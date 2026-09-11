# FPGA Design

This project uses a 32-bit counter to feed a synchronous FIFO, both written in SystemVerilog. The FIFO is read by AXI DMA. Each communicate to its "neighbor" via AXI4-Stream. An ILA is inserted to debug the stream connection between the FIFO and the DMA.

In the block design:

`processing_system7_0` provides clock to all IP blocks

`processing_system7_0` provides reset to `rst_ps7_0_100M`, which provides reset to remaining IP blocks

`axi_smc_0` is used for the "control" plane: C code running in the A9 reads the DMA status

`axi_smc_1` is used for the "data" plane: DMA connects to DDR through HP0 port

VUnit cannot be used here since it requires a QuestaSim license, which I don't have.

If I used AMD's provided IP for the FIFO, I would only need the following handwritten files:

- `counter_source.sv` and `tb_counter_source.sv`
- `tb_counter_fifo.sv`
- `axi_lite_bsm.sv` and `tb_counter_vivado.sv`
