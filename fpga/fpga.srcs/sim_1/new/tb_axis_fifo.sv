// Simulation-only FIFO test for Vivado; no VUnit includes or external test libraries are needed.
// This test drives both ends of the FIFO, standing in for the counter and DMA.
module tb_axis_fifo;                                    // Define the testbench to select as the simulation top.
    timeunit 1ns;                                       // Use nanoseconds as the simulation time unit.
    timeprecision 1ps;                                  // Use picosecond precision for delays.
    localparam int DEPTH = 4;                           // Four entries make full, empty, and pointer wraparound easy to see.

    logic clk = 1'b0;                                   // Start the simulated clock low.
    logic rst_n = 1'b0;                                 // Start with the active-low reset asserted.
    logic [31:0] s_data = 32'd0;                        // Testbench drives the incoming payload.
    logic s_last = 1'b0;                                // Testbench drives the incoming packet marker.
    logic s_valid = 1'b0;                               // Begin without offering an input word.
    logic s_ready;                                      // Observe whether the FIFO can accept that input word.

    logic [31:0] m_data;                                // Observe the FIFO's oldest stored payload.
    logic m_last;                                       // Observe its associated packet marker.
    logic m_valid;                                      // Observe whether an output word is available.
    logic m_ready = 1'b0;                               // Initially refuse output so we can fill the FIFO.
    logic [$clog2(DEPTH+1)-1:0] level;                  // Observe the number of stored words; three bits represent zero through four.

    logic [32:0] expected[$];                           // A simulation queue remembers every accepted {TLAST, data} pair in order.
    int accepted = 0, delivered = 0;                    // Count successful handshakes at the two ends.

    always #5ns clk = ~clk;                             // Generate the same 100 MHz clock used by the counter test.

    axis_fifo #(.DATA_WIDTH(32), .DEPTH(DEPTH)) dut(    // Override the FIFO's default capacity for this small simulation.
        .clk(clk),                                      // Supply the shared input/output clock.
        .rst_n(rst_n),                                  // Supply the reset driven by the testbench.
        .s_axis_tdata(s_data),                          // Feed the simulated source's payload into the FIFO.
        .s_axis_tlast(s_last),                          // Feed its packet marker into the FIFO.
        .s_axis_tvalid(s_valid),                        // Indicate when the simulated source is offering a word.
        .s_axis_tready(s_ready),                        // Observe the FIFO's response to the simulated source.
        .m_axis_tdata(m_data),                          // Observe the oldest stored payload.
        .m_axis_tlast(m_last),                          // Observe the marker attached to that payload.
        .m_axis_tvalid(m_valid),                        // Observe whether the FIFO is offering a word.
        .m_axis_tready(m_ready),                        // Control whether the simulated receiver accepts the word.
        .level(level)                                   // Observe occupancy for comparison with the simulation queue.
    );

    task automatic fifo_cycle(                          // Drive and check one clock cycle at both ends of the FIFO.
        input logic offer_word,                         // Choose whether the source offers an input word.
        input logic [31:0] input_data,                  // Choose that word's payload.
        input logic input_last,                         // Choose its final-word marker.
        input logic accept_output                       // Choose whether the destination is ready for an output word.
    );
        logic [32:0] oldest;                            // Temporarily hold an expected {TLAST, data} pair.
        @(negedge clk);                                 // Change driven inputs halfway between the DUT's sampling edges.
        s_valid = offer_word;                           // Set whether an input word is being offered.
        s_data = input_data;                            // Set the offered payload.
        s_last = input_last;                            // Set the offered packet marker.
        m_ready = accept_output;                        // Set the destination's readiness independently of the input source.
        @(posedge clk);                                 // Sample the handshakes before the DUT's nonblocking updates occur.
        if (m_valid !== (expected.size() != 0))         // Output must be valid exactly when the reference queue contains a word.
            $fatal(1, "Incorrect output TVALID at %0t", $time); // Fail on missing, extra, or unknown output validity.
        if (s_ready !== (expected.size() < DEPTH))      // This FIFO's input is ready whenever the current occupancy is below its capacity.
            $fatal(1, "Incorrect input TREADY at %0t", $time);  // Detect incorrect full-state handling.
        if (m_valid) begin                              // Whenever a word is offered, check it even if the destination is stalled.
            oldest = expected[0];                       // Look at the front of the reference queue without removing it.
            if ({m_last, m_data} !== oldest)            // Compare both the payload and its associated packet marker.
                $fatal(1, "Expected {%0b,%0d}, got {%0b,%0d}", oldest[32], oldest[31:0], m_last, m_data);   // Explain an ordering or marker error.
            if (m_ready) begin                          // Remove the reference word only when output acceptance occurs.
                oldest = expected.pop_front();          // A software-like queue models FIFO order without reproducing the RTL pointers.
                delivered++;                            // Count the accepted output word.
                $display("%0t: delivered %0d, TLAST=%0b", $time, m_data, m_last);   // Log exactly what the receiver accepted.
            end                                         // End output acceptance; otherwise the oldest word stays in the queue.
        end                                             // End output checks for this clock edge.
        if (s_valid && s_ready) begin                   // Add a reference word only when input acceptance occurs.
            expected.push_back({s_last, s_data});       // Append the accepted payload and marker behind all older words.
            accepted++;                                 // Count the accepted input word.
            $display("%0t: accepted %0d, TLAST=%0b", $time, s_data, s_last);    // Log exactly what the source delivered.
        end                                             // End input acceptance.
        #1ns;                                           // Wait for the DUT's occupancy and pointers to update.
        if (int'(level) !== expected.size())            // Compare the hardware occupancy with the number of queued reference words.
            $fatal(1, "Expected level %0d, got %0d", expected.size(), level);   // Detect overflow, underflow, or a bad simultaneous-transfer count.
    endtask

    initial begin                                       // Run the directed test sequence once.
        repeat (3) @(posedge clk);                      // Keep reset active for three rising clock edges.
        #1ns;                                           // Inspect outputs after the final reset update settles.
        if (level !== 3'd0 || m_valid !== 1'b0 || s_ready !== 1'b1) // Reset must leave the four-entry FIFO empty and ready.
            $fatal(1, "Incorrect reset state");         // Stop if the FIFO does not start empty.
        @(negedge clk);                                 // Release reset away from a sampling edge.
        rst_n = 1'b1;                                   // Allow normal FIFO operation.
        fifo_cycle(1'b0, 32'd0, 1'b0, 1'b1);            // A ready receiver must not receive a phantom word from an empty FIFO.
        fifo_cycle(1'b1, 32'd10, 1'b0, 1'b0);           // Store 10 while refusing all output.
        fifo_cycle(1'b1, 32'd11, 1'b0, 1'b0);           // Store 11 behind 10.
        fifo_cycle(1'b1, 32'd12, 1'b0, 1'b0);           // Store 12 behind 11.
        fifo_cycle(1'b1, 32'd13, 1'b1, 1'b0);           // Store 13 with TLAST; all four slots are now occupied.
        fifo_cycle(1'b1, 32'd14, 1'b0, 1'b0);           // Offer 14, but the full FIFO must refuse it.
        fifo_cycle(1'b1, 32'd14, 1'b0, 1'b0);           // Keep offering the same pending word while the FIFO remains full.
        fifo_cycle(1'b1, 32'd14, 1'b0, 1'b1);           // Deliver 10; input is still blocked at this edge because the FIFO began full.
        fifo_cycle(1'b1, 32'd14, 1'b0, 1'b1);           // Accept the held 14 and deliver 11 together; reuse the wrapped write slot.
        fifo_cycle(1'b1, 32'd15, 1'b0, 1'b1);           // Accept 15 and deliver 12 together; occupancy stays unchanged.
        fifo_cycle(1'b1, 32'd16, 1'b1, 1'b1);           // Accept a second packet's final word while delivering the first packet's final word, 13.
        fifo_cycle(1'b0, 32'd0, 1'b0, 1'b0);            // Stop input and stall output; 14 must remain at the front.
        fifo_cycle(1'b0, 32'd0, 1'b0, 1'b1);            // Deliver 14.
        fifo_cycle(1'b0, 32'd0, 1'b0, 1'b1);            // Deliver 15.
        fifo_cycle(1'b0, 32'd0, 1'b0, 1'b0);            // Stall the final word, 16; its TLAST marker must stay high.
        fifo_cycle(1'b0, 32'd0, 1'b0, 1'b0);            // Stall again to check that the final word and marker remain stable.
        fifo_cycle(1'b0, 32'd0, 1'b0, 1'b1);            // Deliver 16, leaving the FIFO empty.
        fifo_cycle(1'b0, 32'd0, 1'b0, 1'b1);            // A further read attempt must not underflow or repeat the old word.
        fifo_cycle(1'b1, 32'd99, 1'b1, 1'b1);           // Store a one-word packet in an empty FIFO; there is no same-edge bypass to output.
        fifo_cycle(1'b0, 32'd0, 1'b0, 1'b1);            // Deliver 99 with its TLAST marker.
        fifo_cycle(1'b0, 32'd0, 1'b0, 1'b1);            // Verify that no extra output follows the one-word packet.
        if (accepted != 8 || delivered != 8 || expected.size() != 0)    // All eight intended words must have entered and left once.
            $fatal(1, "Incorrect totals: accepted=%0d delivered=%0d", accepted, delivered); // Detect lost inputs or incomplete drainage.
        $display("PASS: FIFO ordering, full/empty, simultaneous transfers, wraparound, and TLAST"); // Report success after all checks.
        $finish;                                        // End the simulation successfully, including the timeout process.
    end

    initial begin                                       // Run a separate timeout alongside the main test.
        #5us;                                           // Allow much more time than the short test sequence requires.
        $fatal(1, "FIFO test timed out");               // Fail if the test never reaches its normal completion.
    end
endmodule
