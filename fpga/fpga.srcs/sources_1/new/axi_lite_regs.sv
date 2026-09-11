// AXI4-Lite adapter: one write may be pending independently of one read.
// AW carries a write address, W carries write data, B reports the write result, AR carries a read address, and R returns read data.
module axi_lite_regs #(                                 // Define the bus adapter and its compile-time parameter.
    parameter int ADDR_WIDTH = 12                       // Twelve byte-address bits cover a 4 KiB peripheral register window.
)(                                                      // Begin the AXI and internal register-bank port declarations.
    input  logic                  clk,                  // Clock used by every channel and the attached register bank.
    input  logic                  rst_n,                // Active-low reset, sampled on rising clock edges.

    input  logic [ADDR_WIDTH-1:0] s_axi_awaddr,         // Write address supplied by the bus master.
    input  logic [2:0]            s_axi_awprot,         // Write access attributes; this educational peripheral does not distinguish them.
    input  logic                  s_axi_awvalid,        // The master indicates a valid write address.
    output logic                  s_axi_awready,        // The adapter indicates room to capture that address.
    input  logic [31:0]           s_axi_wdata,          // Four bytes of write data from the master.
    input  logic [3:0]            s_axi_wstrb,          // One enable bit per byte; bit zero enables bits 7:0 of WDATA.
    input  logic                  s_axi_wvalid,         // The master indicates valid write data and byte strobes.
    output logic                  s_axi_wready,         // The adapter indicates room to capture that data.
    output logic [1:0]            s_axi_bresp,          // Write result: 00 means OKAY and 10 means SLVERR.
    output logic                  s_axi_bvalid,         // The adapter indicates that its write result is available.
    input  logic                  s_axi_bready,         // The master indicates that it accepts the write result.
    input  logic [ADDR_WIDTH-1:0] s_axi_araddr,         // Read address supplied by the master.
    input  logic [2:0]            s_axi_arprot,         // Read access attributes; unused by this peripheral's access policy.
    input  logic                  s_axi_arvalid,        // The master indicates a valid read address.
    output logic                  s_axi_arready,        // The adapter indicates room for a read request.
    output logic [31:0]           s_axi_rdata,          // Latched register data returned to the master.
    output logic [1:0]            s_axi_rresp,          // Read result: 00 means OKAY and 10 means SLVERR.
    output logic                  s_axi_rvalid,         // The adapter indicates that read data and its result are available.
    input  logic                  s_axi_rready,         // The master indicates that it accepts the read response.

    output logic                  wr_en,                // Internal one-cycle request to apply a captured register write.
    output logic [ADDR_WIDTH-1:0] wr_addr,              // Captured byte offset of the register to write.
    output logic [31:0]           wr_data,              // Captured value to write into the register bank.
    output logic [3:0]            wr_strb,              // Captured byte enables for that register write.
    input  logic                  wr_error,             // The register bank rejects the current write by asserting this signal.
    output logic [ADDR_WIDTH-1:0] rd_addr,              // Present the master's read address to the combinational register decoder.
    input  logic [31:0]           rd_data,              // Register value selected by that read decoder.
    input  logic                  rd_error              // The register bank asserts this for an invalid read address.
);                                                      // Finish the adapter's ports.
    logic aw_pending, w_pending;                        // Remember independently whether a write address and write data have arrived.
    // AXI permits the address and data to arrive in either order; neither channel waits for the other to become valid.
    assign s_axi_awready = !aw_pending && !s_axi_bvalid;    // Accept an address when its slot is empty and no write response is pending.
    assign s_axi_wready  = !w_pending  && !s_axi_bvalid;    // Accept data when its slot is empty and no write response is pending.
    assign s_axi_arready = !s_axi_rvalid;                   // Accept a read when the previous read response has been consumed.
    assign wr_en = aw_pending && w_pending && !s_axi_bvalid;    // Apply a write once both of its independently captured pieces are present.
    assign rd_addr = s_axi_araddr;                      // Continuously select the register associated with the incoming read address.

    // Responses and their payloads stay stable until the master accepts them.
    always_ff @(posedge clk) begin                      // Update all captured requests and responses at clock edges.
        if (!rst_n) begin                               // Reset clears the adapter's pending transactions.
            aw_pending <= 0;                            // Discard any captured write address.
            w_pending <= 0;                             // Discard any captured write data.
            wr_addr <= 0;                               // Initialize the saved write address.
            wr_data <= 0;                               // Initialize the saved write data.
            wr_strb <= 0;                               // Initialize the saved byte enables.
            s_axi_bvalid <= 0;                          // No write response is available after reset.
            s_axi_bresp <= 0;                           // Initialize the write-response payload to OKAY.
            s_axi_rvalid <= 0;                          // No read response is available after reset.
            s_axi_rresp <= 0;                           // Initialize the read-response payload to OKAY.
            s_axi_rdata <= 0;                           // Initialize the saved read data.
        end else begin                                  // Perform normal bus transactions with reset inactive.
            if (s_axi_awvalid && s_axi_awready) begin   // Capture a write address only on its own handshake.
                wr_addr <= s_axi_awaddr;                // Save the address even if write data has not arrived yet.
                aw_pending <= 1;                        // Mark the address slot occupied.
            end                                         // Finish write-address capture.
            if (s_axi_wvalid && s_axi_wready) begin     // Capture write data only on its own handshake.
                wr_data <= s_axi_wdata;                 // Save the data even if its address has not arrived yet.
                wr_strb <= s_axi_wstrb;                 // Save the byte enables with their data.
                w_pending <= 1;                         // Mark the write-data slot occupied.
            end                                         // Finish write-data capture.
            if (s_axi_bvalid && s_axi_bready)           // The master has accepted the pending write result.
                s_axi_bvalid <= 0;                      // Stop offering that completed response.
            if (wr_en) begin                            // The attached register bank applies or rejects this write at this same edge.
                aw_pending <= 0;                        // Release the captured address slot.
                w_pending <= 0;                         // Release the captured data slot.
                s_axi_bvalid <= 1;                      // Offer a response for the completed register-write attempt.
                s_axi_bresp <= wr_error ? 2'b10 : 2'b00;    // Encode rejection as SLVERR, otherwise OKAY.
            end                                         // Finish committing the register-write attempt.
            if (s_axi_rvalid && s_axi_rready)           // The master has accepted the pending read result.
                s_axi_rvalid <= 0;                      // Stop offering that consumed response.
            if (s_axi_arvalid && s_axi_arready) begin   // A read-address handshake selects and captures one register value.
                s_axi_rdata <= rd_data;                 // Freeze the selected value so later register changes cannot alter this response.
                s_axi_rresp <= rd_error ? 2'b10 : 2'b00;    // Encode an invalid read as SLVERR, otherwise OKAY.
                s_axi_rvalid <= 1;                      // Offer the captured read data and status until accepted.
            end                                         // Finish read-response capture.
        end
    end
endmodule
