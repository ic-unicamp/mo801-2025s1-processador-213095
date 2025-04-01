// banco de registradores de 32 bits
module regfile(
    input clk,
    input we3,
    input  [4:0] a1, a2, a3, 
    input  [31:0] wd3, 
    output [31:0] rd1, rd2
);
    // 32 registradores de 32 bits
    reg [31:0] regs [31:0];      

    // escrita no registrador
    always @(posedge clk)
        if (we3)
        regs[addrWrite] <= writeData;

    // TODO:
    // não estou implementando o registrador 0 (zero) que sempre lê 0
    // talvez não seja necessário
endmodule