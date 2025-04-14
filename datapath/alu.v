//------------------------------------------------------------------------------
// Module: alu
// Description:
//   The ALU module performs fundamental arithmetic and logical operations.
//   It receives two 32-bit input operands (src_a and src_b) along with a 4-bit
//   control signal that selects the operation to perform. The result is computed
//   and output as a 32-bit value (alu_result).
//------------------------------------------------------------------------------
module alu (
    input      [31:0] src_a,          // First operand input
    input      [31:0] src_b,          // Second operand input
    input      [3:0]  alu_control,    // ALU control signal selects the operation
    output reg [31:0] alu_result,     // Result of the ALU computation
    output     [4:0]  alu_zero_flags  // Aggregated comparison flags for branching
);

    // The following hardcoded values correspond to different ALU operations.
    localparam [3:0]
        ALU_CONTROL_AND  = 4'b0000, // Bitwise AND
        ALU_CONTROL_OR   = 4'b0001, // Bitwise OR
        ALU_CONTROL_XOR  = 4'b0010, // Bitwise XOR
        ALU_CONTROL_ADD  = 4'b0011, // Addition
        ALU_CONTROL_SUB  = 4'b0100, // Subtraction
        ALU_CONTROL_SLT  = 4'b0101, // Set on less than (signed)
        ALU_CONTROL_SLTU = 4'b0110, // Set on less than (unsigned)
        ALU_CONTROL_SLL  = 4'b0111, // Logical left shift
        ALU_CONTROL_SRL  = 4'b1000, // Logical right shift
        ALU_CONTROL_SRA  = 4'b1001, // Arithmetic right shift
        ALU_CONTROL_LUI  = 4'b1010; // Load upper immediate 

    localparam [31:0]
        UNDEFINED = 32'bx;
        
    // The ALU performs the operation selected by alu_control on the operands.
    always @(*) begin
        case (alu_control)
            ALU_CONTROL_AND:
                alu_result = src_a & src_b;
            ALU_CONTROL_OR:
                alu_result = src_a | src_b;
            ALU_CONTROL_XOR:
                alu_result = src_a ^ src_b;
            ALU_CONTROL_ADD:
                alu_result = src_a + src_b;
            ALU_CONTROL_SUB:
                alu_result = src_a - src_b;
            ALU_CONTROL_SLT:
                alu_result = $signed(src_a) < $signed(src_b) ? 32'b1 : 32'b0;
            ALU_CONTROL_SLTU:
                alu_result = $unsigned(src_a) < $unsigned(src_b) ? 32'b1 : 32'b0;
            ALU_CONTROL_SLL:
                alu_result = src_a << src_b[4:0];
            ALU_CONTROL_SRL:
                alu_result = src_a >> src_b[4:0];
            ALU_CONTROL_SRA:
                alu_result = $signed(src_a) >>> $signed(src_b[4:0]);
            ALU_CONTROL_LUI:
                alu_result = src_b;
            default:
                alu_result = UNDEFINED;
        endcase
    end
    // Flags and comparisons
    wire less_than_sig_flag = $signed(src_a)   < $signed(src_b);
    wire less_than_uns_flag = $unsigned(src_a) < $unsigned(src_b);
    wire zero_flag = (alu_result == 32'b0);
    wire result_sign = alu_result[31];
    wire overflow_flag = (~((src_a[31] ^ src_b[31]) ^ alu_control[0])) & (src_a[31] ^ result_sign) & ~alu_control[1];
    assign alu_zero_flags = {zero_flag, less_than_sig_flag, less_than_uns_flag, result_sign, overflow_flag};
endmodule
