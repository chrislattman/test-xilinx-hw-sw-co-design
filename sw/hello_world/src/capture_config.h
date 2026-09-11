#ifndef CAPTURE_CONFIG_H
#define CAPTURE_CONFIG_H

#include "xparameters.h"

/* Hardware addresses supplied by the generated platform configuration. */
#define CAPTURE_BASEADDR XPAR_CAPTURE_BD_0_BASEADDR
#define CAPTURE_DMA_BASEADDR XPAR_XAXIDMA_0_BASEADDR


/* Receive-buffer capacity and timeout for completion/reset polling. */
#define CAPTURE_MAX_WORDS 1024U
#define CAPTURE_TIMEOUT_SECONDS 2U

/* Cortex-A9 data-cache geometry and the DMA-accessible DDR bounds. */
#define CAPTURE_CACHE_LINE_BYTES 32U
#define CAPTURE_DDR_FIRST XPAR_PS7_DDR_0_BASEADDRESS
#define CAPTURE_DDR_END (XPAR_PS7_DDR_0_HIGHADDRESS + 1U) /* Exclusive upper bound. */

#endif
