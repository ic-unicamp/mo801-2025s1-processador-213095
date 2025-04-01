

module alu(
    input  [31:0] src_a,
    input  [31:0] src_b,
    input  [3:0]  op,
    output reg [31:0] alu_result,
    output zero
);

  wire [31:0] b_mod; // b ajustado para subtração
  wire [31:0] sum; // resultado da soma ou subtração
  wire add_sub; // flag para adição/subtração

  // ajuste para subtração: se op[0]==1, inverte b e soma 1 (a - b = a + ~b + 1)
  assign b_mod = op[0] ? ~src_b : src_b;
  assign sum  = src_a + b_mod + op[0];

  // seleciona operação
  always @(*) begin
    case (op)
      4'b0000: alu_result = sum; // adição
      4'b0001: alu_result = sum; // subtração
      4'b0010: alu_result = src_a & src_b; // AND
      4'b0011: alu_result = src_a | src_b; // OR
      4'b0100: alu_result = src_a ^ src_b; // XOR
      4'b0101: alu_result = (src_a < src_b) ? 32'd1 : 32'd0; // Set on Less Than
      4'b0110: alu_result = src_a << src_b[4:0]; // shift left logical
      4'b0111: alu_result = src_a >> src_b[4:0]; // shift right logical
      4'b1001: alu_result = $signed(src_a) >>> src_b[4:0]; // shift right arithmetic
      default: alu_result = 32'bx; // Rresultado indefinido
    endcase
  end

  // flag de zero
  assign zero = (alu_result == 32'b0);  // 1 se o resultado é zero

  // TODO:  
  // não estou detectando se o resultado é negativo (mas talvez seja necessário)
  // não estou detectando overflow (mas talvez seja necessário 2)
  
endmodule
