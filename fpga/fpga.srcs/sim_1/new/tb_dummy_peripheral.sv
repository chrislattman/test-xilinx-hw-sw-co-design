// Self-checking AXI4-Lite testbench for the complete dummy peripheral and its Vivado wrapper.
module tb_dummy_peripheral;                             // Begin the simulation-only testbench.
    timeunit 1ns;                                       // Use nanoseconds for delays written without a unit suffix.
    timeprecision 1ps;                                  // Resolve simulation events to one picosecond.

    logic        s_axi_aclk    = '0;                    // Drive the DUT's s_axi_aclk input from this testbench.
    logic        s_axi_aresetn = '0;                    // Drive the DUT's s_axi_aresetn input from this testbench.
    logic [11:0] s_axi_awaddr  = '0;                    // Drive the DUT's s_axi_awaddr input from this testbench.
    logic [2:0]  s_axi_awprot  = '0;                    // Drive the DUT's s_axi_awprot input from this testbench.
    logic        s_axi_awvalid = '0;                    // Drive the DUT's s_axi_awvalid input from this testbench.
    wire         s_axi_awready;                         // Observe the DUT's s_axi_awready output.
    logic [31:0] s_axi_wdata   = '0;                    // Drive the DUT's s_axi_wdata input from this testbench.
    logic [3:0]  s_axi_wstrb   = '0;                    // Drive the DUT's s_axi_wstrb input from this testbench.
    logic        s_axi_wvalid  = '0;                    // Drive the DUT's s_axi_wvalid input from this testbench.
    wire         s_axi_wready;                          // Observe the DUT's s_axi_wready output.
    wire [1:0]   s_axi_bresp;                           // Observe the DUT's s_axi_bresp output.
    wire         s_axi_bvalid;                          // Observe the DUT's s_axi_bvalid output.
    logic        s_axi_bready  = '0;                    // Drive the DUT's s_axi_bready input from this testbench.
    logic [11:0] s_axi_araddr  = '0;                    // Drive the DUT's s_axi_araddr input from this testbench.
    logic [2:0]  s_axi_arprot  = '0;                    // Drive the DUT's s_axi_arprot input from this testbench.
    logic        s_axi_arvalid = '0;                    // Drive the DUT's s_axi_arvalid input from this testbench.
    wire         s_axi_arready;                         // Observe the DUT's s_axi_arready output.
    wire [31:0]  s_axi_rdata;                           // Observe the DUT's s_axi_rdata output.
    wire [1:0]   s_axi_rresp;                           // Observe the DUT's s_axi_rresp output.
    wire         s_axi_rvalid;                          // Observe the DUT's s_axi_rvalid output.
    logic        s_axi_rready  = '0;                    // Drive the DUT's s_axi_rready input from this testbench.

    always #5ns s_axi_aclk = ~s_axi_aclk;               // Generate a 100 MHz clock with a 10 ns period.

    dummy_bd dut(                                       // Test the same Verilog wrapper that will be added to the block design.
        .s_axi_aclk(s_axi_aclk),                        // Connect the testbench's s_axi_aclk signal.
        .s_axi_aresetn(s_axi_aresetn),                  // Connect the testbench's s_axi_aresetn signal.
        .s_axi_awaddr(s_axi_awaddr),                    // Connect the testbench's s_axi_awaddr signal.
        .s_axi_awprot(s_axi_awprot),                    // Connect the testbench's s_axi_awprot signal.
        .s_axi_awvalid(s_axi_awvalid),                  // Connect the testbench's s_axi_awvalid signal.
        .s_axi_awready(s_axi_awready),                  // Connect the testbench's s_axi_awready signal.
        .s_axi_wdata(s_axi_wdata),                      // Connect the testbench's s_axi_wdata signal.
        .s_axi_wstrb(s_axi_wstrb),                      // Connect the testbench's s_axi_wstrb signal.
        .s_axi_wvalid(s_axi_wvalid),                    // Connect the testbench's s_axi_wvalid signal.
        .s_axi_wready(s_axi_wready),                    // Connect the testbench's s_axi_wready signal.
        .s_axi_bresp(s_axi_bresp),                      // Connect the testbench's s_axi_bresp signal.
        .s_axi_bvalid(s_axi_bvalid),                    // Connect the testbench's s_axi_bvalid signal.
        .s_axi_bready(s_axi_bready),                    // Connect the testbench's s_axi_bready signal.
        .s_axi_araddr(s_axi_araddr),                    // Connect the testbench's s_axi_araddr signal.
        .s_axi_arprot(s_axi_arprot),                    // Connect the testbench's s_axi_arprot signal.
        .s_axi_arvalid(s_axi_arvalid),                  // Connect the testbench's s_axi_arvalid signal.
        .s_axi_arready(s_axi_arready),                  // Connect the testbench's s_axi_arready signal.
        .s_axi_rdata(s_axi_rdata),                      // Connect the testbench's s_axi_rdata signal.
        .s_axi_rresp(s_axi_rresp),                      // Connect the testbench's s_axi_rresp signal.
        .s_axi_rvalid(s_axi_rvalid),                    // Connect the testbench's s_axi_rvalid signal.
        .s_axi_rready(s_axi_rready)                     // Connect the testbench's s_axi_rready signal.
    );

    task automatic axi_write(                           // Define a register write with independently driven AXI address and data channels.
        input logic [11:0] address,                     // Specify the register's byte offset.
        input logic [31:0] data,                        // Specify the register write value.
        input logic [3:0]  strobes,                     // Specify which byte lanes the write may change.
        input int ordering                              // Use zero for simultaneous channels, one for address first, or two for data first.
    );
        fork                                            // Drive address, data, and response handling concurrently.
            begin : send_address                        // Begin the independently scheduled write-address channel.
                @(negedge s_axi_aclk);                  // Change master outputs away from the DUT's sampling edge.
                if (ordering == 2) begin                // Delay the address when testing data arriving first.
                    repeat (3) @(negedge s_axi_aclk);   // Let the data channel arrive three cycles before the address.
                end                                     // Finish the optional write-address delay.
                s_axi_awaddr = address;                 // Present the write address.
                s_axi_awvalid = 1'b1;                   // Offer a valid write address to the DUT.
                do @(posedge s_axi_aclk);               // Sample address readiness on a rising clock edge.
                while (s_axi_awready !== 1'b1);         // Keep the address valid until it is accepted.
                @(negedge s_axi_aclk);                  // Wait until after the accepted rising edge.
                s_axi_awvalid = 1'b0;                   // Stop offering the accepted write address.
            end                                         // Finish the write-address thread.
            begin : send_data                           // Begin the independently scheduled write-data channel.
                @(negedge s_axi_aclk);                  // Change master outputs on a falling edge.
                if (ordering == 1) begin                // Delay the data when testing the address arriving first.
                    repeat (3) @(negedge s_axi_aclk);   // Let the address channel arrive three cycles before the data.
                end                                     // Finish the optional write-data delay.
                s_axi_wdata = data;                     // Present the register write value.
                s_axi_wstrb = strobes;                  // Present the write's byte enables.
                s_axi_wvalid = 1'b1;                    // Offer valid write data to the DUT.
                do @(posedge s_axi_aclk);               // Sample data readiness on a rising clock edge.
                while (s_axi_wready !== 1'b1);          // Keep the data valid until it is accepted.
                @(negedge s_axi_aclk);                  // Wait until after the accepted rising edge.
                s_axi_wvalid = 1'b0;                    // Stop offering the accepted write data.
            end                                         // Finish the write-data thread.
            begin : accept_write_response               // Begin write-response checking and backpressure.
                @(negedge s_axi_aclk);                  // Set response readiness on a falling edge.
                s_axi_bready = 1'b0;                    // Initially prevent the DUT's write response from being consumed.
                do @(posedge s_axi_aclk);               // Look for the response on rising clock edges.
                while (s_axi_bvalid !== 1'b1);          // Wait until the DUT offers a write response.
                if (s_axi_bresp !== 2'b00) begin        // Require an OKAY response with the chosen generator options.
                    $fatal(1, "Unexpected write response at 0x%03h", address);  // Fail if the response code is unexpected.
                end                                     // Finish the response-code check.
                repeat (3) begin                        // Keep the response stalled for three more clock edges.
                    @(posedge s_axi_aclk);              // Check that the held response remains valid each cycle.
                    if ((s_axi_bvalid !== 1'b1) || (s_axi_bresp !== 2'b00)) begin   // Detect a dropped or changed response during backpressure.
                        $fatal(1, "Write response changed while stalled");  // Fail on a response-channel protocol violation.
                    end                                 // Finish this cycle's response-stability check.
                end                                     // Finish the response backpressure interval.
                @(negedge s_axi_aclk);                  // Change readiness away from the DUT's active edge.
                s_axi_bready = 1'b1;                    // Allow the held write response to be accepted.
                @(posedge s_axi_aclk);                  // Complete the response handshake.
                @(negedge s_axi_aclk);                  // Wait until the response has been consumed.
                s_axi_bready = 1'b0;                    // Return response readiness to its idle value.
            end                                         // Finish the write-response thread.
        join                                            // Wait for all three write-channel threads to finish.
    endtask

    task automatic expect_read(                         // Define a read that checks both register data and response stability.
        input logic [11:0] address,                     // Specify the register's byte offset.
        input logic [31:0] expected                     // Specify the complete 32-bit value expected from this register.
    );
        logic [31:0] observed;                          // Hold the first valid read value for later comparisons.
        @(negedge s_axi_aclk);                          // Start the transaction away from the DUT's sampling edge.
        s_axi_araddr = address;                         // Present the register read address.
        s_axi_arvalid = 1'b1;                           // Offer a valid read address.
        s_axi_rready = 1'b0;                            // Hold off consuming the eventual read response.
        do @(posedge s_axi_aclk);                       // Sample address readiness on rising clock edges.
        while (s_axi_arready !== 1'b1);                 // Keep the read address valid until it is accepted.
        @(negedge s_axi_aclk);                          // Wait until after address acceptance.
        s_axi_arvalid = 1'b0;                           // Stop offering the accepted read address.
        do @(posedge s_axi_aclk);                       // Look for valid read data on rising clock edges.
        while (s_axi_rvalid !== 1'b1);                  // Wait until a read response is available.
        observed = s_axi_rdata;                         // Remember the response's initial data value.
        if ((s_axi_rresp !== 2'b00) || (observed !== expected)) begin   // Require an OKAY response and the expected register contents.
            $fatal(1, "Read 0x%03h: expected 0x%08h, got 0x%08h", address, expected, observed); // Report the register and values when a check fails.
        end                                             // Finish the initial read-response check.
        repeat (3) begin                                // Exercise read-response backpressure for three more cycles.
            @(posedge s_axi_aclk);                      // Inspect the held response at each rising edge.
            if ((s_axi_rvalid !== 1'b1) || (s_axi_rresp !== 2'b00) || (s_axi_rdata !== observed)) begin // Require the response and its data to remain stable while stalled.
                $fatal(1, "Read response changed while stalled");   // Fail on a read-response protocol violation.
            end                                         // Finish this cycle's stability check.
        end                                             // Finish the read-response backpressure interval.
        @(negedge s_axi_aclk);                          // Change readiness away from the DUT's sampling edge.
        s_axi_rready = 1'b1;                            // Allow the checked response to be consumed.
        @(posedge s_axi_aclk);                          // Complete the read-response handshake.
        @(negedge s_axi_aclk);                          // Wait until after the response is consumed.
        s_axi_rready = 1'b0;                            // Return read readiness to its idle value.
    endtask

    always @(posedge s_axi_aclk) begin                  // Check the hardware mirror on every active clock edge.
        logic expected_mirror;                          // Remember the control value present just before this edge.
        expected_mirror = s_axi_aresetn ? dut.u_dummy.hwif_out.control.sw_bit.value : 1'b0; // Expect the pre-edge control value, or zero while reset is asserted.
        #1ps;                                           // Let the DUT's nonblocking register assignments take effect.
        if (dut.u_dummy.u_regs.field_storage.status.hw_bit.value !== expected_mirror) begin // Inspect generated storage to check the exact one-cycle mirror delay.
            $fatal(1, "Mirror register violated its reset or one-cycle update rule");   // Fail if reset, a software write, or hardware copying produces the wrong mirror value.
        end                                             // Finish the mirror-value comparison.
    end

    initial begin                                       // Begin the sequential functional tests.
        repeat (5) @(negedge s_axi_aclk);               // Keep reset asserted across several rising edges.
        s_axi_aresetn = 1'b1;                           // Release reset on a falling edge.
        expect_read(12'h000, 32'd0);                    // Check the control register's reset value.
        expect_read(12'h004, 32'd0);                    // Check the mirror register's reset value.
        axi_write(12'h000, 32'd1, 4'hf, 1);             // Write one with the address arriving before the data.
        expect_read(12'h000, 32'd1);                    // Check software readback of its own control bit.
        expect_read(12'h004, 32'd1);                    // Check that hardware copied one into the mirror.
        axi_write(12'h004, 32'd0, 4'hf, 0);             // Try to overwrite the read-only mirror with the opposite value.
        expect_read(12'h004, 32'd1);                    // Check that a software write cannot change the mirror.
        axi_write(12'h000, 32'd0, 4'h0, 0);             // Issue a write with every byte lane disabled.
        expect_read(12'h000, 32'd1);                    // Check that a zero-strobe write leaves the control bit unchanged.
        axi_write(12'h000, 32'd0, 4'he, 2);             // Write only upper byte lanes, with data arriving before the address.
        expect_read(12'h000, 32'd1);                    // Check that writes excluding byte zero cannot change bit zero.
        axi_write(12'h000, 32'hffff_ffff, 4'hf, 0);     // Try to set the control bit and all reserved bits.
        expect_read(12'h000, 32'd1);                    // Check that reserved bits still read as zero.
        axi_write(12'h000, 32'd0, 4'h1, 2);             // Clear the control bit using a write to byte zero.
        expect_read(12'h000, 32'd0);                    // Check control readback after clearing the bit.
        expect_read(12'h004, 32'd0);                    // Check that hardware also cleared the mirror.
        axi_write(12'h004, 32'd1, 4'hf, 1);             // Try to set the read-only mirror while the control bit is zero.
        expect_read(12'h004, 32'd0);                    // Check that read-only protection also prevents software from setting the bit.
        axi_write(12'h008, 32'hffff_ffff, 4'hf, 0);     // Write an unused offset with default no-error generator settings.
        expect_read(12'h008, 32'd0);                    // Check that an unused offset returns zero.
        expect_read(12'h000, 32'd0);                    // Check that the unused offset does not alias the control register.
        axi_write(12'h000, 32'd1, 4'hf, 0);             // Set the control bit before testing another reset.
        expect_read(12'h004, 32'd1);                    // Confirm that the mirror is one before reset.
        @(negedge s_axi_aclk);                          // Assert reset away from the DUT's sampling edge.
        s_axi_aresetn = 1'b0;                           // Reset the bus adapter and both registers.
        repeat (5) @(negedge s_axi_aclk);               // Hold reset across five clock cycles.
        s_axi_aresetn = 1'b1;                           // Release reset on a falling edge.
        expect_read(12'h000, 32'd0);                    // Check that reset cleared the software control bit.
        expect_read(12'h004, 32'd0);                    // Check that reset cleared the hardware mirror bit.
        $display("PASS: dummy peripheral access, mirror, reset, byte strobes, and AXI handshakes"); // Report success only after all checks have completed.
        $finish;                                        // End simulation so the free-running clock does not keep it alive.
    end

    initial begin                                       // Set an overall timeout for any stalled AXI transaction.
        #100us;                                         // Allow much longer than the normal test duration.
        $fatal(1, "Timeout: dummy peripheral test did not finish"); // Fail instead of leaving the simulation running indefinitely.
    end
endmodule
