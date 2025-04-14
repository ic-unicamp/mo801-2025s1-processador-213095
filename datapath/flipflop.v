//------------------------------------------------------------------------------
// Module: flipflop_d_en (flip-flop D with enable)
// Description: Positive-edge triggered flip-flop with enable and asynchronous reset.
//              On reset (active low), q is cleared to zero. When enable is asserted,
//              d is loaded into q. When enable is deasserted, q retains its value.
//------------------------------------------------------------------------------
module flipflop_d_en(
    input             clk,        // Clock signal
    input             en,         // Enable signal for updating the register
    input             resetn,     // Active-low reset
    input      [31:0] d,          // 32-bit data input (d)
    output reg [31:0] q           // 32-bit data output register (q)
);
    // Always block with asynchronous reset and synchronous enable.
    // I dislike using <= but it appears it does not work without in this module
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // Reset: clear the register when resetn is low.
            q <= 32'b0;
        end else if (en) begin
            // Load d into q when enable is high.
            q <= d;
        end else begin
            // Retain the current value of q when enable is low.
            q <= q;
        end
    end
endmodule

module flipflop_d(
    input         clk,        // Clock signal
    input         resetn,     // Active-low reset
    input  [31:0] d,          // 32-bit data input (d)
    output [31:0] q           // 32-bit data output register (q)
);
    flipflop_d_en inner_flipflop(
        .clk(clk),
        .en(1'b1),
        .resetn(resetn),    
        .d(d),
        .q(q)
    );
endmodule

