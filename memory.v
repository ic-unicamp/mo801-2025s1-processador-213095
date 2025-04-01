module memory(
    input         clk,
    input         we,
    input  [31:0] a,
    input  [31:0] wd,
    output [31:0] rd
);

  // Define a memory array with 64 words (32 bits each)
  reg [31:0] RAM [0:63];
  
  // Initialize memory contents from the file "riscvtest.txt"
  initial begin
    $readmemh("memory.mem", RAM);
  end

  // Read data from memory (word-aligned address)
  assign rd = RAM[a[31:2]];

  // Write to memory on the rising edge of the clock if write enable is asserted
  always @(posedge clk) begin
    if (we)
      RAM[a[31:2]] <= wd;
  end

endmodule