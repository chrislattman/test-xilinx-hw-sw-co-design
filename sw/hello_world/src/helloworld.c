/*
 * Standalone Cortex-A9 polling test for the counter/FIFO/AXI DMA capture path.
 * Requires simple-mode S2MM and the Vitis SDT DMA configuration API.
 */

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include "platform.h"
#include "xaxidma.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xstatus.h"
#include "xiltimer.h"

#include "capture_config.h"
#include "dummy_test.h"

/* Capture register offsets; keep consistent with capture_regs.sv. */
#define CAP_COMMAND 0x00U
#define CAP_STATUS 0x04U
#define CAP_WORD_COUNT 0x08U
#define CAP_START_VALUE 0x0CU
#define CAP_FIFO_LEVEL 0x10U
#define CAP_ACCEPTED_WORDS 0x14U
#define CAP_START 0x01U
#define CAP_FIFO_EMPTY 0x02U
#define CAP_STATUS_MASK 0x0FU /* ACTIVE, FIFO_EMPTY, FIFO_FULL, SOURCE_BUSY */
#define BUFFER_SENTINEL 0xA5A5A5A5U

static XAxiDma dma;
/* Keep the DDR buffer on dedicated cache lines, including for short transfers. */
static uint32_t rx_buffer[CAPTURE_MAX_WORDS] __attribute__((aligned(CAPTURE_CACHE_LINE_BYTES)));
_Static_assert(sizeof(uint32_t) == 4U, "The stream contains four-byte words");
_Static_assert((sizeof(rx_buffer) % CAPTURE_CACHE_LINE_BYTES) == 0U, "Buffer must occupy whole cache lines");

/* Order memory and MMIO accesses when transferring buffer ownership. */
static void complete_accesses(void)
{
    __asm__ volatile ("dsb sy" ::: "memory");
}

static int timeout_expired(XTime started)
{
    XTime now;
    XTime_GetTime(&now);
    return (now - started) >= ((XTime)COUNTS_PER_SECOND * CAPTURE_TIMEOUT_SECONDS);
}

static u32 capture_read(u32 offset)
{
    return Xil_In32((UINTPTR)CAPTURE_BASEADDR + offset);
}

static u32 dma_status(void)
{
    return XAxiDma_ReadReg((UINTPTR)CAPTURE_DMA_BASEADDR, XAXIDMA_RX_OFFSET + XAXIDMA_SR_OFFSET);
}

/* Preserve diagnostics and stop DMA before allowing the buffer to be reused. */
static int abort_capture(const char *reason)
{
    XTime started;
    xil_printf("FAIL: %s\r\n", reason);
    xil_printf("DMA S2MM status = 0x%08x\r\n", (unsigned)dma_status());
    xil_printf("CAP status = 0x%08x\r\n", (unsigned)capture_read(CAP_STATUS));
    xil_printf("FIFO level = %u\r\n", (unsigned)capture_read(CAP_FIFO_LEVEL));
    xil_printf("Accepted words = %u\r\n", (unsigned)capture_read(CAP_ACCEPTED_WORDS));
    XAxiDma_Reset(&dma);
    XTime_GetTime(&started);
    while (!XAxiDma_ResetIsDone(&dma))
    {
        if (timeout_expired(started))
        {
            xil_printf("DMA reset timed out. Reset the board and reload the bitstream.\r\n");
            /* DMA may still own the buffer. Halt until an external reset. */
            while (1);
        }
    }
    complete_accesses();
    xil_printf("Reload the bitstream before retrying; DMA reset does not clear our custom FIFO.\r\n");
    return XST_FAILURE;
}

