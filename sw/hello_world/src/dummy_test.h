#ifndef DUMMY_TEST_H
#define DUMMY_TEST_H

#include <stdint.h>

/* Exercise the dummy registers at the assigned Vivado base address.
 * Returns zero on success and -1 on failure; prints results through xil_printf.
 */
int dummy_test(uintptr_t base_address);

#endif
