module core( // modulo de um core
  input clk, // clock
  input resetn, // reset que ativa em zero
  output reg [31:0] address, // endereço de saída
  output reg [31:0] data_out, // dado de saída
  input [31:0] data_in, // dado de entrada
  output reg we // write enable
);


// definição da máquina de estados do multicycle (falta coisa ainda)
// tentando seguir os nomes daquele slides das bolas e isso aqui 
// https://media.cheggcdn.com/media/191/19122956-37ff-43f2-b709-e82d752ee509/phpEAxJTM
localparam FETCH = 3'b000, DECODE = 3'b001, EXECUTE = 3'b010, MEMWRITE = 3'b011, ALUWB = 3'b100;  

reg [2:0] state;      // estado atual
reg [31:0] instr;     // instrução lida da memória
reg [31:0] pc;        

// regfile: 32 registradores com 32 bits
reg [31:0] reg_file [0:31];

// Coisas das instruções de RiscV
reg [6:0]  opcode;   
reg [2:0]  funct3;  
reg [4:0]  rd, rs1, rs2; 
reg [31:0] imm;

// alu
reg [31:0] alu_result;


// Parte original do Rodolfo 
// always @(posedge clk) begin
//   if (resetn == 1'b0) begin
//     address = 32'h00000000;
//   end else begin
//     address = address + 4;
//   end
//   we = 0;
//   data_out = 32'h00000000;
// end


integer i;

// BLOCO DO FSM -> depois vou passar isso pra um arquivo separado, mas vamos testar isso aqui primeiro.
always @(posedge clk) begin
    if (!resetn) begin // parte do reset
      pc = 32'h00000000;
      state = FETCH;
      for(i = 0; i < 32; i = i + 1)
        reg_file[i] = 32'h00000000;  // zera todos os registradores
    end else begin
      case(state)
        FETCH: begin
          address = pc; // endereço é o valor do PC
          we = 0; // garante que não vai escrever
          data_out = 32'h0; // zera o out
          state = DECODE; // vai pro decode
        end
        
        DECODE: begin
          instr = data_in; // le a instrução da memoria
          opcode = data_in[6:0]; // pega o opcode
          funct3 = data_in[14:12];  // e o funct3 se tiver
          
          // decodifica
          if (data_in[6:0] == 7'b0010011) begin  // addi (I-type)
            rd  = data_in[11:7];
            rs1 = data_in[19:15]; 
            imm = {{20{data_in[31]}}, data_in[31:20]}; // extensão de sinal
            state = EXECUTE;
          end
          else if (data_in[6:0] == 7'b0100011) begin // sw (s-type)
            rs1 = data_in[19:15]; 
            rs2 = data_in[24:20];  
            imm = {{20{data_in[31]}}, data_in[31:25], data_in[11:7]};
            state = EXECUTE;
          end
          else begin
            state = FETCH; // se não encontrar volta pro fetch
          end
        end
        
        EXECUTE: begin
          // no addi: soma o valor do registrador rs1 com o imediato
          // no sw: calcula o endereço (rs1 + imm)
          alu_result = reg_file[rs1] + imm;
          
          if (opcode == 7'b0010011) begin   // addi
            state = ALUWB;
          end else if (opcode == 7'b0100011) begin  // sw
            state = MEMWRITE;
          end else begin
            state = FETCH;
          end
        end
        ALUWB: begin
          // para o addi
          reg_file[rd] = alu_result; // Escreve alu_result no rd
          pc = pc + 4; // atualiza PC
          state = FETCH; // volta pro fetch
        end
        
        MEMWRITE: begin
          // para o sw
          address = alu_result; // passa o alu como endereço da memoria
          data_out = reg_file[rs2]; // o dado pra ser armazenado no rs2
          we = 1; // write enable
          pc = pc + 4; // pc + 4
          state = FETCH; // volta pro fetch
        end
        default: state = FETCH;  // default = volta pro fetch
      endcase
    end
  end


endmodule
