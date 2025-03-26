
module core( // modulo de um core
  input clk, // clock
  input resetn, // reset que ativa em zero
  output reg [31:0] address, // endereço de saída
  output reg [31:0] data_out, // dado de saída
  input [31:0] data_in, // dado de entrada
  output reg we // write enable
);

always @(posedge clk) begin
  if (resetn == 1'b0) begin
    address <= 32'h00000000;
  end else begin
    address <= address + 4;
  end
  we = 0;
  data_out = 32'h00000000;
end

endmodule



module controller();
  // To do
  // fazer a maquina de estados
  // fazer a decodificação de instruções
  // colocar no PC
endmodule


module datapath();
  // Todo: implementar e conectar as coisas (adder, alu, memoria, etc...)
endmodule