// Seguindo especificação do multiciclo
module extend(input [31:7] instr, input [1:0]  imm_src, output reg [31:0] imm_ext);
  always @(*) begin
    case(imm_src)
      2'b00: imm_ext = {{20{instr[31]}}, instr[31:20]}; // i-type 
      2'b01: imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // s-type (stores)
      2'b10: imm_ext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; // b-type (branches)
      2'b11: imm_ext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; // j-type (jal)
      default: imm_ext = 32'bx; // indefinido
    endcase             
  end
endmodule