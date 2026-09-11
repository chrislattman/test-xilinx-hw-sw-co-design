// One standalone Vivado testbench for the AXI adapter, capture registers, counter, and FIFO together.
// axi_lite_bfm supplies the register transactions that A9 software will eventually generate.
// This testbench takes longer than the default 1000 ns Vivado gives simulations, so you will need to click Run -> Run All after running this simulation.
module tb_capture_peripheral;                           // Define the testbench module to select as the simulation top; it has no external ports.
    timeunit 1ns;                                       // Use nanoseconds as the time unit for delays in this module.
    timeprecision 1ps;                                  // Resolve simulation delays in this module to picosecond precision.
    localparam int FIFO_DEPTH = 4;                      // Fix the test FIFO capacity at four words so short captures can fill it.
    localparam logic [11:0] REG_COMMAND = 12'h000;      // Define the byte offset of COMMAND, where writing one to bit zero requests START.
    localparam logic [11:0] REG_STATUS = 12'h004;       // Define the byte offset of STATUS: bit 0 ACTIVE, bit 1 EMPTY, bit 2 FULL, and bit 3 SOURCE_BUSY.
    localparam logic [11:0] REG_WORD_COUNT = 12'h008;   // Define the byte offset of WORD_COUNT, the number of words requested for a capture.
    localparam logic [11:0] REG_START_VALUE = 12'h00c;  // Define the byte offset of START_VALUE, the first number requested for a capture.
    localparam logic [11:0] REG_FIFO_LEVEL = 12'h010;   // Define the byte offset of FIFO_LEVEL, the number of words currently buffered.
    localparam logic [11:0] REG_ACCEPTED = 12'h014;     // Define the byte offset of the count of words accepted at the peripheral output during the latest capture.

    logic clk = 1'b0;                                   // Declare the testbench clock and initialize it low before clock generation starts.
    logic rst_n = 1'b0;                                 // Declare the active-low reset and initialize it low so the test starts with reset asserted.
    always #5ns clk = ~clk;                             // Toggle the clock every 5 ns, producing a 10 ns period and a 100 MHz clock.
    axi_lite_bfm bus(clk);                              // Instantiate the AXI4-Lite bus-model interface, including its read/write tasks, and connect its clock.

    logic [31:0] data;                                  // Observe the 32-bit payload offered by the peripheral on its output stream.
    logic [31:0] value;                                 // Hold register-read results returned to the main test sequence by the bus model.
    logic [3:0] keep;                                   // Observe the four TKEEP bits, one valid-byte indication for each payload byte.
    logic valid;                                        // Observe TVALID, which indicates that the peripheral is offering a valid stream word.
    logic last;                                         // Observe TLAST, which marks the final word of a capture packet.
    logic ready = 1'b0;                                 // Drive the receiver's TREADY signal, initially low so no stream word can be accepted.
    bit force_stall = 1;                                // Initially force the receiver to pause; capture tests can release this pause or use it to fill the FIFO.
    bit checking = 0;                                   // Initially mark captures inactive, so the stream monitor treats any accepted word as unexpected.
    bit was_stalled = 0;                                // Track whether the previous rising edge stalled a valid word; initially there is no previous stall.
    logic [36:0] held;                                  // Hold the previous sample of four TKEEP bits, one TLAST bit, and 32 data bits for stability checks.
    logic [31:0] expected_start = 32'd0;                // Store the expected first number for the current capture, initially zero.
    int expected_count = 0;                             // Store the expected number of output words for the current capture, initially zero.
    int received = 0;                                   // Count output words actually accepted during the current capture, starting at zero.
    int last_stalls = 0;                                // Count deliberate pauses on the final word of the current capture, starting at zero.
    int stream_cycle = 0;                               // Track the cycle index used to generate the repeating readiness pattern, starting at zero.

    capture_peripheral #(.FIFO_DEPTH(FIFO_DEPTH)) dut(  // Instantiate the capture peripheral as dut and configure its FIFO to hold FIFO_DEPTH words.
        .s_axi_aclk(clk),                               // Connect the testbench clock to the shared clock input of the complete peripheral.
        .s_axi_aresetn(rst_n),                          // Connect the testbench's active-low reset to the complete peripheral.
        .s_axi_awaddr(bus.awaddr),                      // Pass the bus master's write-register byte offset into the peripheral.
        .s_axi_awprot(bus.awprot),                      // Pass the bus master's write-access attributes into the peripheral.
        .s_axi_awvalid(bus.awvalid),                    // Tell the peripheral when the bus master is offering a valid write address.
        .s_axi_awready(bus.awready),                    // Return the peripheral's write-address readiness to the bus master.
        .s_axi_wdata(bus.wdata),                        // Pass the bus master's 32-bit register-write value into the peripheral.
        .s_axi_wstrb(bus.wstrb),                        // Pass the four write-byte enables into the peripheral, one bit per byte.
        .s_axi_wvalid(bus.wvalid),                      // Tell the peripheral when the bus master is offering valid write data.
        .s_axi_wready(bus.wready),                      // Return the peripheral's write-data readiness to the bus master.
        .s_axi_bresp(bus.bresp),                        // Return the peripheral's write-response code to the bus master.
        .s_axi_bvalid(bus.bvalid),                      // Tell the bus master when the peripheral is holding a valid write response.
        .s_axi_bready(bus.bready),                      // Tell the peripheral when the bus master is ready to accept a write response.
        .s_axi_araddr(bus.araddr),                      // Pass the bus master's read-register byte offset into the peripheral.
        .s_axi_arprot(bus.arprot),                      // Pass the bus master's read-access attributes into the peripheral.
        .s_axi_arvalid(bus.arvalid),                    // Tell the peripheral when the bus master is offering a valid read address.
        .s_axi_arready(bus.arready),                    // Return the peripheral's read-address readiness to the bus master.
        .s_axi_rdata(bus.rdata),                        // Return the peripheral's 32-bit register-read value to the bus master.
        .s_axi_rresp(bus.rresp),                        // Return the peripheral's read-response code to the bus master.
        .s_axi_rvalid(bus.rvalid),                      // Tell the bus master when the peripheral is holding valid read data and a response code.
        .s_axi_rready(bus.rready),                      // Tell the peripheral when the bus master is ready to accept a read response.
        .m_axis_tdata(data),                            // Connect the FIFO's outgoing payload to the testbench's data observation signal.
        .m_axis_tkeep(keep),                            // Connect the stream's outgoing byte-valid mask to the testbench's keep observation signal.
        .m_axis_tlast(last),                            // Connect the outgoing final-word marker to the testbench's last observation signal.
        .m_axis_tvalid(valid),                          // Connect outgoing stream validity to the testbench's valid observation signal.
        .m_axis_tready(ready)                           // Supply the testbench receiver's readiness to control when valid output words are accepted.
    );                                                  // Finish the capture peripheral's port connections.

    always @(negedge clk) begin                         // Update receiver readiness on falling edges, away from the hardware's rising sampling edges.
        if (!rst_n) begin                               // Initialize the receiver's controls whenever the active-low reset is asserted.
            ready = 0;                                  // Keep the receiver from accepting stream words during reset.
            last_stalls = 0;                            // Clear the count of deliberate pauses on a packet's final word.
            stream_cycle = 0;                           // Reset the cycle index used by the repeating readiness pattern.
        end else if (force_stall) begin                 // Apply a forced pause when a capture test needs the FIFO to fill before any word is consumed.
            ready = 0;                                  // Keep TREADY low so the receiver refuses output words throughout the forced pause.
        end else if (valid && last && last_stalls < 3) begin    // Apply up to three deliberate pauses when a valid final word is offered.
            ready = 0;                                  // Keep TREADY low so this final word and its marker must remain stable.
            last_stalls++;                              // Count this deliberate final-word pause.
        end else begin                                  // Use the ordinary repeating readiness pattern when no reset or special pause applies.
            ready = ((stream_cycle % 4) != 0);          // Set readiness high for three out of four pattern cycles; the fourth cycle stalls.
            stream_cycle++;                             // Advance the cycle index for the next use of the ordinary readiness pattern.
        end                                             // Finish choosing readiness for the next rising clock edge.
    end                                                 // End the downstream receiver process.

    always @(posedge clk) begin                         // Check the output stream on rising edges, when a valid and ready word transfers.
        if (!rst_n) begin                               // Reset the stream monitor's bookkeeping while reset is asserted.
            received = 0;                               // Clear the count of output words accepted by the receiver.
            was_stalled = 0;                            // Forget any earlier stall so reset does not require an old word to remain on the stream.
        end else begin                                  // Run the stream checks during normal operation.
            if (was_stalled && (valid !== 1'b1 || {keep,last,data} !== held))   // Detect loss of TVALID or a change in payload or sideband bits after the previous edge stalled a word.
                $fatal(1, "AXI stream changed while stalled");  // Stop the simulation with an error if a stalled word changes or loses its valid indication.
            held = {keep,last,data};                    // Save the current payload and sideband bits before this edge's nonblocking hardware updates take effect.
            was_stalled = valid && !ready;              // Remember whether this edge leaves a valid word unaccepted because the receiver is not ready.
            if (valid && ready) begin                   // Check and count a word only when TVALID and TREADY are both high at this edge.
                if (!checking || received >= expected_count)    // Detect an accepted word outside an expected capture or beyond its requested length.
                    $fatal(1, "Unexpected extra stream word");  // Stop with an error if an unsolicited or excess stream word is accepted.
                if (data !== expected_start + 32'(received))    // Compare the payload with the first number plus this word's zero-based index, using 32-bit arithmetic.
                    $fatal(1, "Data mismatch at word %0d", received);  // Stop with an error and report the index of a word whose payload is incorrect.
                if (keep !== 4'hf)                      // Check that TKEEP marks all four bytes of the accepted word as valid.
                    $fatal(1, "Invalid TKEEP");         // Stop with an error if any payload byte lacks its required valid-byte indication.
                if (last !== (received == expected_count-1))    // Require TLAST to be high exactly when this is the final requested word.
                    $fatal(1, "Incorrect TLAST");       // Stop with an error if TLAST appears too early or is missing from the final word.
                received++;                             // Count the accepted word after all of its checks pass.
            end                                         // End the checks for this accepted word.
        end                                             // End the normal-operation branch of the stream monitor.
    end                                                 // End the stream monitor process.

    task automatic check_reg(                           // Define a register-read check with separate argument and local-variable storage for each call.
        input logic [11:0] address,                     // Accept the byte offset of the register to check.
        input logic [31:0] expected_value,              // Accept the value that the selected register bits are expected to contain.
        input logic [31:0] mask = 32'hffffffff          // Select which bits to compare; the default mask selects all 32 bits.
    );                                                  // Finish the register-check task's argument list.
        logic [31:0] got;                               // Hold the register value returned during this invocation of the task.
        bus.read_reg(address, got, 2);                  // Read the register into got while deliberately stalling acceptance of its read response for two cycles.
        if ((got & mask) !== (expected_value & mask))   // Compare the selected bits using case inequality, so unexpected X or Z bits cause a mismatch.
            $fatal(1, "Register %h: expected %h, got %h (mask %h)", address, expected_value, got, mask);    // Stop with an error and report the register offset, expected value, returned value, and mask.
    endtask

    task automatic run_capture(                         // Define a task that configures a capture through AXI4-Lite and checks its stream and register results.
        input logic [31:0] first,                       // Accept the first number to request and expect in the capture packet.
        input int count,                                // Accept the number of full 32-bit words to request and expect.
        input bit fill_fifo                             // Choose whether to pause the receiver and test the FIFO-full state before draining.
    );                                                  // Finish the capture task's argument list.
        @(negedge clk);                                 // Wait for a falling clock edge before preparing the next capture's test controls.
        #1ns;                                           // Wait another nanosecond so the receiver's falling-edge process finishes before controls change.
        expected_start = first;                         // Tell the stream checker which number should appear first in this capture.
        expected_count = count;                         // Tell the stream checker how many output words to expect in this capture.
        received = 0;                                   // Restart the accepted-output count at zero for this capture.
        checking = 1;                                   // Mark this capture as expected so the monitor can check its words against the requested sequence.
        was_stalled = 0;                                // Clear the previous-stall flag before the new capture begins.
        last_stalls = 0;                                // Restart the count of deliberate pauses on this capture's final word.
        stream_cycle = 0;                               // Restart the cycle index for the ordinary readiness pattern.
        force_stall = fill_fifo;                        // Apply the requested forced pause while the counter initially fills the FIFO.
        bus.write_reg(REG_WORD_COUNT, 32'(count), 4'hf, 0, 3, 2);   // Program the word count with all bytes enabled, delaying write data by three cycles and the response acceptance by two.
        bus.write_reg(REG_START_VALUE, first, 4'hf, 3, 0, 2);   // Program the first number, delaying the write address by three cycles and the response acceptance by two.
        bus.write_reg(REG_COMMAND, 32'd1, 4'hf, 0, 0, 2);   // Write one to command bit zero to request START, then stall write-response acceptance for two cycles.
        if (fill_fifo) begin                            // Check full-FIFO behavior when the receiver is deliberately paused.
            repeat (FIFO_DEPTH + 6) @(posedge clk);     // Wait enough rising edges for the counter to fill the small FIFO and encounter backpressure.
            #2ns;                                       // Wait two nanoseconds for the last rising edge's hardware updates to settle.
            check_reg(REG_FIFO_LEVEL, 32'(FIFO_DEPTH)); // Verify that the FIFO contains exactly FIFO_DEPTH words.
            check_reg(REG_STATUS, 32'h5, 32'h5);        // Check STATUS bits zero and two, requiring ACTIVE and FIFO_FULL to both be high.
            check_reg(REG_ACCEPTED, 32'd0);             // Verify that no words have left the FIFO while the receiver is paused.
            bus.write_reg(REG_WORD_COUNT, 32'd99, 4'hf, 0, 0, 2, 2'b10);    // Attempt to change WORD_COUNT during capture and require the SLVERR response code 2'b10.
            check_reg(REG_WORD_COUNT, 32'(count));      // Verify that the rejected write left the original word count unchanged.
            bus.write_reg(REG_COMMAND, 32'd1, 4'hf, 0, 0, 2, 2'b10);    // Attempt a second START during capture and require the SLVERR response code 2'b10.
            @(negedge clk);                             // Wait for a falling clock edge before preparing to release the forced output pause.
            #1ns;                                       // Wait another nanosecond so the readiness driver runs before the pause control changes.
            force_stall = 0;                            // Release the forced pause so the receiver can begin draining on subsequent cycles.
        end                                             // End the checks performed while the FIFO is held full.
        while (received < count) @(posedge clk);        // Wait on rising edges until the stream checker has counted the complete requested packet.
        #2ns;                                           // Wait for the final-word hardware updates to settle before reading status.
        check_reg(REG_STATUS, 32'h2, 32'hf);            // Require only FIFO_EMPTY to be high among the four status bits after the packet drains.
        check_reg(REG_FIFO_LEVEL, 32'd0);               // Verify that no words remain buffered after the capture.
        check_reg(REG_ACCEPTED, 32'(count));            // Verify that the accepted-word register equals this capture's length rather than a lifetime total.
        if (last_stalls != 3)                           // Check that the receiver exercised all three deliberate pauses on the final word.
            $fatal(1, "Final-word stalls were not exercised");  // Stop with an error if the required final-word pause test was not completed.
        checking = 0;                                   // Mark the capture complete so any subsequently accepted stream word is unexpected.
        $display("Capture passed: first=%h words=%0d", first, count); // Print the starting number and word count of this successfully checked capture.
    endtask

    initial begin                                       // Run the main test sequence once, alongside the clock, receiver, monitor, and timeout processes.
        bus.idle();                                     // Initialize the bus master's transaction controls to their idle state.
        repeat (4) @(posedge clk);                      // Keep reset asserted across four rising clock edges.
        @(negedge clk);                                 // Wait for a falling clock edge before preparing to deassert reset.
        #1ns;                                           // Wait another nanosecond so the receiver finishes its falling-edge reset handling.
        rst_n = 1'b1;                                   // Deassert the active-low reset so the hardware resumes normal operation on rising clock edges.
        check_reg(REG_COMMAND, 32'd0);                  // Verify that COMMAND reads as zero instead of retaining a START request.
        check_reg(REG_STATUS, 32'h2);                   // Verify that the peripheral starts idle with only the FIFO_EMPTY status bit set.
        check_reg(REG_WORD_COUNT, 32'd1024);            // Verify the default capture length of 1024 words.
        check_reg(REG_START_VALUE, 32'd0);              // Verify the default starting number of zero.
        check_reg(REG_FIFO_LEVEL, 32'd0);               // Verify that FIFO occupancy is zero after reset.
        check_reg(REG_ACCEPTED, 32'd0);                 // Verify that the outgoing accepted-word count is zero after reset.
        fork                                            // Start the following write and read in parallel to exercise the independent AXI channels.
            bus.write_reg(REG_START_VALUE, 32'd55, 4'hf, 0, 3, 2);  // Write START_VALUE while the concurrent read transaction is also in progress.
            bus.read_reg(REG_WORD_COUNT, value, 4);     // Read WORD_COUNT into value while deliberately stalling read-response acceptance for four cycles.
        join                                            // Wait for both parallel transactions to finish before checking their results.
        if (value !== 32'd1024)                         // Check that the concurrent write did not corrupt the default WORD_COUNT readback.
            $fatal(1, "Concurrent read returned incorrect data");  // Stop with an error if the simultaneous read returned an unexpected value.
        check_reg(REG_START_VALUE, 32'd55);             // Verify that the concurrent write successfully changed START_VALUE to 55.
        bus.write_reg(REG_START_VALUE, 32'h11223344);   // Write a known four-byte pattern before testing selective byte updates.
        bus.write_reg(REG_START_VALUE, 32'haabbccdd, 4'b0101, 3, 0, 3); // Use WSTRB=0101 to replace byte zero with DD and byte two with BB, preserving the other bytes.
        check_reg(REG_START_VALUE, 32'h11bb33dd);       // Verify the merged value after the selective byte write.
        bus.write_reg(REG_START_VALUE, 32'd0, 4'b0000); // Issue a write with all byte strobes disabled, requesting no byte updates.
        check_reg(REG_START_VALUE, 32'h11bb33dd);       // Verify that disabling all write strobes preserved the previous register value.
        bus.write_reg(REG_STATUS, 32'd0, 4'hf, 0, 0, 2, 2'b10); // Attempt to write read-only STATUS and require a SLVERR response.
        bus.write_reg(12'h100, 32'd0, 4'hf, 0, 0, 2, 2'b10);    // Attempt to write an unmapped register offset and require a SLVERR response.
        bus.read_reg(12'h100, value, 2, 2'b10);         // Attempt to read an unmapped register offset and require a SLVERR response.
        bus.read_reg(12'h009, value, 2, 2'b10);         // Attempt to read the unaligned byte offset 0x009 and require a SLVERR response.
        bus.write_reg(REG_WORD_COUNT, 32'd0);           // Set WORD_COUNT to zero to test rejection of a zero-length capture.
        bus.write_reg(REG_COMMAND, 32'd1, 4'hf, 0, 0, 2, 2'b10);    // Request START with a zero word count and require a SLVERR response.
        check_reg(REG_STATUS, 32'h2);                   // Verify that the rejected zero-length START leaves the peripheral idle and empty.
        bus.write_reg(REG_WORD_COUNT, 32'd16);          // Restore a valid word count before testing a write that disables the command byte.
        bus.write_reg(REG_COMMAND, 32'd1, 4'b1110);     // Write COMMAND with byte zero disabled, so bit zero cannot request START.
        check_reg(REG_STATUS, 32'h2);                   // Verify that the disabled command byte leaves the peripheral idle and empty.
        check_reg(REG_ACCEPTED, 32'd0);                 // Verify that the register-access tests have not produced any accepted output words.
        run_capture(32'd10, 16, 1);                     // Capture 16 words starting at 10, testing a full FIFO and rejection of writes while active.
        run_capture(32'd41, 1, 0);                      // Capture the single word 41 without resetting, exercising a packet whose first word is also its last.
        run_capture(32'hffffffff, 3, 0);                // Capture FFFFFFFF, 00000000, and 00000001 to test 32-bit counter wraparound.
        run_capture(32'd100, 17, 0);                    // Capture 17 words starting at 100 to check another restart and fresh per-capture status and counts.
        $display("PASS: AXI4-Lite capture controls and streaming checks");  // Print PASS after every register-access and capture test has completed successfully.
        $finish;                                        // End the clock, stimulus, monitors, and timeout processes successfully.
    end

    initial begin                                       // Start an independent watchdog process to catch a hung test.
        #100us;                                         // Wait 100 microseconds from simulation start, well beyond the expected test duration.
        $fatal(1, "AXI4-Lite capture test timed out");  // Stop with a fatal error if the main test has not finished before the watchdog expires.
    end
endmodule
