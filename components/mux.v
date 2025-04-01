
module mux2(input [31:0] data0, data1, input sel, output [31:0] out);
  assign out = sel ? data1 : data0;
endmodule

module mux3() (input  [31:0] data0, data1, data2, input  [31:0] sel, output [31:0] out);
  assign out = sel[1] ? data2 : (sel[0] ? data1 : data0);
endmodule
