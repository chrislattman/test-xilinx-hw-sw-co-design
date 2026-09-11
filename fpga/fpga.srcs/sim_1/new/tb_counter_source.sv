// Simulation-only test: receive 10, 11, 12, 13, pausing on 11 and on the final word.
module tb_counter_source;                               // Define the testbench, which has no external ports.
    // Equivalent to `timescale 1ns / 1ps in Verilog
    timeunit 1ns;                                       // Interpret unitless simulation delays in nanoseconds.
    timeprecision 1ps;                                  // Resolve simulation delays to one picosecond.

    // These would be regs in Verilog (signals the testbench drives)
    logic clk = 1'b0;                                   // Start the simulated clock low.
    logic rst_n = 1'b0;                                 // Start with the active-low reset asserted.
    logic start = 1'b0;                                 // Do not request a packet during reset.
    logic [31:0] word_count = 32'd0;                    // Initialize the requested packet length.
    logic [31:0] start_value = 32'd0;                   // Initialize the requested first number.

    // These would be wires in Verilog except m_axis_tready (signals driven by the counter's outputs)
    logic busy;                                         // Observe whether the generator has words left.
    logic [31:0] m_axis_tdata;                          // Observe the word currently offered by the generator.
    logic m_axis_tlast;                                 // Observe whether that word ends the packet.
    logic m_axis_tvalid;                                // Observe whether the offered word is valid.
    logic m_axis_tready = 1'b0;                         // Act as a receiver that initially refuses all words.

    always #5ns clk = ~clk;                             // Toggle every 5 ns: a 10 ns period makes a 100 MHz clock.

    counter_source dut(                                 // Instantiate the design under test; dut is this instance's name.
        .clk(clk),                                      // Connect the generator's clock port to the testbench clock.
        .rst_n(rst_n),                                  // Connect its reset port to the reset driven by this test.
        .start(start),                                  // Connect its start port to the test's request pulse.
        .word_count(word_count),                        // Supply the requested number of words.
        .start_value(start_value),                      // Supply the requested first number.
        .busy(busy),                                    // Connect its busy output to the signal we inspect.
        .m_axis_tdata(m_axis_tdata),                    // Connect its stream data output to our observation signal.
        .m_axis_tlast(m_axis_tlast),                    // Connect its final-word marker to our observation signal.
        .m_axis_tvalid(m_axis_tvalid),                  // Connect its valid output to our observation signal.
        .m_axis_tready(m_axis_tready)                   // Feed our chosen readiness back to the generator.
    );

    // A task is a reusable test procedure; unlike a function, it can wait for clock edges (they exist in Verilog too).
    task automatic counter_cycle(                       // Define a procedure that checks one offered word at a clock edge.
        input logic ready_value,                        // Decide whether the receiver accepts the word in this cycle.
        input logic [31:0] expected_data,               // Specify the number the generator must be presenting.
        input logic expected_last                       // Specify whether this must be the final word.
    );
        @(negedge clk);                                 // Wait for a falling edge to avoid changing inputs at the sampling edge.
        m_axis_tready = ready_value;                    // Set readiness half a clock period before the rising edge.
        @(posedge clk);                                 // Inspect the offered word at the transfer edge, before register updates.
        if (busy !== 1'b1 || m_axis_tvalid !== 1'b1)    // Case inequality also catches unknown values instead of accepting them.
            $fatal(1, "Expected a valid word while busy at %0t", $time);    // Stop with an error if the source is not offering data.
        if (m_axis_tdata !== expected_data)             // Check the number, catching skipped, duplicated, or unknown words.
            $fatal(1, "Expected %0d, got %0d at %0t", expected_data, m_axis_tdata, $time);  // Report the incorrect word.
        if (m_axis_tlast !== expected_last)             // Check the final-word marker, including while the receiver is stalled.
            $fatal(1, "Incorrect TLAST at %0t", $time); // Report an early, missing, or unknown final-word marker.
        $display("%0t: ready=%0b data=%0d last=%0b", $time, m_axis_tready, m_axis_tdata, m_axis_tlast); // Log this checked cycle.
        #1ns;                                           // Let the DUT's nonblocking register updates settle before returning.
    endtask

    initial begin                                       // Run the test sequence once, starting at simulation time zero.
        repeat (3) @(posedge clk);                      // Keep reset asserted across three rising clock edges.
        #1ns;                                           // Inspect reset results after the register updates have settled.
        if ({busy, m_axis_tvalid, m_axis_tlast} !== 3'b000) // These three outputs must all be low after reset.
            $fatal(1, "Generator did not become idle during reset");    // Stop if reset did not clear the active state.
        @(negedge clk);                                 // Set up the capture request away from the next sampling edge.
        rst_n = 1'b1;                                   // Release reset so the generator can accept a request.
        start_value = 32'd10;                           // Request that the first word be decimal ten.
        word_count = 32'd4;                             // Request exactly four words: 10, 11, 12, and 13.
        start = 1'b1;                                   // Assert start for the upcoming rising edge.
        @(negedge clk);                                 // Wait one full clock period; the intervening rising edge captures the request.
        start = 1'b0;                                   // End the one-cycle request pulse; readiness is still low.
        counter_cycle(1'b1, 32'd10, 1'b0);              // Accept 10; it is not the final word.
        counter_cycle(1'b0, 32'd11, 1'b0);              // Refuse 11; the generator must keep offering it.
        counter_cycle(1'b0, 32'd11, 1'b0);              // Refuse again; the number must still be 11.
        counter_cycle(1'b1, 32'd11, 1'b0);              // Accept the held 11, allowing the generator to advance.
        counter_cycle(1'b1, 32'd12, 1'b0);              // Accept 12; one more word remains afterward.
        counter_cycle(1'b0, 32'd13, 1'b1);              // Refuse the final word; TLAST must already be high.
        counter_cycle(1'b0, 32'd13, 1'b1);              // Refuse it again; both the data and TLAST must stay unchanged.
        counter_cycle(1'b1, 32'd13, 1'b1);              // Accept the final word; the task returns after register updates settle.
        if ({busy, m_axis_tvalid, m_axis_tlast} !== 3'b000) // The final acceptance must now have made the source idle.
            $fatal(1, "Generator stayed active after its final word");  // Stop if the packet did not finish correctly.
        repeat (3) begin                                // Continue observing for three clocks to detect unwanted extra words.
            @(posedge clk);                             // Check at the edge where an extra word would be accepted; TREADY is still high.
            if ({busy, m_axis_tvalid, m_axis_tlast} !== 3'b000) // All three outputs must remain low after the packet.
                $fatal(1, "Generator produced an unexpected extra word");   // Stop if it restarts or exceeds the count.
            #1ns;                                       // Wait past this edge's register updates before the next observation.
        end                                             // Finish the post-packet idle checks.
        $display("PASS: counter sequence, backpressure, TLAST, and idle checks");   // Report success only after every check completes.
        $finish;                                        // End the simulation successfully, including the timeout process.
    end

    initial begin                                       // Run a separate timeout process alongside the main test and clock.
        #2us;                                           // Allow much more time than this short test should need.
        $fatal(1, "Counter test timed out");            // Fail if the main sequence never reaches its successful finish.
    end
endmodule
