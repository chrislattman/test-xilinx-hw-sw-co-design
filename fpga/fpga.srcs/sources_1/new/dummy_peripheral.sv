// Connect the generated register block to the dummy hardware behavior.
module dummy_peripheral (                               // Begin the SystemVerilog peripheral's port list.
    input  wire        s_axi_aclk,                      // Receive the 100 MHz clock shared with the control SmartConnect.
    input  wire        s_axi_aresetn,                   // Receive the active-low reset, sampled on rising clock edges.
    input  wire [11:0] s_axi_awaddr,                    // Receive the byte offset of the register being written.
    input  wire [2:0]  s_axi_awprot,                    // Receive the AXI write-access attributes.
    input  wire        s_axi_awvalid,                   // Receive the indication that the write address is valid.
    output wire        s_axi_awready,                   // Indicate that the peripheral can accept a write address.
    input  wire [31:0] s_axi_wdata,                     // Receive the 32-bit register write value.
    input  wire [3:0]  s_axi_wstrb,                     // Receive one write-enable bit for each of the four byte lanes.
    input  wire        s_axi_wvalid,                    // Receive the indication that the write data is valid.
    output wire        s_axi_wready,                    // Indicate that the peripheral can accept write data.
    output wire [1:0]  s_axi_bresp,                     // Return the AXI write-response code.
    output wire        s_axi_bvalid,                    // Indicate that a write response is available.
    input  wire        s_axi_bready,                    // Receive the master's readiness to accept a write response.
    input  wire [11:0] s_axi_araddr,                    // Receive the byte offset of the register being read.
    input  wire [2:0]  s_axi_arprot,                    // Receive the AXI read-access attributes.
    input  wire        s_axi_arvalid,                   // Receive the indication that the read address is valid.
    output wire        s_axi_arready,                   // Indicate that the peripheral can accept a read address.
    output wire [31:0] s_axi_rdata,                     // Return the selected register's 32-bit value.
    output wire [1:0]  s_axi_rresp,                     // Return the AXI read-response code.
    output wire        s_axi_rvalid,                    // Indicate that read data and its response are available.
    input  wire        s_axi_rready                     // Receive the master's readiness to accept a read response.
);                                                      // Finish the peripheral's port list.

    dummy_regs_pkg::dummy_regs__in_t  hwif_in;          // Declare the hardware inputs to the generated register block.
    dummy_regs_pkg::dummy_regs__out_t hwif_out;         // Declare the hardware outputs from the generated register block.

    assign hwif_in.status.hw_bit.next = hwif_out.control.sw_bit.value;  // Feed the stored software bit into the hardware mirror's next-value input.
    assign hwif_in.status.hw_bit.we   = 1'b1;           // Enable the mirror register to sample that value on every rising clock edge.

    dummy_regs u_regs(                                  // Instantiate the AXI4-Lite register block generated from dummy_regs.rdl.
        .clk(s_axi_aclk),                               // Receive the 100 MHz clock shared with the control SmartConnect.
        .rst_n(s_axi_aresetn),                          // Receive the active-low reset, sampled on rising clock edges.
        .s_axil_awaddr(s_axi_awaddr),                   // Receive the byte offset of the register being written.
        .s_axil_awprot(s_axi_awprot),                   // Receive the AXI write-access attributes.
        .s_axil_awvalid(s_axi_awvalid),                 // Receive the indication that the write address is valid.
        .s_axil_awready(s_axi_awready),                 // Indicate that the peripheral can accept a write address.
        .s_axil_wdata(s_axi_wdata),                     // Receive the 32-bit register write value.
        .s_axil_wstrb(s_axi_wstrb),                     // Receive one write-enable bit for each of the four byte lanes.
        .s_axil_wvalid(s_axi_wvalid),                   // Receive the indication that the write data is valid.
        .s_axil_wready(s_axi_wready),                   // Indicate that the peripheral can accept write data.
        .s_axil_bresp(s_axi_bresp),                     // Return the AXI write-response code.
        .s_axil_bvalid(s_axi_bvalid),                   // Indicate that a write response is available.
        .s_axil_bready(s_axi_bready),                   // Receive the master's readiness to accept a write response.
        .s_axil_araddr(s_axi_araddr),                   // Receive the byte offset of the register being read.
        .s_axil_arprot(s_axi_arprot),                   // Receive the AXI read-access attributes.
        .s_axil_arvalid(s_axi_arvalid),                 // Receive the indication that the read address is valid.
        .s_axil_arready(s_axi_arready),                 // Indicate that the peripheral can accept a read address.
        .s_axil_rdata(s_axi_rdata),                     // Return the selected register's 32-bit value.
        .s_axil_rresp(s_axi_rresp),                     // Return the AXI read-response code.
        .s_axil_rvalid(s_axi_rvalid),                   // Indicate that read data and its response are available.
        .s_axil_rready(s_axi_rready),                   // Receive the master's readiness to accept a read response.
        .hwif_in(hwif_in),                              // Supply the mirror value and hardware write-enable to the generated block.
        .hwif_out(hwif_out)                             // Obtain the software-controlled bit from the generated block.
    );
endmodule
