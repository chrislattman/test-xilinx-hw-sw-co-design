// Capture subsystem: handwritten control, counter source, and FIFO.
// The port list consists of wires because this wrapper connects other modules together.
module capture_peripheral #(                            // Begin the capture-peripheral module and its parameter list.
    parameter int FIFO_DEPTH = 256                      // Set the FIFO capacity to 256 words unless the instantiating module overrides it.
)(                                                      // Close the parameter list and begin the external port list.
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK CLK",    // Tell Vivado that the following port is the clock for this peripheral.
       X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI:M_AXIS, ASSOCIATED_RESET s_axi_aresetn, FREQ_HZ 100000000" *)    // Tell Vivado these interfaces share this clock and reset, with an expected clock frequency of 100 MHz.
    input wire s_axi_aclk,                              // Clock the AXI adapter, register bank, counter, and FIFO together.
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST RST",  // Identify the following port to Vivado as this peripheral's reset signal.
       X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *) // Tell Vivado that a low level asserts the reset.
    input wire s_axi_aresetn,                           // Reset all four blocks together with an active-low synchronous reset.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR",    // Identify the following port as the AWADDR write-address signal of Vivado's S_AXI interface.
       X_INTERFACE_PARAMETER = "PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 12" *) // Describe a 32-bit AXI4-Lite control interface with twelve byte-address bits.
    input wire [11:0] s_axi_awaddr,                     // Receive the byte offset of a register to write.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *)  // Identify the following port as the AWPROT write-access attributes of the S_AXI interface.
    input wire [2:0] s_axi_awprot,                      // Receive the write access attributes.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *) // Identify the following port as the AWVALID write-address-valid signal of the S_AXI interface.
    input wire s_axi_awvalid,                           // Receive the master's indication that a write address is valid.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *) // Identify the following port as the AWREADY write-address-ready signal of the S_AXI interface.
    output wire s_axi_awready,                          // Tell the master whether the write address can be accepted.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)   // Identify the following port as the WDATA write-data signal of the S_AXI interface.
    input wire [31:0] s_axi_wdata,                      // Receive the new register data.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)   // Identify the following port as the WSTRB write-byte-enable signal of the S_AXI interface.
    input wire [3:0] s_axi_wstrb,                       // Receive the four byte enables associated with the write data.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)  // Identify the following port as the WVALID write-data-valid signal of the S_AXI interface.
    input wire s_axi_wvalid,                            // Receive the master's indication that write data is valid.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)  // Identify the following port as the WREADY write-data-ready signal of the S_AXI interface.
    output wire s_axi_wready,                           // Tell the master whether write data can be accepted.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)   // Identify the following port as the BRESP write-response code of the S_AXI interface.
    output wire [1:0] s_axi_bresp,                      // Return the write result, either OKAY or SLVERR.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)  // Identify the following port as the BVALID write-response-valid signal of the S_AXI interface.
    output wire s_axi_bvalid,                           // Indicate that a write response is available.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)  // Identify the following port as the BREADY write-response-ready signal of the S_AXI interface.
    input wire s_axi_bready,                            // Receive the master's acceptance of the write response.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)  // Identify the following port as the ARADDR read-address signal of the S_AXI interface.
    input wire [11:0] s_axi_araddr,                     // Receive the byte offset of a register to read.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *)  // Identify the following port as the ARPROT read-access attributes of the S_AXI interface.
    input wire [2:0] s_axi_arprot,                      // Receive the read access attributes.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *) // Identify the following port as the ARVALID read-address-valid signal of the S_AXI interface.
    input wire s_axi_arvalid,                           // Receive the master's indication that a read address is valid.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *) // Identify the following port as the ARREADY read-address-ready signal of the S_AXI interface.
    output wire s_axi_arready,                          // Tell the master whether a read address can be accepted.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)   // Identify the following port as the RDATA read-data signal of the S_AXI interface.
    output wire [31:0] s_axi_rdata,                     // Return the captured register value.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)   // Identify the following port as the RRESP read-response code of the S_AXI interface.
    output wire [1:0] s_axi_rresp,                      // Return the read result, either OKAY or SLVERR.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)  // Identify the following port as the RVALID read-response-valid signal of the S_AXI interface.
    output wire s_axi_rvalid,                           // Indicate that read data and its result are available.
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)  // Identify the following port as the RREADY read-response-ready signal of the S_AXI interface.
    input wire s_axi_rready,                            // Receive the master's acceptance of the read response.
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TDATA" *)   // Identify the following port as the TDATA payload signal of Vivado's M_AXIS stream interface.
    output wire [31:0] m_axis_tdata,                    // Offer the FIFO's oldest payload word to the downstream receiver.
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TKEEP" *)   // Identify the following port as the TKEEP byte-valid mask of the M_AXIS stream interface.
    output wire [3:0] m_axis_tkeep,                     // Mark all four bytes of each 32-bit output word as valid.
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TLAST" *)   // Identify the following port as the TLAST final-word marker of the M_AXIS stream interface.
    output wire m_axis_tlast,                           // Offer the packet marker stored with the current FIFO word.
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TVALID" *)  // Identify the following port as the TVALID data-valid signal of the M_AXIS stream interface.
    output wire m_axis_tvalid,                          // Indicate that the FIFO is offering a valid output word.
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 M_AXIS TREADY" *)  // Identify the following port as the TREADY receiver-ready signal of the M_AXIS stream interface.
    input wire m_axis_tready                            // Receive downstream readiness, which allows the FIFO to deliver a word.
);                                                      // Finish the peripheral port list.
    logic wr_en;                                        // Carry the adapter's register-write request to the register bank.
    logic wr_error;                                     // Carry the register bank's write-rejection indication back to the AXI adapter.
    logic rd_error;                                     // Carry the register bank's read-rejection indication back to the AXI adapter.
    logic start;                                        // Carry a valid START command from the register bank to the counter.
    logic source_busy;                                  // Indicate that the counter is still supplying the current packet to the FIFO.
    logic [11:0] wr_addr;                               // Carry the byte offset of the register being written.
    logic [11:0] rd_addr;                               // Carry the byte offset of the register being read.
    logic [31:0] wr_data;                               // Carry the captured 32-bit write value from the adapter to the register bank.
    logic [31:0] rd_data;                               // Carry the selected 32-bit register value back to the adapter for a read response.
    logic [31:0] word_count;                            // Carry the configured number of words to generate when START is accepted.
    logic [31:0] start_value;                           // Carry the configured first number to generate when START is accepted.
    logic [3:0] wr_strb;                                // Carry captured write byte enables to the register bank.
    logic [31:0] source_data;                           // Carry generated payload words from the counter into the FIFO.
    logic source_last;                                  // Mark the counter's final word so the FIFO stores the packet boundary with its data.
    logic source_valid;                                 // Indicate that the counter is offering a valid word to the FIFO.
    logic source_ready;                                 // Carry the FIFO's input readiness back to the counter so it can pause when necessary.
    logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_level;        // Observe the FIFO occupancy using enough bits to represent full capacity.
    wire [31:0] fifo_level_32 = fifo_level;             // Continuously zero-extend the unsigned FIFO occupancy to the register bank's 32-bit input.
    assign m_axis_tkeep = 4'hf;                         // All four bytes are valid because this source always generates full 32-bit words.

    axi_lite_regs bus_adapter(                          // Instantiate the block that captures AXI requests and holds their responses.
        .clk(s_axi_aclk),                               // Clock the AXI adapter from the peripheral's shared clock.
        .rst_n(s_axi_aresetn),                          // Supply the AXI adapter with the shared active-low synchronous reset.
        .s_axi_awaddr(s_axi_awaddr),                    // Pass the external write-register byte offset into the adapter.
        .s_axi_awprot(s_axi_awprot),                    // Pass the external write-access attributes into the adapter.
        .s_axi_awvalid(s_axi_awvalid),                  // Pass the master's write-address-valid indication into the adapter.
        .s_axi_awready(s_axi_awready),                  // Return the adapter's write-address readiness to the master.
        .s_axi_wdata(s_axi_wdata),                      // Pass the master's 32-bit register-write value into the adapter.
        .s_axi_wstrb(s_axi_wstrb),                      // Pass the master's four write-byte enables into the adapter.
        .s_axi_wvalid(s_axi_wvalid),                    // Pass the master's write-data-valid indication into the adapter.
        .s_axi_wready(s_axi_wready),                    // Return the adapter's write-data readiness to the master.
        .s_axi_bresp(s_axi_bresp),                      // Return the adapter's write-response code to the master.
        .s_axi_bvalid(s_axi_bvalid),                    // Tell the master when the adapter is holding a valid write response.
        .s_axi_bready(s_axi_bready),                    // Tell the adapter when the master is ready to accept a write response.
        .s_axi_araddr(s_axi_araddr),                    // Pass the external read-register byte offset into the adapter.
        .s_axi_arprot(s_axi_arprot),                    // Pass the external read-access attributes into the adapter.
        .s_axi_arvalid(s_axi_arvalid),                  // Pass the master's read-address-valid indication into the adapter.
        .s_axi_arready(s_axi_arready),                  // Return the adapter's read-address readiness to the master.
        .s_axi_rdata(s_axi_rdata),                      // Return the adapter's captured 32-bit register-read value to the master.
        .s_axi_rresp(s_axi_rresp),                      // Return the adapter's read-response code to the master.
        .s_axi_rvalid(s_axi_rvalid),                    // Tell the master when the adapter is holding valid read data and a response code.
        .s_axi_rready(s_axi_rready),                    // Tell the adapter when the master is ready to accept a read response.
        .wr_en(wr_en),                                  // Route the adapter's register-write request to the internal wr_en signal.
        .wr_addr(wr_addr),                              // Route the adapter's captured write-address offset to the register bank.
        .wr_data(wr_data),                              // Route the adapter's captured write data to the register bank.
        .wr_strb(wr_strb),                              // Route the adapter's captured byte enables to the register bank.
        .wr_error(wr_error),                            // Let the adapter use the register bank's write-rejection signal to form the write response.
        .rd_addr(rd_addr),                              // Route the requested read-address offset from the adapter to the register bank.
        .rd_data(rd_data),                              // Supply the adapter with the register value selected for reading.
        .rd_error(rd_error)                             // Let the adapter use the register bank's read-rejection signal to form the read response.
    );

    capture_regs #(.FIFO_DEPTH(FIFO_DEPTH)) control(    // Instantiate the configuration and status registers, using this FIFO capacity.
        .clk(s_axi_aclk),                               // Clock the register bank from the peripheral's shared clock.
        .rst_n(s_axi_aresetn),                          // Supply the register bank with the shared active-low synchronous reset.
        .wr_en(wr_en),                                  // Tell the register bank when the adapter requests a write.
        .wr_addr(wr_addr),                              // Tell the register bank which byte offset the write targets.
        .wr_data(wr_data),                              // Supply the register bank with the requested 32-bit write value.
        .wr_strb(wr_strb),                              // Tell the register bank which of the four bytes the write may update.
        .wr_error(wr_error),                            // Return the register bank's write-rejection indication to the adapter.
        .rd_addr(rd_addr),                              // Tell the register bank which byte offset the read targets.
        .rd_data(rd_data),                              // Return the selected register's read value to the adapter.
        .rd_error(rd_error),                            // Return the register bank's read-rejection indication to the adapter.
        .start(start),                                  // Route the register bank's accepted START command to the counter.
        .word_count(word_count),                        // Route the stored packet length from the register bank to the counter.
        .start_value(start_value),                      // Route the stored starting number from the register bank to the counter.
        .source_busy(source_busy),                      // Report counter activity to the register bank for status and START validation.
        .fifo_level(fifo_level_32),                     // Supply the zero-extended FIFO occupancy for status readback and START validation.
        .stream_fire(m_axis_tvalid && m_axis_tready),   // Tell the register bank a word transfers when output TVALID and TREADY are both high.
        .stream_last(m_axis_tlast)                      // Supply the output TLAST marker so the register bank recognizes acceptance of the final word.
    );

    counter_source source(                              // Instantiate the counter and drive it from the software-visible configuration.
        .clk(s_axi_aclk),                               // Clock the counter from the peripheral's shared clock.
        .rst_n(s_axi_aresetn),                          // Supply the counter with the shared active-low synchronous reset.
        .start(start),                                  // Tell the idle counter when to capture its configuration and begin generating a packet.
        .word_count(word_count),                        // Supply the number of words the counter must generate for the new packet.
        .start_value(start_value),                      // Supply the first number the counter must generate for the new packet.
        .busy(source_busy),                             // Report whether the counter is still supplying the current packet to the FIFO.
        .m_axis_tdata(source_data),                     // Route the counter's current 32-bit output word toward the FIFO.
        .m_axis_tlast(source_last),                     // Route the counter's final-word marker toward the FIFO.
        .m_axis_tvalid(source_valid),                   // Tell the FIFO when the counter's output word and marker are valid.
        .m_axis_tready(source_ready)                    // Let the counter advance only when its valid word is accepted by the FIFO.
    );

    axis_fifo #(.DEPTH(FIFO_DEPTH)) fifo(               // Instantiate the FIFO that buffers the generated packet.
        .clk(s_axi_aclk),                               // Clock the FIFO from the peripheral's shared clock.
        .rst_n(s_axi_aresetn),                          // Supply the FIFO with the shared active-low synchronous reset.
        .s_axis_tdata(source_data),                     // Feed the counter's 32-bit payload into the FIFO's input stream.
        .s_axis_tlast(source_last),                     // Feed the counter's final-word marker into the FIFO to store alongside its payload.
        .s_axis_tvalid(source_valid),                   // Tell the FIFO when the counter offers a valid input word.
        .s_axis_tready(source_ready),                   // Return the FIFO's input readiness to the counter.
        .m_axis_tdata(m_axis_tdata),                    // Expose the oldest buffered payload at the peripheral's output stream.
        .m_axis_tlast(m_axis_tlast),                    // Expose the final-word marker stored with that output payload.
        .m_axis_tvalid(m_axis_tvalid),                  // Expose the FIFO's output-valid indication to the downstream receiver.
        .m_axis_tready(m_axis_tready),                  // Let the FIFO remove its output word when it is valid and the downstream receiver is ready.
        .level(fifo_level)                              // Observe the FIFO occupancy for the register bank's status readback.
    );
endmodule
