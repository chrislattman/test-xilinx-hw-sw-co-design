// Handwritten capture registers.
module capture_regs #(                                  // Define the register bank and its configurable FIFO capacity.
    parameter int FIFO_DEPTH = 256                      // Use the FIFO capacity to generate the FULL status bit.
)(                                                      // Begin the register-bank interface, which sits behind the AXI adapter.
    input  logic clk,                                   // Shared clock.
    input  logic rst_n,                                 // Shared active-low synchronous reset.
    input  logic wr_en,                                 // The adapter requests a register write at the next rising edge.
    input  logic [11:0] wr_addr,                        // Byte offset of the register being written.
    input  logic [31:0] wr_data,                        // New register data supplied by the adapter.
    input  logic [3:0] wr_strb,                         // One write enable for each of the four data bytes.
    output logic wr_error,                              // Tell the adapter to reject this write with SLVERR.

    input  logic [11:0] rd_addr,                        // Byte offset of the register being read.
    output logic [31:0] rd_data,                        // Combinationally selected register value for the adapter to capture.
    output logic rd_error,                              // Tell the adapter that the selected read address is invalid.

    output logic start,                                 // Produce a one-cycle command that starts the counter.
    output logic [31:0] word_count,                     // Store the next packet's length.
    output logic [31:0] start_value,                    // Store the next packet's first number for the counter to capture.
    input  logic source_busy,                           // Observe whether the counter is still sending words into the FIFO.
    input  logic [31:0] fifo_level,                     // Observe how many words remain buffered in the FIFO.
    input  logic stream_fire,                           // Observe acceptance at the FIFO's outgoing stream interface.
    input  logic stream_last                            // Observe TLAST at the FIFO's outgoing stream interface.
);                                                      // Finish the register-bank ports.
    logic active;                                       // Stay active from an accepted START until the final FIFO output is accepted.
    logic [31:0] accepted_words;                        // Count words accepted by the downstream receiver during the current capture.

    // Byte writes must preserve the bytes whose WSTRB bits are zero. Functions cannot wait for clock edges.
    function automatic logic [31:0] merge_bytes(        // Define a combinational helper function returning an updated 32-bit register value.
        input logic [31:0] old_value, new_value,        // Supply the existing value and the proposed replacement bytes.
        input logic [3:0] strobe                        // Select which bytes to replace.
    );                                                  // Finish the function argument list.
        logic [31:0] result;                            // Hold the merged value while calculating the result.
        result = old_value;                             // Begin by preserving every old byte.
        for (int i = 0; i < 4; i++)                     // Visit each of the four byte positions.
            if (strobe[i]) result[8*i +: 8] = new_value[8*i +: 8];  // Replace eight bits starting at bit 8*i only when that byte is enabled.
        return result;                                  // Return the merged value without advancing simulation time.
    endfunction

    // Decode addresses and current state continuously; actual writes occur in the clocked process below.
    always_comb begin                                   // Describe combinational read selection and write-permission checks.
        wr_error = 0;                                   // Assume the write is allowed unless a rule below rejects it.
        case (wr_addr)                                  // Interpret the captured write address as a byte offset.
            12'h000: begin                              // COMMAND register: only bit zero requests START.
                if (wr_strb[0] && wr_data[0] &&         // Check START only when its byte is enabled and its command bit is one.
                    (active || source_busy || fifo_level != 0 || word_count == 0))  // Starting requires idle hardware, an empty FIFO, and a nonzero count.
                    wr_error = 1;                       // Reject a START that would overlap a capture or request zero words.
            end                                         // Finish command-write validation.
            12'h008, 12'h00c: wr_error = active;        // WORD_COUNT and START_VALUE may be changed only while no capture is active.
            default: wr_error = 1;                      // Reject writes to read-only registers and unmapped or unaligned offsets.
        endcase                                         // Finish write-address decoding.
        rd_error = 0;                                   // Assume the read address is valid unless the decoder rejects it.
        rd_data = 0;                                    // Default all readback bits to zero, including reserved status bits.
        case (rd_addr)                                  // Select the register associated with the incoming read offset.
            12'h000: rd_data = 0;                       // COMMAND reads zero because START is a pulse, not a stored enable bit.
            12'h004: begin                              // STATUS reports four independently meaningful state bits.
                rd_data[0] = active;                    // ACTIVE remains high until the final outgoing stream handshake.
                rd_data[1] = (fifo_level == 0);         // FIFO_EMPTY is high when no words are buffered.
                rd_data[2] = (fifo_level == FIFO_DEPTH);    // FIFO_FULL is high when all storage slots are occupied.
                rd_data[3] = source_busy;               // SOURCE_BUSY reports the counter's own progress, before FIFO drainage.
            end                                         // Finish assembling the status register.
            12'h008: rd_data = word_count;              // Read the configured number of words.
            12'h00c: rd_data = start_value;             // Read the configured starting number.
            12'h010: rd_data = fifo_level;              // Read the current number of buffered words.
            12'h014: rd_data = accepted_words;          // Read how many outgoing words the receiver has accepted in this capture.
            default: rd_error = 1;                      // Reject reads from unmapped or unaligned offsets.
        endcase                                         // Finish read-address decoding.
    end

    // Both this register bank and the counter sample the START command at the same rising clock edge.
    assign start = wr_en && !wr_error && wr_addr == 12'h000 &&  // Recognize a valid COMMAND write requested by the adapter.
                   wr_strb[0] && wr_data[0];            // Require byte zero and bit zero to be enabled for the START pulse.

    // Register storage updates independently of AXI response backpressure; the adapter holds the resulting response afterward.
    always_ff @(posedge clk) begin                      // Update configuration and capture status at rising edges.
        if (!rst_n) begin                               // Reset initializes the peripheral to an idle configuration.
            active <= 0;                                // No capture is active after reset.
            word_count <= 1024;                         // Default the next capture to 1024 words; software can choose another count.
            start_value <= 0;                           // Default the next capture to start at zero.
            accepted_words <= 0;                        // No outgoing words have been accepted yet.
        end else begin                                  // Process legal writes and stream events with reset inactive.
            if (wr_en && !wr_error) begin               // A rejected write must not modify the register bank.
                case (wr_addr)                          // Select which configuration register to update.
                    12'h008: word_count <= merge_bytes(word_count, wr_data, wr_strb);   // Update enabled bytes of WORD_COUNT.
                    12'h00c: start_value <= merge_bytes(start_value, wr_data, wr_strb); // Update enabled bytes of START_VALUE.
                    default: ;                          // Other legal writes do not update these two configuration registers.
                endcase                                 // Finish configuration-write selection.
            end                                         // End legal register writes.
            if (start) begin                            // Begin tracking the newly requested capture.
                active <= 1;                            // Protect the configuration until the outgoing packet finishes.
                accepted_words <= 0;                    // Restart the outgoing word counter for this capture.
            end else if (stream_fire) begin             // Count only words actually accepted at the outgoing stream interface.
                accepted_words <= accepted_words + 32'd1;   // Increment the count of outgoing accepted words.
                if (stream_last) active <= 0;           // Clear ACTIVE when the accepted word ends the packet.
            end                                         // End capture-progress updates.
        end                                             // End normal register-bank operation.
    end
    // ACTIVE tracks stream delivery; the AMD DMA separately reports completion of its memory transfer.
    // The C application must use DMA completion before consuming the DDR buffer.
endmodule
