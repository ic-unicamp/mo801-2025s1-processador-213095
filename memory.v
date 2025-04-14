//------------------------------------------------------------------------------
// Module: memory
// Description: A simple synchronous memory module with read and write 
//              capabilities, initialized with zeros and then loaded from 
//              a memory file ("memory.mem").
//------------------------------------------------------------------------------
module memory (
    input clk,                // Clock signal
    input [31:0] address,     // 32-bit address (only bits [13:2] used for indexing)
    input [31:0] data_in,     // Data input for write operations
    output [31:0] data_out,   // Data output for read operations
    input we                  // Write enable signal
);

    // Declare a memory array of 1024 32-bit words (16kB memory)
    reg [31:0] mem [0:1023];
    integer i;

    // Read operation: continuously assign data_out from memory, using word addressing.
    assign data_out = mem[address[13:2]];

    // Synchronous write: on the rising edge of the clock, if write enable is asserted,
    // write the input data into the memory location.
    always @(posedge clk) begin
        if (we) begin
            mem[address[13:2]] <= data_in;
        end
    end

    // Initial block: Initialize the memory to zeros, then load a memory file.
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            mem[i] = 32'h00000000;
        end
        $readmemh("memory.mem", mem); // Load memory from external file
    end

endmodule
