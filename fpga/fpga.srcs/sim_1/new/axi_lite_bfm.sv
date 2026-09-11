// Simulation-only bus functional model (BFM): reusable procedures that act like an AXI4-Lite bus master.
// Supports one read and one write concurrently; the address and data of a write can arrive in either order.
interface axi_lite_bfm(input logic clk);                // Group the AXI signals and their test procedures around the shared clock.
    timeunit 1ns;                                       // Interpret simulation delays in nanoseconds.
    timeprecision 1ps;                                  // Use picosecond delay precision.
    logic [11:0] awaddr = 0, araddr = 0;                // Drive write and read byte offsets within the peripheral window.
    logic [2:0] awprot = 0, arprot = 0;                 // Use the default access-attribute encoding for this test master.
    logic [31:0] wdata = 0, rdata;                      // Drive write data and observe read data from the peripheral.
    logic [3:0] wstrb = 0;                              // Drive one write enable for each byte of WDATA.
    logic awvalid = 0, awready, wvalid = 0, wready;     // Drive address/data validity and observe independent slave readiness.
    logic [1:0] bresp, rresp;                           // Observe the peripheral's write and read response codes.
    logic bvalid, bready = 0, arvalid = 0, arready, rvalid, rready = 0; // Observe response validity and drive response acceptance and read-address validity.

    task automatic idle();                              // Return all master-driven transaction controls to their idle values.
        awvalid = 0; wvalid = 0; bready = 0; arvalid = 0; rready = 0;   // Withdraw requests and response readiness during reset setup.
        awaddr = 0; araddr = 0; wdata = 0; wstrb = 0;   // Initialize the master-driven address and data payloads.
    endtask                                             // End the reset/idle helper.

    task automatic write_reg(                           // Perform one complete register write and check its response code.
        input logic [11:0] address,                     // Select the register's byte offset.
        input logic [31:0] data,                        // Supply the requested register value.
        input logic [3:0] strobe = 4'hf,                // Write all four bytes unless the caller selects a partial write.
        input int aw_delay = 0,                         // Delay the address phase by this many clock cycles.
        input int w_delay = 0,                          // Delay the data phase independently by this many clock cycles.
        input int response_stall = 0,                   // Refuse the write response for this many cycles to test its stability.
        input logic [1:0] expected_response = 0         // Expect OKAY by default; use 2'b10 for an intentional rejected write.
    );                                                  // Finish the write task's arguments.
        logic [1:0] held_response;                      // Remember the response while deliberately refusing to accept it.
        fork                                            // Run the address and data senders concurrently, as AXI permits.
            begin                                       // Start the write-address sender.
                repeat (aw_delay) @(negedge clk);       // Apply the caller's optional address delay.
                @(negedge clk); awaddr = address; awvalid = 1;  // Present a stable address before the next rising sampling edge.
                do @(posedge clk); while (awready !== 1'b1);    // Keep the address valid until an actual address handshake occurs.
                @(negedge clk); awvalid = 0;            // Withdraw address validity after its acceptance edge.
            end                                         // End the write-address sender.
            begin                                       // Start the independent write-data sender.
                repeat (w_delay) @(negedge clk);        // Apply the caller's optional data delay.
                @(negedge clk); wdata = data; wstrb = strobe; wvalid = 1;   // Offer data and byte enables before a rising edge.
                do @(posedge clk); while (wready !== 1'b1); // Keep the data stable until the peripheral accepts it.
                @(negedge clk); wvalid = 0;             // Withdraw data validity after its acceptance edge.
            end                                         // End the write-data sender.
        join                                            // Continue only after both independent senders have completed their handshakes.
        wait (bvalid === 1'b1);                         // Wait for the peripheral to offer the write result.
        #1ns;                                           // Let response payload updates settle before saving the response value.
        held_response = bresp;                          // Save the response that must stay unchanged until accepted.
        repeat (response_stall) begin                   // Deliberately leave BREADY low for the requested number of cycles.
            @(posedge clk);                             // Observe the still-pending response at each clock edge.
            if (bvalid !== 1'b1 || bresp !== held_response) // Require valid and response to remain stable.
                $fatal(1, "Write response changed while stalled");
        end                                             // Finish the forced write-response pause.
        @(negedge clk); bready = 1;                     // Tell the peripheral that the master is now ready for the response.
        do @(posedge clk); while (bvalid !== 1'b1);     // Wait for the response acceptance edge.
        if (bresp !== expected_response)                // Check OKAY or the caller's expected SLVERR.
            $fatal(1, "Unexpected BRESP at %h: %h", address, bresp);
        @(negedge clk); bready = 0;                     // Return response readiness to idle after the handshake.
    endtask                                             // End one complete register write.

    task automatic read_reg(                            // Perform one complete register read and return the captured data.
        input logic [11:0] address,                     // Select the register's byte offset.
        output logic [31:0] data,                       // Return the value observed at the accepted read response.
        input int response_stall = 0,                   // Refuse the read response for this many cycles to test stable data and status.
        input logic [1:0] expected_response = 0         // Expect OKAY by default or SLVERR for an intentional invalid read.
    );                                                  // Finish the read task's arguments.
        logic [31:0] held_data;                         // Save the offered read value during response backpressure.
        logic [1:0] held_response;                      // Save its response code during the same pause.
        @(negedge clk); araddr = address; arvalid = 1;  // Present the read address before a rising clock edge.
        do @(posedge clk); while (arready !== 1'b1);    // Hold the address until the read-address handshake succeeds.
        @(negedge clk); arvalid = 0;                    // Withdraw the accepted read request.
        wait (rvalid === 1'b1);                         // Wait for read data and its response code to become available.
        #1ns;                                           // Let all response fields settle before saving their values.
        held_data = rdata; held_response = rresp;       // Remember the complete response that the peripheral must hold stable.
        repeat (response_stall) begin                   // Keep RREADY low for the requested number of cycles.
            @(posedge clk);                             // Inspect the response at each clock edge during the pause.
            if (rvalid !== 1'b1 || rdata !== held_data || rresp !== held_response)  // Validity, data, and response code must all be preserved.
                $fatal(1, "Read response changed while stalled");   // Reject a response that changed before acceptance.
        end                                             // Finish the forced read-response pause.
        @(negedge clk); rready = 1;                     // Allow the peripheral's read response to be accepted.
        do @(posedge clk); while (rvalid !== 1'b1);     // Wait for the actual response acceptance edge.
        data = rdata;                                   // Return the value accepted at this edge to the caller.
        if (rresp !== expected_response)                // Check the returned read result.
            $fatal(1, "Unexpected RRESP at %h: %h", address, rresp);
        @(negedge clk); rready = 0;                     // Return read-response readiness to idle after acceptance.
    endtask                                             // End one complete register read.
endinterface                                            // End the reusable simulation bus master.

