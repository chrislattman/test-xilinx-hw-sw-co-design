# Hardware/Software Co-Design

Refer to the READMEs in each subfolder.

To regenerate the SystemVerilog and C files corresponding to the SystemRDL file `dummy_regs.rdl`:

```
peakrdl regblock dummy_regs.rdl -o fpga/fpga.srcs/sources_1/new --cpuif axi4-lite-flat \
    --module-name dummy_regs --package-name dummy_regs_pkg \
    --addr-width 12 --default-reset rst_n

peakrdl c-header dummy_regs.rdl -o sw/hello_world/src/dummy_regs.h --std gnu17 --bitfields none
```
