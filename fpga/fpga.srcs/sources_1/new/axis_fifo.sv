//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/10/2026 06:16:16 PM
// Design Name: 
// Module Name: axis_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// Both sides of this synchronous FIFO share one clock. Every entry stores its data and its TLAST marker together.
// The read is combinational; this simple version is intended for distributed RAM/registers.
// A full FIFO accepts a new input on the cycle after a read frees a slot.
module axis_fifo #(                                     // Define the module and begin its compile-time parameter list.
    parameter int DATA_WIDTH = 32,                      // Number of payload bits per word; defaults to 32.
    parameter int DEPTH = 256,                          // Number of words that fit in the FIFO; defaults to 256.
    parameter int LEVEL_WIDTH = $clog2(DEPTH + 1)       // Bits needed to count from zero through DEPTH, including the full state.
)(                                                      // Finish parameters and begin the input/output port list.
    input  logic                  clk,                  // Shared clock for accepting and delivering words.
    input  logic                  rst_n,                // Active-low reset checked at each rising clock edge.

    input  logic [DATA_WIDTH-1:0] s_axis_tdata,         // Incoming data supplied by the counter source.
    input  logic                  s_axis_tlast,         // Incoming marker indicating that this word ends a packet.
    input  logic                  s_axis_tvalid,        // The source asserts this when it is offering a valid word.
    output logic                  s_axis_tready,        // Tell the source whether the FIFO has room to accept a word.

    output logic [DATA_WIDTH-1:0] m_axis_tdata,         // Oldest stored data word, offered to the downstream receiver.
    output logic                  m_axis_tlast,         // The TLAST marker stored with that oldest word.
    output logic                  m_axis_tvalid,        // Tell the receiver whether an output word is available.
    input  logic                  m_axis_tready,        // The downstream receiver asserts this when it can accept a word.

    output logic [LEVEL_WIDTH-1:0] level                // Current number of stored words; useful for status and simulation.
);
    localparam int PTR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);    // Bits needed to address an entry; use at least one bit.

    logic [DATA_WIDTH:0] memory [0:DEPTH-1];            // Array of DEPTH entries; each has DATA_WIDTH data bits plus one TLAST bit.
    logic [PTR_WIDTH-1:0] rd_ptr, wr_ptr;               // Read pointer selects the oldest word; write pointer selects the next free slot.
    logic push, pop;                                    // Combinational signals indicating input acceptance and output acceptance.
    // The s_axis ports face the source; the m_axis ports face the destination.
    assign s_axis_tready = (level < DEPTH);             // Accept input whenever at least one storage slot is free.
    assign m_axis_tvalid = (level != 0);                // Offer output whenever at least one stored word exists.
    assign {m_axis_tlast, m_axis_tdata} = m_axis_tvalid ? memory[rd_ptr] : '0;  // Unpack the oldest entry, or drive zeros when empty.
    assign push = s_axis_tvalid && s_axis_tready;       // A rising edge with both high stores one incoming word.
    assign pop  = m_axis_tvalid && m_axis_tready;       // A rising edge with both high removes one accepted output word.

    // Input and output handshakes are independent; both can occur at the same clock edge.
    always_ff @(posedge clk) begin                      // Update the FIFO state only on rising clock edges.
        if (!rst_n) begin                               // Reset takes priority when rst_n is low.
            rd_ptr <= 0;                                // Restart reading at the first array entry.
            wr_ptr <= 0;                                // Restart writing at the first array entry.
            level  <= 0;                                // Mark the FIFO empty; old memory contents need not be erased.
        end else begin                                  // Normal operation begins here when reset is inactive.
            if (push) begin                             // Store data only when the input handshake succeeds.
                memory[wr_ptr] <= {s_axis_tlast, s_axis_tdata}; // Keep the packet marker and payload together in one entry (using concatenation).
                wr_ptr <= (wr_ptr == DEPTH-1) ? '0 : wr_ptr + 1'b1; // Advance to the next slot, wrapping after the final entry.
            end                                         // End the write operation; otherwise the write pointer and memory hold their values.
            if (pop)                                    // Advance the read pointer only when the receiver accepts the oldest word.
                rd_ptr <= (rd_ptr == DEPTH-1) ? '0 : rd_ptr + 1'b1; // Wrap the read pointer at the array boundary too.
            case ({push, pop})                          // Combine the two handshakes to decide how occupancy changes (concatenates push with pop).
                2'b10: level <= level + 1'b1;           // Input only: one more word is stored.
                2'b01: level <= level - 1'b1;           // Output only: one fewer word is stored.
                default: ;                              // Both or neither: occupancy stays the same; the semicolon is an empty statement.
            endcase
        end
    end
`ifndef SYNTHESIS                                       // Include the following parameter checks in simulation, not hardware synthesis.
    initial begin                                       // Check the parameter choices once at the start of simulation.
        if (DEPTH < 1 || DATA_WIDTH < 1 || LEVEL_WIDTH < $clog2(DEPTH+1))   // Reject empty storage, zero-width data, or an undersized count.
            $fatal(1, "Invalid FIFO parameters");       // Stop simulation if the module was configured incorrectly.
    end
`endif
endmodule
