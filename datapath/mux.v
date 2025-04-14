//------------------------------------------------------------------------------
// Module: mux4
// Description:
//   A 4-to-1 multiplexer that selects one of four 32-bit input signals (d0–d3)
//   based on a 2-bit select signal 's'. The output 'q' is assigned to the
//   input corresponding to the value of 's'.
//------------------------------------------------------------------------------
module mux4 (
    input  [1:0] s,        // 2-bit select signal
    input  [31:0] d0,      // Input 0
    input  [31:0] d1,      // Input 1
    input  [31:0] d2,      // Input 2
    input  [31:0] d3,      // Input 3
    output [31:0] q        // 32-bit multiplexed output
);
    assign q = (s == 2'b00) ? d0 : (s == 2'b01) ? d1 : (s == 2'b10) ? d2 : d3;
endmodule

//------------------------------------------------------------------------------
// Module: mux3
// Description: 3-to-1 multiplexer
//------------------------------------------------------------------------------
module mux3 (
    input   [1:0]   s,            // 2-bit multiplexer select signal
    input   [31:0]  d0, d1, d2,     // Three 32-bit input sources
    output  [31:0]  q               // 32-bit multiplexed output
);
    // Instantiate mux4, tying d3 to zero so that if s==2'b11, output is 32'b0.
    mux4 u_mux4 (
        .s(s),
        .d0(d0),
        .d1(d1),
        .d2(d2),
        .d3(32'b0),
        .q(q)
    );
endmodule

//------------------------------------------------------------------------------
// Module: mux2
// Description: 2-to-1 multiplexer
//------------------------------------------------------------------------------
module mux2 (
    input          s,       // Multiplexer select signal
    input  [31:0]  d0, d1,  // Two 32-bit input sources
    output [31:0]  q        // 32-bit multiplexed output
);
    // Extend the 1-bit select to 2 bits, mapping 0 -> 2'b00 and 1 -> 2'b01.
    wire [1:0] s_ext = {1'b0, s};

    // Instantiate mux4, setting unused inputs (d2 and d3) to zero.
    mux4 u_mux4 (
        .s(s_ext),
        .d0(d0),
        .d1(d1),
        .d2(32'b0),
        .d3(32'b0),
        .q(q)
    );
endmodule

