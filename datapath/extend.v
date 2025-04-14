//------------------------------------------------------------------------------
// Module: extend
// Description:
//   Immediate Extension Unit for RISC-V instructions.
//   Based on the immediate format selector (imm_src), this module extracts
//   and sign-extends (or zero-extends) the immediate value from the instruction.
//   The input instruction bits are provided from bit 31 down to bit 7.
//------------------------------------------------------------------------------
module extend (
    input  [31:7] instr,      // Instruction bits [31:7]
    input  [2:0]  imm_src,    // Immediate format selector
    output reg [31:0] imm_ext // Extended immediate value
);
    // Immediate Type Definitions
    localparam [2:0]
        I_TYPE_IMM = 3'b000,  // I-type immediate (e.g., arithmetic immediate)
        B_TYPE_IMM = 3'b001,  // B-type immediate (branch)
        S_TYPE_IMM = 3'b010,  // S-type immediate (store)
        U_TYPE_IMM = 3'b011,  // U-type immediate (LUI, AUIPC)
        J_TYPE_IMM = 3'b100;  // J-type immediate (jump)
    localparam [31:0]
        UNDEFINED = 32'bx;
        
    // Depending on the imm_src selector, extract the appropriate bits from
    // the instruction and perform sign (or zero) extension.
    always @(*) begin
        case (imm_src)
            I_TYPE_IMM: // Bits [30:20] are the immediate. Sign-extend from bit 31.
                imm_ext = {{21{instr[31]}}, instr[30:20]};
            B_TYPE_IMM: // B-type: Immediate is split and shifted:
                imm_ext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            S_TYPE_IMM: // Immediate is split between [30:25] and [11:7]. Sign-extend from bit 31.
                imm_ext = {{21{instr[31]}}, instr[30:25], instr[11:7]};
            U_TYPE_IMM: // U-type: Immediate occupies bits [31:12], lower 12 bits are zeros.
                imm_ext = {instr[31:12], 12'b0};
            J_TYPE_IMM: // Immediate is split and shifted:
                imm_ext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            default:
                imm_ext = UNDEFINED;
        endcase
    end

endmodule
