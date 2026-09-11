// Integration test: the real counter feeds the real FIFO; the testbench acts as the downstream receiver.
module tb_counter_fifo;                                 // Define the simulation-only top module.
    timeunit 1ns;                                       // Use nanoseconds as the simulation time unit.
    timeprecision 1ps;                                  // Use picosecond precision for simulation delays.
    localparam int FIFO_DEPTH = 4;                      // A small FIFO makes backpressure easy to observe.
    localparam int WORD_COUNT = 16;                     // Send more words than the FIFO can hold at once.
    localparam logic [31:0] FIRST_VALUE = 32'd10;       // The expected packet contains 10 through 25 inclusive.

    logic clk = 1'b0;                                   // Start the simulated clock low.
    logic rst_n = 1'b0;                                 // Start with reset asserted for both modules.
    logic start = 1'b0;                                 // Do not request a packet during reset.
    logic [31:0] word_count = 32'd0;                    // Drive the generator's requested packet length from the test.
    logic [31:0] start_value = 32'd0;                   // Drive the generator's requested first number from the test.

    logic source_busy;                                  // Observe whether the counter still has words to send into the FIFO.
    logic [31:0] source_data;                           // Carry the current word from counter to FIFO.
    logic source_last;                                  // Carry that word's packet marker from counter to FIFO.
    logic source_valid;                                 // Carry the counter's indication that its word is valid.
    logic source_ready;                                 // Carry readiness back from FIFO to counter; the testbench does not drive it.
    logic [31:0] stream_data;                           // Observe the oldest word offered by the FIFO.
    logic stream_last;                                  // Observe the final-word marker stored with that word.
    logic stream_valid;                                 // Observe whether the FIFO is offering a valid word.
    logic stream_ready = 1'b0;                          // Initially refuse all output, standing in for a paused DMA receiver.
    logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_level;        // Observe how many words are stored in the FIFO.

    int sent = 0;                                       // Count words accepted from the counter into the FIFO.
    int received = 0;                                   // Count words accepted from the FIFO by the simulated receiver.
    int cycle_count = 0;                                // Select a repeatable pattern of downstream pauses.
    int final_stall_cycles = 0;                         // Count deliberately stalled cycles on the final output word.
    bit source_was_stalled = 0;                         // Remember whether the counter was waiting at the previous clock edge.
    bit stream_was_stalled = 0;                         // Remember whether the FIFO output was waiting at the previous clock edge.
    bit saw_busy_low_with_buffered_data = 0;            // Record that counter completion can precede FIFO drainage.

    logic [32:0] held_source;                           // Remember the counter's previous {TLAST, data} pair for stability checks.
    logic [32:0] held_stream;                           // Remember the FIFO's previous {TLAST, data} pair for stability checks.

    always #5ns clk = ~clk;                             // Generate a 100 MHz clock shared by both modules.

    counter_source source(                              // Instantiate the counter you already tested.
        .clk(clk),                                      // Connect the shared clock.
        .rst_n(rst_n),                                  // Connect the shared active-low synchronous reset.
        .start(start),                                  // Let the testbench request one packet.
        .word_count(word_count),                        // Supply the number of words to generate.
        .start_value(start_value),                      // Supply the first number to generate.
        .busy(source_busy),                             // Observe the counter's own completion status.
        .m_axis_tdata(source_data),                     // Drive the shared counter-to-FIFO data signal.
        .m_axis_tlast(source_last),                     // Drive the shared counter-to-FIFO packet marker.
        .m_axis_tvalid(source_valid),                   // Drive validity toward the FIFO.
        .m_axis_tready(source_ready)                    // Receive readiness from the FIFO.
    );

    axis_fifo #(.DATA_WIDTH(32), .DEPTH(FIFO_DEPTH)) fifo( // Instantiate the FIFO you already tested, with four entries.
        .clk(clk),                                      // Use the same clock as the counter.
        .rst_n(rst_n),                                  // Reset both modules together.
        .s_axis_tdata(source_data),                     // Accept the word driven by the counter.
        .s_axis_tlast(source_last),                     // Accept the packet marker driven by the counter.
        .s_axis_tvalid(source_valid),                   // Observe the counter's valid signal.
        .s_axis_tready(source_ready),                   // Drive readiness back to the counter; this completes the input handshake wiring.
        .m_axis_tdata(stream_data),                     // Offer stored data to the simulated receiver.
        .m_axis_tlast(stream_last),                     // Offer the packet marker attached to that stored word.
        .m_axis_tvalid(stream_valid),                   // Indicate whether an output word is available.
        .m_axis_tready(stream_ready),                   // Receive readiness controlled by the testbench.
        .level(fifo_level)                              // Expose FIFO occupancy for the integration checks.
    );

    always @(posedge clk) begin                         // Monitor both stream interfaces at their transfer edges.
        if (!rst_n) begin                               // Clear the test's bookkeeping while the hardware is reset.
            sent = 0;                                   // No words have entered the FIFO in this run yet.
            received = 0;                               // No words have left the FIFO in this run yet.
            source_was_stalled = 0;                     // There is no pre-reset counter word that must be preserved.
            stream_was_stalled = 0;                     // There is no pre-reset FIFO word that must be preserved.
            saw_busy_low_with_buffered_data = 0;        // Clear the observation of counter completion before FIFO drainage.
        end else begin                                  // Check normal operation when reset is inactive.
            if (source_was_stalled && (source_valid !== 1'b1 || {source_last, source_data} !== held_source)) // A waiting counter must preserve its offered word.
                $fatal(1, "Counter changed or withdrew a stalled word"); // Reject a broken counter-to-FIFO handshake.
            if (stream_was_stalled && (stream_valid !== 1'b1 || {stream_last, stream_data} !== held_stream)) // A waiting FIFO must preserve its offered word too.
                $fatal(1, "FIFO changed or withdrew a stalled output word"); // Reject a broken FIFO-to-receiver handshake.
            held_source = {source_last, source_data};   // Save the counter word before the current edge's register updates.
            held_stream = {stream_last, stream_data};   // Save the FIFO output before the current edge's register updates.
            source_was_stalled = source_valid && !source_ready; // Remember whether the counter must hold this word until acceptance.
            stream_was_stalled = stream_valid && !stream_ready; // Remember whether the FIFO must hold this output until acceptance.
            if (source_valid && source_ready) begin     // The counter-to-FIFO handshake accepts one word at this edge.
                if (sent >= WORD_COUNT)                 // The counter must not produce more than the requested number of words.
                    $fatal(1, "Counter sent an extra word"); // Stop before an out-of-range transfer could be counted as valid.
                if (source_data !== FIRST_VALUE + 32'(sent)) // Compare against the expected sequence; the cast makes sent 32 bits wide.
                    $fatal(1, "Counter-to-FIFO data mismatch at word %0d", sent); // Identify a skipped or duplicated counter word.
                if (source_last !== (sent == WORD_COUNT-1)) // Only the last requested word may carry TLAST.
                    $fatal(1, "Counter-to-FIFO TLAST mismatch at word %0d", sent); // Reject an incorrect input packet boundary.
                sent++;                                 // Count the word now accepted into the FIFO.
            end                                         // End checks for the counter's accepted input word.
            if (stream_valid && stream_ready) begin     // The simulated receiver accepts one FIFO output word at this edge.
                if (received >= WORD_COUNT)             // No output word may follow the requested packet.
                    $fatal(1, "FIFO delivered an extra word"); // Reject an unexpected extra transfer.
                if (stream_data !== FIRST_VALUE + 32'(received)) // Check every received word against its expected numeric value.
                    $fatal(1, "Expected %0d, received %0d", FIRST_VALUE + 32'(received), stream_data); // Report the data mismatch.
                if (stream_last !== (received == WORD_COUNT-1)) // The final output word must be the only one marked with TLAST.
                    $fatal(1, "FIFO output TLAST mismatch at word %0d", received); // Reject an incorrect output packet boundary.
                $display("%0t: received %0d, TLAST=%0b", $time, stream_data, stream_last); // Log exactly the words accepted by the receiver.
                received++;                             // Count the accepted output word.
            end                                         // End checks for the FIFO's accepted output word.
            #1ns;                                       // Wait until the hardware's nonblocking register updates settle.
            if (int'(fifo_level) !== (sent - received)) // Stored words must equal total input acceptances minus total output acceptances.
                $fatal(1, "FIFO occupancy does not match the two handshake counts"); // Detect a word lost or added between the interfaces.
            if (!source_busy && fifo_level != 0)        // Notice when the counter is finished but the FIFO still contains data.
                saw_busy_low_with_buffered_data = 1;    // Record this distinction so the test proves it actually occurred.
        end                                             // End normal-operation monitoring.
    end                                                 // End the monitor process, which runs alongside the stimulus below.

    initial begin                                       // Drive reset, one capture request, and the receiver's readiness.
        repeat (3) @(posedge clk);                      // Hold reset across three rising clock edges.
        #2ns;                                           // Wait past the DUT updates and the monitor's one-nanosecond settling check.
        if (source_busy !== 1'b0 || stream_valid !== 1'b0 || int'(fifo_level) !== 0) // Both modules must start idle and empty.
            $fatal(1, "Incorrect reset state");         // Stop if the connected pair did not reset correctly.
        @(negedge clk);                                 // Change control inputs away from a rising sampling edge.
        rst_n = 1'b1;                                   // Release reset for both modules.
        start_value = FIRST_VALUE;                      // Request that the packet begin at decimal ten.
        word_count = 32'(WORD_COUNT);                   // Request sixteen words, converting the parameter to a 32-bit input value.
        start = 1'b1;                                   // Assert start for the next rising edge.
        @(negedge clk);                                 // Wait one full cycle so the intervening rising edge captures the request.
        start = 1'b0;                                   // End the one-cycle start pulse.
        repeat (FIFO_DEPTH + 3) @(posedge clk);         // Keep the receiver paused long enough to fill the FIFO and stall the counter.
        #2ns;                                           // Inspect the full state after all updates at the last edge have settled.
        if (int'(fifo_level) !== FIFO_DEPTH || sent != FIFO_DEPTH || received != 0) // Exactly four words must be stored, with none delivered yet.
            $fatal(1, "FIFO did not fill correctly while the receiver was paused"); // Reject incorrect buffering or unexpected output transfers.
        if (source_ready !== 1'b0 || source_valid !== 1'b1 || source_busy !== 1'b1) // A full FIFO must hold the active counter waiting.
            $fatal(1, "Full FIFO did not backpressure the counter"); // Reject incorrect readiness wiring or source behavior.
        if (source_data !== FIRST_VALUE + 32'(FIFO_DEPTH)) // The FIFO holds 10 through 13, so the counter must be waiting with 14.
            $fatal(1, "Counter did not hold its first unaccepted word"); // Detect advancement past data refused by the full FIFO.
        $display("Full FIFO: four words buffered; counter is holding %0d", source_data); // Make the backpressure observation visible in the log.
        while (received < WORD_COUNT) begin             // Drain the complete packet while introducing downstream pauses.
            @(negedge clk);                             // Select readiness before the upcoming transfer edge.
            if (stream_valid && stream_last && final_stall_cycles < 3) begin // Deliberately pause on the final output word three times.
                stream_ready = 1'b0;                    // Refuse the final word so its data and TLAST must remain stable.
                final_stall_cycles++;                   // Count this deliberately stalled final-word cycle.
            end else begin                              // Use a regular pattern for the rest of the packet.
                stream_ready = ((cycle_count % 4) != 0); // Accept for three out of every four pattern cycles.
            end                                         // Finish choosing the receiver's readiness.
            cycle_count++;                              // Advance the deterministic readiness pattern.
            @(posedge clk);                             // Let the DUTs and monitor process this cycle's handshakes.
            #2ns;                                       // Check loop completion after received and the hardware outputs have settled.
        end                                             // End the drain loop after all sixteen words have been accepted.
        if (sent != WORD_COUNT || received != WORD_COUNT) // Both interfaces must have transferred exactly sixteen words.
            $fatal(1, "Incorrect final transfer counts"); // Reject an incomplete or oversized packet.
        if (final_stall_cycles != 3 || !saw_busy_low_with_buffered_data) // Confirm the final-word pause and early source-completion cases occurred.
            $fatal(1, "Required final-word and buffered-completion cases were not exercised"); // Fail if the intended integration cases were skipped.
        if (source_busy !== 1'b0 || stream_valid !== 1'b0 || int'(fifo_level) !== 0) // The source must be idle and the FIFO empty after drainage.
            $fatal(1, "The connected pair did not become idle after the packet"); // Reject residual valid data or occupancy.
        @(negedge clk);                                 // Prepare a few final observations after packet completion.
        stream_ready = 1'b1;                            // Stay ready so an unwanted extra output would be detected by the monitor.
        repeat (3) begin                                // Observe three additional transfer opportunities.
            @(posedge clk);                             // Let the monitor check for unexpected extra words.
            #2ns;                                       // Inspect state after the clocked updates settle.
            if (source_valid !== 1'b0 || stream_valid !== 1'b0 || int'(fifo_level) !== 0) // No new packet should begin without another start pulse.
                $fatal(1, "Unexpected activity after the packet finished"); // Reject a restarted or unfinished transfer.
        end                                             // End the post-packet idle checks.
        $display("PASS: counter + FIFO sequence, backpressure, TLAST, and drain checks"); // Report success after every integration check completes.
        $finish;                                        // End all simulation processes, including the clock and timeout.
    end

    initial begin                                       // Run a timeout alongside the stimulus and monitor.
        #10us;                                          // Allow much longer than this short sixteen-word transfer should need.
        $fatal(1, "Counter/FIFO integration test timed out"); // Report a deadlock or a packet that never finishes.
    end
endmodule