/* Receive one packet and verify its length, contents, and controller status. */
static int run_capture(uint32_t first_value, uint32_t words)
{
    const u32 bytes = words * (u32)sizeof(uint32_t);
    XTime started;
    u32 status;
    u32 received_bytes;
    int result;

    if ((words == 0U) || (words > CAPTURE_MAX_WORDS))
    {
        xil_printf("FAIL: invalid capture length %u\r\n", (unsigned)words);
        return XST_FAILURE;
    }
    /* The controller accepts START only while idle, with an empty FIFO. */
    if (((capture_read(CAP_STATUS) & CAP_STATUS_MASK) != CAP_FIFO_EMPTY) || (capture_read(CAP_FIFO_LEVEL) != 0U))
    {
        xil_printf("FAIL: capture is not idle and empty; reload the bitstream before retrying.\r\n");
        return XST_FAILURE;
    }

    /* Verify the control path before starting any data transfer. */
    Xil_Out32((UINTPTR)CAPTURE_BASEADDR + CAP_WORD_COUNT, words);
    Xil_Out32((UINTPTR)CAPTURE_BASEADDR + CAP_START_VALUE, first_value);
    complete_accesses();
    if ((capture_read(CAP_WORD_COUNT) != words) || (capture_read(CAP_START_VALUE) != first_value))
    {
        xil_printf("FAIL: capture register readback mismatch\r\n");
        return XST_FAILURE;
    }

    /*
     * HP0 DMA does not keep the A9 data cache coherent. Flush dirty lines before
     * DMA writes DDR; do not access the buffer again until completion and
     * invalidation. The sentinel also detects writes beyond a short packet.
     */
    memset(rx_buffer, 0xA5, sizeof(rx_buffer));
    Xil_DCacheFlushRange((UINTPTR)rx_buffer, (u32)sizeof(rx_buffer));
    /* Clear stale completion flags before submitting the next receive. */
    XAxiDma_IntrAckIrq(&dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    complete_accesses();
    result = (int)XAxiDma_SimpleTransfer(&dma, (UINTPTR)rx_buffer, bytes, XAXIDMA_DEVICE_TO_DMA);
    if (result != XST_SUCCESS)
    {
        xil_printf("DMA submission returned %d\r\n", result);
        return abort_capture("DMA submission rejected");
    }
    /* Arm the DMA before allowing the counter to produce the packet. */
    complete_accesses();
    Xil_Out32((UINTPTR)CAPTURE_BASEADDR + CAP_COMMAND, CAP_START);
    complete_accesses();

    /* IOC status can be polled even with DMA interrupt generation disabled. */
    XTime_GetTime(&started);
    while (1)
    {
        status = dma_status();
        if ((status & (XAXIDMA_ERR_ALL_MASK | XAXIDMA_IRQ_ERROR_MASK)) != 0U)
        {
            return abort_capture("DMA reported an error");
        }
        if (((status & XAXIDMA_IRQ_IOC_MASK) != 0U) && ((status & XAXIDMA_IDLE_MASK) != 0U))
        {
            break;
        }
        if (timeout_expired(started))
        {
            return abort_capture("DMA completion timed out");
        }
    }

    complete_accesses();
    /* After completion, S2MM_LENGTH reports the actual received byte count. */
    received_bytes = XAxiDma_ReadReg((UINTPTR)CAPTURE_DMA_BASEADDR, XAXIDMA_RX_OFFSET + XAXIDMA_BUFFLEN_OFFSET);
    if (received_bytes != bytes)
    {
        xil_printf("Expected %u bytes, received %u bytes\r\n", (unsigned)bytes, (unsigned)received_bytes);
        return abort_capture("wrong packet length");
    }
    /* Invalidate the entire private buffer before checking data and its tail. */
    Xil_DCacheInvalidateRange((UINTPTR)rx_buffer, (u32)sizeof(rx_buffer));
    complete_accesses();

    for (uint32_t i = 0U; i < words; ++i)
    {
        const uint32_t expected = first_value + i; /* Intentional 32-bit wraparound. */
        if (rx_buffer[i] != expected)
        {
            xil_printf("Word %u: expected 0x%08x, received 0x%08x\r\n", (unsigned)i, (unsigned)expected, (unsigned)rx_buffer[i]);
            return abort_capture("counter sequence mismatch");
        }
    }
    /* Words beyond the packet must retain their original sentinel value. */
    for (uint32_t i = words; i < CAPTURE_MAX_WORDS; ++i)
    {
        if (rx_buffer[i] != BUFFER_SENTINEL)
        {
            return abort_capture("buffer tail changed beyond the packet");
        }
    }
    /* Check the custom controller independently of DMA completion. */
    if (((capture_read(CAP_STATUS) & CAP_STATUS_MASK) != CAP_FIFO_EMPTY) || (capture_read(CAP_FIFO_LEVEL) != 0U) || (capture_read(CAP_ACCEPTED_WORDS) != words))
    {
        return abort_capture("capture status or accepted-word count mismatch");
    }

    xil_printf("PASS: %u words, first=0x%08x, last=0x%08x\r\n", (unsigned)words, (unsigned)rx_buffer[0], (unsigned)rx_buffer[words - 1U]);
    return XST_SUCCESS;
}

int main(void)
{
    XAxiDma_Config *config;
    int result;
    /* Assumes the usual standalone identity mapping of CPU and DMA RAM addresses. */
    const UINTPTR buffer_address = (UINTPTR)rx_buffer;

    init_platform();
    if (dummy_test((uintptr_t)XPAR_DUMMY_BD_0_BASEADDR) != 0) {
        return 1;
    }
    xil_printf("Counter/FIFO/DMA capture test\r\n");
    xil_printf("Capture registers = 0x%08x\r\n", (unsigned)CAPTURE_BASEADDR);
    xil_printf("DMA registers = 0x%08x\r\n", (unsigned)CAPTURE_DMA_BASEADDR);
    xil_printf("Receive buffer = 0x%08x\r\n", (unsigned)buffer_address);
    /* The entire receive buffer must be reachable through the HP0 DDR mapping. */
    if ((buffer_address < (UINTPTR)CAPTURE_DDR_FIRST) || (buffer_address > ((UINTPTR)CAPTURE_DDR_END - sizeof(rx_buffer))))
    {
        xil_printf("FAIL: place .bss in PS DDR in your application's linker script.\r\n");
        cleanup_platform();
        return XST_FAILURE;
    }

    config = XAxiDma_LookupConfig((UINTPTR)CAPTURE_DMA_BASEADDR);
    if ((config == NULL) || (config->BaseAddr != (UINTPTR)CAPTURE_DMA_BASEADDR) || (config->HasSg != 0) || (config->HasS2Mm == 0) || (config->MicroDmaMode != 0))
    {
        xil_printf("FAIL: DMA address or BSP configuration does not match simple-mode S2MM.\r\n");
        cleanup_platform();
        return XST_FAILURE;
    }
    result = XAxiDma_CfgInitialize(&dma, config);
    if (result != XST_SUCCESS)
    {
        xil_printf("FAIL: DMA initialization returned %d\r\n", result);
        cleanup_platform();
        return XST_FAILURE;
    }
    XAxiDma_IntrDisable(&dma, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
    xil_printf("Initial capture status = 0x%08x\r\n", (unsigned)capture_read(CAP_STATUS));

    /* Exercise full-size, odd-length, wrapping, and single-word packets without reset. */
    result = run_capture(0U, 1024U);
    if (result == XST_SUCCESS)
    {
        result = run_capture(100U, 17U);
    }
    if (result == XST_SUCCESS)
    {
        result = run_capture(0xFFFFFFFFU, 3U);
    }
    if (result == XST_SUCCESS)
    {
        result = run_capture(41U, 1U);
    }

    xil_printf(result == XST_SUCCESS ? "ALL CAPTURES PASSED\r\n" : "CAPTURE TEST FAILED\r\n");
    cleanup_platform();
    return result;
}
