// Verilog boundary for adding the SystemVerilog capture_peripheral to a Vivado block design.
// This wrapper forwards every port to capture_peripheral and adds no storage or processing.
module capture_bd #(                                    // Begin the block-design wrapper and its parameter list.
    parameter integer FIFO_DEPTH = 256                  // Set the FIFO capacity in words; the default hardware capacity is 256.
)(                                                      // Close the parameter list and begin the external port list.
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK CLK",    // Identify the following port as the peripheral clock.
       X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI:M_AXIS, ASSOCIATED_RESET s_axi_aresetn, FREQ_HZ 100000000" *) // Associate both buses with this clock and reset; expect a 100 MHz clock.
    input wire s_axi_aclk,                              // Receive the shared clock for the entire capture peripheral.
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST RST",    // Identify the following port as the peripheral reset.
       X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *) // Tell Vivado that a low level asserts this reset.
    input wire s_axi_aresetn,                           // Receive the active-low reset used by the capture peripheral.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR", // Identify the AXI4-Lite write-address signal.
       X_INTERFACE_PARAMETER = "PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 12" *) // Describe 32-bit control data and a 12-bit byte offset.
    input wire [11:0] s_axi_awaddr,                     // Receive the byte offset of the register to write.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *) // Identify the AXI4-Lite write-access attributes.
    input wire [2:0] s_axi_awprot,                      // Receive the write transaction's access attributes.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *) // Identify the AXI4-Lite write-address-valid signal.
    input wire s_axi_awvalid,                           // Receive the master's indication that its write address is valid.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *) // Identify the AXI4-Lite write-address-ready signal.
    output wire s_axi_awready,                          // Tell the master when the peripheral can accept a write address.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *) // Identify the AXI4-Lite write-data signal.
    input wire [31:0] s_axi_wdata,                      // Receive the 32-bit value to write into a register.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *) // Identify the AXI4-Lite write-byte enables.
    input wire [3:0] s_axi_wstrb,                       // Receive one write-enable bit for each of the four data bytes.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *) // Identify the AXI4-Lite write-data-valid signal.
    input wire s_axi_wvalid,                            // Receive the master's indication that its write data is valid.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *) // Identify the AXI4-Lite write-data-ready signal.
    output wire s_axi_wready,                           // Tell the master when the peripheral can accept write data.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *) // Identify the AXI4-Lite write-response code.
    output wire [1:0] s_axi_bresp,                      // Return the result of a register write to the master.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *) // Identify the AXI4-Lite write-response-valid signal.
    output wire s_axi_bvalid,                           // Tell the master when a write response is available.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *) // Identify the AXI4-Lite write-response-ready signal.
    input wire s_axi_bready,                            // Receive the master's readiness to accept a write response.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *) // Identify the AXI4-Lite read-address signal.
    input wire [11:0] s_axi_araddr,                     // Receive the byte offset of the register to read.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *) // Identify the AXI4-Lite read-access attributes.
    input wire [2:0] s_axi_arprot,                      // Receive the read transaction's access attributes.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *) // Identify the AXI4-Lite read-address-valid signal.
    input wire s_axi_arvalid,                           // Receive the master's indication that its read address is valid.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *) // Identify the AXI4-Lite read-address-ready signal.
    output wire s_axi_arready,                          // Tell the master when the peripheral can accept a read address.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *) // Identify the AXI4-Lite read-data signal.
    output wire [31:0] s_axi_rdata,                     // Return the selected register's 32-bit value to the master.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *) // Identify the AXI4-Lite read-response code.
    output wire [1:0] s_axi_rresp,                      // Return the result of a register read to the master.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *) // Identify the AXI4-Lite read-response-valid signal.
    output wire s_axi_rvalid,                           // Tell the master when read data and its response code are available.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *) // Identify the AXI4-Lite read-response-ready signal.
    input wire s_axi_rready,                            // Receive the master's readiness to accept a read response.
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TDATA" *) // Identify the outgoing AXI4-Stream payload.
    output wire [31:0] m_axis_tdata,                    // Offer the FIFO's oldest 32-bit word to the DMA.
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TKEEP" *) // Identify the outgoing stream's byte-valid mask.
    output wire [3:0] m_axis_tkeep,                     // Mark the four valid bytes supplied with each output word.
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TLAST" *) // Identify the outgoing stream's final-word marker.
    output wire m_axis_tlast,                           // Mark the final word of the capture packet being sent to the DMA.
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TVALID" *) // Identify the outgoing stream's data-valid signal.
    output wire m_axis_tvalid,                          // Tell the DMA when the peripheral is offering a valid stream word.
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TREADY" *) // Identify the outgoing stream's receiver-ready signal.
    input wire m_axis_tready                            // Receive the DMA's readiness to accept the offered stream word.
);                                                      // Finish the wrapper's external port list.

    capture_peripheral #(                              // Instantiate the existing SystemVerilog peripheral inside this Verilog wrapper.
        .FIFO_DEPTH(FIFO_DEPTH)                         // Pass the wrapper's FIFO capacity to the existing peripheral.
    ) u_capture(                                       // Name the enclosed peripheral instance u_capture and begin its port connections.
        .s_axi_aclk(s_axi_aclk),                        // Forward the shared clock to the peripheral.
        .s_axi_aresetn(s_axi_aresetn),                   // Forward the active-low reset to the peripheral.
        .s_axi_awaddr(s_axi_awaddr),                    // Forward the write-register byte offset to the peripheral.
        .s_axi_awprot(s_axi_awprot),                    // Forward the write-access attributes to the peripheral.
        .s_axi_awvalid(s_axi_awvalid),                  // Forward the master's write-address validity to the peripheral.
        .s_axi_awready(s_axi_awready),                  // Return the peripheral's write-address readiness through the wrapper.
        .s_axi_wdata(s_axi_wdata),                      // Forward the register-write value to the peripheral.
        .s_axi_wstrb(s_axi_wstrb),                      // Forward the four write-byte enables to the peripheral.
        .s_axi_wvalid(s_axi_wvalid),                    // Forward the master's write-data validity to the peripheral.
        .s_axi_wready(s_axi_wready),                    // Return the peripheral's write-data readiness through the wrapper.
        .s_axi_bresp(s_axi_bresp),                      // Return the peripheral's write-response code through the wrapper.
        .s_axi_bvalid(s_axi_bvalid),                    // Return the peripheral's write-response validity through the wrapper.
        .s_axi_bready(s_axi_bready),                    // Forward the master's write-response readiness to the peripheral.
        .s_axi_araddr(s_axi_araddr),                    // Forward the read-register byte offset to the peripheral.
        .s_axi_arprot(s_axi_arprot),                    // Forward the read-access attributes to the peripheral.
        .s_axi_arvalid(s_axi_arvalid),                  // Forward the master's read-address validity to the peripheral.
        .s_axi_arready(s_axi_arready),                  // Return the peripheral's read-address readiness through the wrapper.
        .s_axi_rdata(s_axi_rdata),                      // Return the peripheral's register-read value through the wrapper.
        .s_axi_rresp(s_axi_rresp),                      // Return the peripheral's read-response code through the wrapper.
        .s_axi_rvalid(s_axi_rvalid),                    // Return the peripheral's read-response validity through the wrapper.
        .s_axi_rready(s_axi_rready),                    // Forward the master's read-response readiness to the peripheral.
        .m_axis_tdata(m_axis_tdata),                    // Forward the peripheral's outgoing payload toward the DMA.
        .m_axis_tkeep(m_axis_tkeep),                    // Forward the peripheral's outgoing byte-valid mask toward the DMA.
        .m_axis_tlast(m_axis_tlast),                    // Forward the peripheral's outgoing final-word marker toward the DMA.
        .m_axis_tvalid(m_axis_tvalid),                  // Forward the peripheral's outgoing stream validity toward the DMA.
        .m_axis_tready(m_axis_tready)                   // Forward the DMA's readiness back to the peripheral.
    );                                                  // Finish the enclosed peripheral's port connections.
endmodule
