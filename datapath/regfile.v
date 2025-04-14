//------------------------------------------------------------------------------
// Module: regfile
// Description: Implements a 32-register file for a RISC-V processor.
//              The register file contains 32 registers, each 32 bits wide.
//              It is reset to zero (active-low reset) and 
//              supports synchronous writes on the rising edge of clk.
//              Register 0 is hardwired to zero (writes to it are ignored).
//------------------------------------------------------------------------------
module regfile (
    input           clk,     // Clock signal
    input           resetn,  // Active-low reset signal
    input           we3,     // Write enable signal for register file
    input   [4:0]   rs1,     // Source register 1 address
    input   [4:0]   rs2,     // Source register 2 address
    input   [4:0]   rd,      // Destination register address (for writes)
    input   [31:0]  wd3,     // Write data for register rd
    output  [31:0]  rd1,     // Data output for register rs1
    output  [31:0]  rd2      // Data output for register rs2
);
    // Integer to reset the registers
    integer i;
    // Register file declaration: an array of 32 registers, each 32 bits wide.
    reg [31:0] register [31: 0];

    // Synchronous reset and write operations.
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            // Clear all registers when resetn is low.
            for (i = 0; i < 32; i = i + 1) begin
                register[i] = 32'b0;
            end
        end else if (we3 && (rd != 5'b0)) begin
            // Write enable is asserted and destination is not register 0:
            // Write wd3 to the specified register rd.
            register[rd] = wd3;
        end else if (rd == 5'b0) begin
            // Ensure register 0 always remains 0, regardless of any write.
            // This is "paranoic" but ensures register 0 is refreshed to zero
            // once in a while
            register[5'b0] = 32'b0;
        end
    end

    // Continuous assignment for read ports:
    // Register 0 is hardwired to 0 
    assign rd1 = (rs1 == 5'b0) ? 32'b0 : register[rs1];
    assign rd2 = (rs2 == 5'b0) ? 32'b0 : register[rs2];

endmodule