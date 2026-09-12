// Verilog boundary for adding the SystemVerilog dummy peripheral as a Vivado module reference.
module dummy_bd (                                       // Begin the block-design wrapper's port list.
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK CLK",    // Identify the following port as a clock.
       X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET s_axi_aresetn, FREQ_HZ 100000000" *)   // Associate the AXI interface and reset with this 100 MHz clock.
    input wire s_axi_aclk,                              // Receive the 100 MHz clock shared with the control SmartConnect.
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST RST",    // Identify the following port as a reset.
       X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *) // Describe the reset's active-low polarity.
    input wire s_axi_aresetn,                           // Receive the active-low reset, sampled on rising clock edges.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR",    // Identify the write-address member of the AXI interface.
       X_INTERFACE_PARAMETER = "PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 12" *) // Describe a 32-bit AXI4-Lite slave with a 4 KiB address window.
    input wire [11:0] s_axi_awaddr,                     // Receive the byte offset of the register being written.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *)  // Identify the AWPROT member of the AXI4-Lite interface.
    input wire [2:0] s_axi_awprot,                      // Receive the AXI write-access attributes.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *) // Identify the AWVALID member of the AXI4-Lite interface.
    input wire s_axi_awvalid,                           // Receive the indication that the write address is valid.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *) // Identify the AWREADY member of the AXI4-Lite interface.
    output wire s_axi_awready,                          // Indicate that the peripheral can accept a write address.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)   // Identify the WDATA member of the AXI4-Lite interface.
    input wire [31:0] s_axi_wdata,                      // Receive the 32-bit register write value.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)   // Identify the WSTRB member of the AXI4-Lite interface.
    input wire [3:0] s_axi_wstrb,                       // Receive one write-enable bit for each of the four byte lanes.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)  // Identify the WVALID member of the AXI4-Lite interface.
    input wire s_axi_wvalid,                            // Receive the indication that the write data is valid.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)  // Identify the WREADY member of the AXI4-Lite interface.
    output wire s_axi_wready,                           // Indicate that the peripheral can accept write data.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)   // Identify the BRESP member of the AXI4-Lite interface.
    output wire [1:0] s_axi_bresp,                      // Return the AXI write-response code.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)  // Identify the BVALID member of the AXI4-Lite interface.
    output wire s_axi_bvalid,                           // Indicate that a write response is available.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)  // Identify the BREADY member of the AXI4-Lite interface.
    input wire s_axi_bready,                            // Receive the master's readiness to accept a write response.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)  // Identify the ARADDR member of the AXI4-Lite interface.
    input wire [11:0] s_axi_araddr,                     // Receive the byte offset of the register being read.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *)  // Identify the ARPROT member of the AXI4-Lite interface.
    input wire [2:0] s_axi_arprot,                      // Receive the AXI read-access attributes.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *) // Identify the ARVALID member of the AXI4-Lite interface.
    input wire s_axi_arvalid,                           // Receive the indication that the read address is valid.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *) // Identify the ARREADY member of the AXI4-Lite interface.
    output wire s_axi_arready,                          // Indicate that the peripheral can accept a read address.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)   // Identify the RDATA member of the AXI4-Lite interface.
    output wire [31:0] s_axi_rdata,                     // Return the selected register's 32-bit value.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)   // Identify the RRESP member of the AXI4-Lite interface.
    output wire [1:0] s_axi_rresp,                      // Return the AXI read-response code.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)  // Identify the RVALID member of the AXI4-Lite interface.
    output wire s_axi_rvalid,                           // Indicate that read data and its response are available.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)  // Identify the RREADY member of the AXI4-Lite interface.
    input wire s_axi_rready                             // Receive the master's readiness to accept a read response.
);                                                      // Finish the block-design wrapper's port list.

    dummy_peripheral u_dummy(                           // Instantiate the SystemVerilog peripheral without adding logic.
        .s_axi_aclk(s_axi_aclk),                        // Forward s_axi_aclk between the block design and the peripheral.
        .s_axi_aresetn(s_axi_aresetn),                  // Forward s_axi_aresetn between the block design and the peripheral.
        .s_axi_awaddr(s_axi_awaddr),                    // Forward s_axi_awaddr between the block design and the peripheral.
        .s_axi_awprot(s_axi_awprot),                    // Forward s_axi_awprot between the block design and the peripheral.
        .s_axi_awvalid(s_axi_awvalid),                  // Forward s_axi_awvalid between the block design and the peripheral.
        .s_axi_awready(s_axi_awready),                  // Forward s_axi_awready between the block design and the peripheral.
        .s_axi_wdata(s_axi_wdata),                      // Forward s_axi_wdata between the block design and the peripheral.
        .s_axi_wstrb(s_axi_wstrb),                      // Forward s_axi_wstrb between the block design and the peripheral.
        .s_axi_wvalid(s_axi_wvalid),                    // Forward s_axi_wvalid between the block design and the peripheral.
        .s_axi_wready(s_axi_wready),                    // Forward s_axi_wready between the block design and the peripheral.
        .s_axi_bresp(s_axi_bresp),                      // Forward s_axi_bresp between the block design and the peripheral.
        .s_axi_bvalid(s_axi_bvalid),                    // Forward s_axi_bvalid between the block design and the peripheral.
        .s_axi_bready(s_axi_bready),                    // Forward s_axi_bready between the block design and the peripheral.
        .s_axi_araddr(s_axi_araddr),                    // Forward s_axi_araddr between the block design and the peripheral.
        .s_axi_arprot(s_axi_arprot),                    // Forward s_axi_arprot between the block design and the peripheral.
        .s_axi_arvalid(s_axi_arvalid),                  // Forward s_axi_arvalid between the block design and the peripheral.
        .s_axi_arready(s_axi_arready),                  // Forward s_axi_arready between the block design and the peripheral.
        .s_axi_rdata(s_axi_rdata),                      // Forward s_axi_rdata between the block design and the peripheral.
        .s_axi_rresp(s_axi_rresp),                      // Forward s_axi_rresp between the block design and the peripheral.
        .s_axi_rvalid(s_axi_rvalid),                    // Forward s_axi_rvalid between the block design and the peripheral.
        .s_axi_rready(s_axi_rready)                     // Forward s_axi_rready between the block design and the peripheral.
    );
endmodule
