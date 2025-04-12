module memory(
  input clk,
  input [31:0] address,
  input [31:0] data_in,
  output [31:0] data_out,
  input we
);

reg [31:0] mem[0:1024]; // 16KB de memória
integer i;

assign data_out = mem[address[13:2]];

always @(posedge clk) begin
  if (we) begin
    mem[address[13:2]] = data_in;
  end
end

  // Read data from memory (word-aligned address)
  assign rd = RAM[a[31:2]];

  // Write to memory on the rising edge of the clock if write enable is asserted
  always @(posedge clk) begin
    if (we)
      RAM[a[31:2]] <= wd;
  end

endmodule