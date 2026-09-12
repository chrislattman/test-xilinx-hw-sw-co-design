#include "dummy_test.h"
#include "dummy_regs.h"

#include <stddef.h>
#include "xil_io.h"
#include "xil_printf.h"

/* The generated struct supplies offsets; the generated masks supply bit positions.
 * Xil_In32/Xil_Out32 perform the actual MMIO accesses on the Zynq processor.
 */
#define CONTROL_OFFSET ((uintptr_t)offsetof(dummy_regs_t, control))
#define STATUS_OFFSET  ((uintptr_t)offsetof(dummy_regs_t, status))
#define MIRROR_POLL_LIMIT 1000U

static void write_register(uintptr_t address, uint32_t value)
{
    Xil_Out32(address, value);
    __asm__ volatile ("dsb sy" ::: "memory");
}

static int wait_for_mirror(uintptr_t base_address, uint32_t expected)
{
    /* Hardware needs one PL clock after the control register changes. Polling
     * tolerates that delay without depending on the relative CPU/PL speeds.
     * This is a bounded number of reads, not a wall-clock timeout.
     */
    for (unsigned int i = 0; i < MIRROR_POLL_LIMIT; ++i) {
        uint32_t status = Xil_In32(base_address + STATUS_OFFSET);
        if (status == expected) {
            return 0;
        }
    }

    return -1;
}

int dummy_test(uintptr_t base_address)
{
    static const uint32_t values[] = {0U, 1U, 0U, 1U, 0U};

    xil_printf("Dummy SystemRDL peripheral test\r\n");
    xil_printf("Dummy registers = 0x%08x\r\n", (unsigned int)base_address);

    for (unsigned int i = 0; i < sizeof(values) / sizeof(values[0]); ++i) {
        uint32_t bit = values[i];
        uint32_t control = (bit << DUMMY_REGS__CONTROL__SW_BIT_bp)
                         & DUMMY_REGS__CONTROL__SW_BIT_bm;
        uint32_t expected = (bit << DUMMY_REGS__STATUS__HW_BIT_bp)
                          & DUMMY_REGS__STATUS__HW_BIT_bm;

        write_register(base_address + CONTROL_OFFSET, control);

        if (Xil_In32(base_address + CONTROL_OFFSET) != control) {
            xil_printf("FAIL: control readback for bit %u\r\n", (unsigned int)bit);
            return -1;
        }

        if (wait_for_mirror(base_address, expected) != 0) {
            xil_printf("FAIL: mirror did not become %u\r\n", (unsigned int)bit);
            return -1;
        }

        /* With the supplied generation commands, a write to the read-only
         * status register is acknowledged and ignored. Try the opposite bit
         * to demonstrate that the access restriction is enforced by hardware.
         */
        write_register(base_address + STATUS_OFFSET,
                       expected ^ DUMMY_REGS__STATUS__HW_BIT_bm);

        if (Xil_In32(base_address + STATUS_OFFSET) != expected) {
            xil_printf("FAIL: software changed the read-only mirror\r\n");
            return -1;
        }

        xil_printf("PASS: control=%u, mirror=%u, status write ignored\r\n",
                   (unsigned int)bit, (unsigned int)bit);
    }

    xil_printf("ALL DUMMY TESTS PASSED\r\n");
    return 0;
}
