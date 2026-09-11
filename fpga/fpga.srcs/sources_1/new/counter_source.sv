// Produces a finite AXI4-Stream packet of incrementing 32-bit numbers.
module counter_source(                                  // Define the module and begin its input/output port list.
    // These would all be input/output wires in Verilog
    input  logic        clk,                            // Clock input; registers update on rising edges (100 MHz in this project).
    input  logic        rst_n,                          // Active-low synchronous reset: a low value resets the module at a rising clock edge.

    input  logic        start,                          // Pulse high for one clock cycle while idle to request a new packet.
    input  logic [31:0] word_count,                     // Number of 32-bit words to send; captured when a start request is accepted.
    input  logic [31:0] start_value,                    // First number in the packet; captured when a start request is accepted.
    output logic        busy,                           // High while words remain to send; going low does not mean the DMA has finished.

    output logic [31:0] m_axis_tdata,                   // Current 32-bit word offered to the downstream FIFO.
    output logic        m_axis_tlast,                   // Marks the current word as the final word of the packet when TVALID is high.
    output logic        m_axis_tvalid,                  // Tells the FIFO that TDATA and TLAST describe a valid word ready to transfer.
    input  logic        m_axis_tready                   // The FIFO drives this high when it can accept a word at the next rising clock edge.
);
    logic [31:0] value, remaining;                      // Declare two 32-bit registers: the current number and the number of words left.
    assign busy          = (remaining != 0);            // Continuously indicate whether any words remain; this adds no separate busy register.
    assign m_axis_tvalid = busy;                        // Offer a valid word whenever busy, independently of whether the FIFO is ready.
    assign m_axis_tdata  = value;                       // Continuously expose the value register on the stream data output; adds no storage.
    assign m_axis_tlast  = busy && (remaining == 1);    // Assert TLAST only while sending the packet's one remaining word.

    // Nonblocking assignments (<=) below update registers together using their pre-update values.
    always_ff @(posedge clk) begin                      // Begin the sequential process; it runs only at rising clock edges.
        if (!rst_n) begin                               // Give reset priority: logical NOT makes this condition true when rst_n is zero.
            value     <= 0;                             // Clear all 32 bits of the current number during reset.
            remaining <= 0;                             // Clear the word count, making busy, TVALID, and TLAST low after the update.
        end else if (!busy) begin                       // If reset is inactive and the generator is idle, check for a new request.
            if (start && word_count != 0) begin         // Accept a start only for a nonzero number of words; ignore zero-length requests.
                value     <= start_value;               // Capture the first number; later changes to start_value do not affect this packet.
                remaining <= word_count;                // Capture the packet length; this makes busy and TVALID high after the update.
            end                                         // End the start check; without an accepted start, both registers retain their values.
        end else if (m_axis_tvalid && m_axis_tready) begin // While busy, advance only if both sides agree to transfer at this clock edge.
            // The FIFO accepts the current word at this edge; these assignments prepare the state for the next word.
            value     <= value + 32'd1;                 // Add decimal one, expressed as a 32-bit literal; the result wraps after 0xFFFFFFFF.
            remaining <= remaining - 32'd1;             // Subtract one accepted word; reaching zero makes busy and TVALID low.
        end                                             // End the conditional; while stalled, no assignments occur, so data and TLAST stay stable.
    end
endmodule
