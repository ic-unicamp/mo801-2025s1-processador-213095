module control (
    input              clk,
    input              resetn,
    input      [6:0]   opcode,         // Instruction opcode
    input      [2:0]   funct3,         // Instruction funct3 field
    input      [6:0]   funct7,         // Instruction funct7 field
    input      [4:0]   alu_zero_flags, // Aggregated ALU flags: {zero, lt, ltu, sign, overflow}
    output reg         pc_write,       // Enables PC update
    output reg         adr_src,        // Selects address source (PC vs. ALU result)
    output reg         mem_write,      // Memory write enable
    output reg         ir_write,       // Instruction register write enable
    output reg [1:0]   result_src,     // Selects final result source
    output reg [3:0]   alu_control,    // ALU operation selector
    output reg [1:0]   alu_src_b,      // Selects ALU operand B
    output reg [1:0]   alu_src_a,      // Selects ALU operand A
    output reg [2:0]   imm_src,        // Immediate format selector
    output reg         reg_write       // Enables register file write
);

    //===============================================================
    // Parameter and Localparam Definitions
    //===============================================================
    // Opcode Constants (DO NOT CHANGE)
    localparam [6:0]
        OPCODE_I_TYPE   = 7'b0010011, // I-type arithmetic immediate
        OPCODE_I_LOAD   = 7'b0000011, // I-type load
        OPCODE_I_JALR   = 7'b1100111, // I-type JALR
        OPCODE_S_TYPE   = 7'b0100011, // S-type store
        OPCODE_B_TYPE   = 7'b1100011, // B-type branch
        OPCODE_U_UIPC   = 7'b0010111, // U-type AUIPC
        OPCODE_U_LUI0   = 7'b0110111, // U-type LUI
        OPCODE_J_TYPE   = 7'b1101111, // J-type jump
        OPCODE_R_TYPE   = 7'b0110011, // R-type arithmetic
        OPCODE_SYSTEM   = 7'b1110011; // System instructions (ecall, ebreak, etc.)

    // ALU Control Signal Constants from alu.v
    localparam [3:0]
        ALU_CONTROL_AND  = 4'b0000,
        ALU_CONTROL_OR   = 4'b0001,
        ALU_CONTROL_XOR  = 4'b0010,
        ALU_CONTROL_ADD  = 4'b0011,
        ALU_CONTROL_SUB  = 4'b0100,
        ALU_CONTROL_SLT  = 4'b0101,
        ALU_CONTROL_SLTU = 4'b0110,
        ALU_CONTROL_SLL  = 4'b0111,
        ALU_CONTROL_SRL  = 4'b1000,
        ALU_CONTROL_SRA  = 4'b1001,
        ALU_CONTROL_LUI  = 4'b1010;

    // Immediate Type Constants from extend.v
    localparam [2:0]
        I_TYPE_IMM = 3'b000,
        B_TYPE_IMM = 3'b001,
        S_TYPE_IMM = 3'b010,
        U_TYPE_IMM = 3'b011,
        J_TYPE_IMM = 3'b100;

    // Finite State Machine (FSM) States  
    localparam [5:0]
        FETCH      = 0,
        DECODE     = 1,
        EXC_R      = 2,
        EXC_I      = 3,
        UPDATE_PC  = 4,
        MEM_ADDR   = 5,
        MEM_READ   = 6,
        MEM_WRITE  = 7,
        JAL        = 8, 
        JALR       = 9,
        ALU_WB     = 10,
        MEM_WB     = 11,
        BRANCH     = 12,
        AUIPC      = 13,
        ECALL      = 14,
        EBREAK     = 15,
        EXCEPTION  = 16;

    // Branch Function Constants (according to funct3)
    localparam [2:0]
        BEQ  = 3'b000,
        BNE  = 3'b001,
        BLT  = 3'b100,
        BGE  = 3'b101,
        BLTU = 3'b110,
        BGEU = 3'b111;

    // Undefined ALU control signal
    localparam [3:0] ALUCONTROL_UNDEFINED = 4'bx;

    //===============================================================
    // Internal State Registers
    //===============================================================
    reg [3:0] state, state_next;
    // Internal signal to choose between simple and detailed ALU decoding.
    reg [1:0] alu_op;

    //===============================================================
    // State Register Update (Synchronous with Async Reset)
    //===============================================================
    always @(posedge clk or negedge resetn) begin
        if (!resetn)
            state = FETCH;
        else
            state = state_next;
    end

    //===============================================================
    // Unified Combinational Block:
    // Output Generation, Immediate/ALU Decoding, and Next-State Logic
    //===============================================================
    always @(*) begin
        // default assignments for outputs and temporary signals.
        state_next  = FETCH;
        result_src  = 2'b00;
        reg_write   = 1'b0;
        alu_control = ALUCONTROL_UNDEFINED;
        alu_op      = 2'b00;
        pc_write    = 1'b0;
        adr_src     = 1'b0;
        mem_write   = 1'b0;
        ir_write    = 1'b0;
        alu_src_a   = 2'b00;
        alu_src_b   = 2'b00;

        // Determine the immediate format based solely on opcode.
        // (The case item order is rearranged.)
        case (opcode)
            OPCODE_I_LOAD,
            OPCODE_I_TYPE,
            OPCODE_I_JALR: imm_src = I_TYPE_IMM;
            OPCODE_S_TYPE: imm_src = S_TYPE_IMM;
            OPCODE_B_TYPE: imm_src = B_TYPE_IMM;
            OPCODE_J_TYPE: imm_src = J_TYPE_IMM;
            OPCODE_U_UIPC,
            OPCODE_U_LUI0: imm_src = U_TYPE_IMM;
            default:      imm_src = 3'bx;
        endcase

        // Main state machine logic.
        // The order of state cases is intentionally mixed.
        case (state)
            //---- DECODE State (listed first) --------------------------
            DECODE: begin
                if (opcode == OPCODE_I_JALR || opcode == OPCODE_J_TYPE) begin
                    // Precompute link address for jump instructions.
                    reg_write   = 1'b1;
                    alu_src_a   = 2'b01; // Old PC
                    alu_src_b   = 2'b10; // Constant 4
                    result_src  = 2'b00; // Link address via ALU
                    alu_op      = 2'b00; // Simple ADD mode
                    alu_control = ALU_CONTROL_ADD;
                end
                else begin
                    alu_src_a   = 2'b01; // Old PC used as source
                    alu_src_b   = 2'b01; // Immediate offset
                    alu_op      = 2'b00; // ADD operation
                    alu_control = ALU_CONTROL_ADD;
                end

                // Determine next state based on opcode.
                case (opcode)
                    OPCODE_R_TYPE:  state_next = EXC_R;
                    OPCODE_I_TYPE:  state_next = EXC_I;
                    OPCODE_I_LOAD:  state_next = MEM_ADDR;
                    OPCODE_I_JALR:  state_next = JALR;
                    OPCODE_S_TYPE:  state_next = MEM_ADDR;
                    OPCODE_U_LUI0:  state_next = EXC_I;
                    OPCODE_U_UIPC:  state_next = ALU_WB;
                    OPCODE_B_TYPE:  state_next = BRANCH;
                    OPCODE_J_TYPE:  state_next = JAL;
                    OPCODE_SYSTEM: begin
                        // For system instructions: assume funct7=0 indicates an ECALL;
                        // otherwise treat as EBREAK.
                        if (funct7 == 7'b0000000)
                            state_next = ECALL;
                        else
                            state_next = EBREAK;
                    end
                    default:        state_next = FETCH;
                endcase
            end

            //---- FETCH State (listed second) -------------------------
            FETCH: begin
                ir_write    = 1'b1;    // Latch instruction
                alu_src_a   = 2'b00;   // PC as source
                alu_src_b   = 2'b10;   // Constant 4
                result_src  = 2'b10;   // PC+4 output
                pc_write    = 1'b1;    // Update PC
                alu_op      = 2'b00;   // Addition
                alu_control = ALU_CONTROL_ADD;
                state_next  = DECODE;
            end

            //---- EXC_R State (R-type ALU operations) -------------
            EXC_R: begin
                alu_src_a   = 2'b10;   // Use rs1
                alu_src_b   = 2'b00;   // Use rs2
                alu_op      = 2'b10;   // Detailed decode mode
                case (funct3)
                    3'b000: alu_control = (funct7 == 7'b0100000) ? ALU_CONTROL_SUB : ALU_CONTROL_ADD;
                    3'b001: alu_control = ALU_CONTROL_SLL;
                    3'b010: alu_control = ALU_CONTROL_SLT;
                    3'b011: alu_control = ALU_CONTROL_SLTU;
                    3'b100: alu_control = ALU_CONTROL_XOR;
                    3'b101: alu_control = (funct7 == 7'b0100000) ? ALU_CONTROL_SRA : ALU_CONTROL_SRL;
                    3'b110: alu_control = ALU_CONTROL_OR;
                    3'b111: alu_control = ALU_CONTROL_AND;
                    default: alu_control = ALUCONTROL_UNDEFINED;
                endcase
                state_next = ALU_WB;
            end

            //---- EXC_I State (I-type ALU operations) -------------
            EXC_I: begin
                alu_src_a   = 2'b10;   // Use rs1
                alu_src_b   = 2'b01;   // Immediate operand
                alu_op      = 2'b10;   // Detailed mode
                case (funct3)
                    3'b000: alu_control = ALU_CONTROL_ADD;
                    3'b010: alu_control = ALU_CONTROL_SLT;
                    3'b011: alu_control = ALU_CONTROL_SLTU;
                    3'b100: alu_control = ALU_CONTROL_XOR;
                    3'b110: alu_control = ALU_CONTROL_OR;
                    3'b111: alu_control = ALU_CONTROL_AND;
                    3'b001: alu_control = ALU_CONTROL_SLL;
                    3'b101: alu_control = (funct7 == 7'b0100000) ? ALU_CONTROL_SRA : ALU_CONTROL_SRL;
                    default: alu_control = ALUCONTROL_UNDEFINED;
                endcase
                state_next = ALU_WB;
            end

            //---- JAL State (Unconditional jump) ----------------------
            JAL: begin
                alu_src_a   = 2'b01;   // Old PC
                alu_src_b   = 2'b01;   // Immediate offset
                alu_op      = 2'b10;   // Compute jump target
                alu_control = ALU_CONTROL_ADD;
                result_src  = 2'b00;
                pc_write    = 1'b1;
                state_next  = UPDATE_PC;
            end

            //---- JALR State (Register jump) --------------------------
            JALR: begin
                alu_src_a   = 2'b10;   // rs1 value
                alu_src_b   = 2'b01;   // Immediate
                alu_op      = 2'b10;
                alu_control = ALU_CONTROL_ADD;
                result_src  = 2'b00;
                pc_write    = 1'b1;
                state_next  = UPDATE_PC;
            end

            //---- UPDATE_PC State (Finalize PC update) ---------------
            UPDATE_PC: begin
                pc_write   = 1'b1;
                state_next = FETCH;
            end

            //---- MEM_ADDR State (Memory Address Calculation) --------
            MEM_ADDR: begin
                alu_src_a   = 2'b10;   // rs1 as base
                alu_src_b   = 2'b01;   // Immediate offset
                alu_op      = 2'b10;
                alu_control = ALU_CONTROL_ADD;
                if (opcode == OPCODE_I_LOAD)
                    state_next = MEM_READ;
                else if (opcode == OPCODE_S_TYPE)
                    state_next = (funct3 == 3'b010) ? MEM_WRITE : MEM_READ;
                else
                    state_next = FETCH;
            end

            //---- MEM_READ State (Memory read cycle) -----------------
            MEM_READ: begin
                alu_src_a   = 2'b10;
                alu_src_b   = 2'b01;
                alu_op      = 2'b10;
                alu_control = ALU_CONTROL_ADD;
                result_src  = 2'b00;
                adr_src     = 1'b1; // Use ALU result as address
                if (opcode == OPCODE_I_LOAD)
                    state_next = MEM_WB;
                else if ((funct3 == 3'b000) || (funct3 == 3'b001))
                    state_next = MEM_WRITE;
                else
                    state_next = FETCH;
            end

            //---- MEM_WRITE State (Memory write cycle) ----------------
            MEM_WRITE: begin
                alu_src_a   = 2'b10;
                alu_src_b   = 2'b01;
                alu_op      = 2'b10;
                alu_control = ALU_CONTROL_ADD;
                result_src  = 2'b00;
                adr_src     = 1'b1;
                mem_write   = 1'b1;
                state_next  = FETCH;
            end

            //---- MEM_WB State (Memory write-back to register) -------
            MEM_WB: begin
                alu_src_a   = 2'b10;
                alu_src_b   = 2'b01;
                alu_op      = 2'b10;
                alu_control = ALU_CONTROL_ADD;
                result_src  = 2'b01; // Use memory data
                reg_write   = 1'b1;
                state_next  = FETCH;
            end

            //---- ALU_WB State (ALU write-back to register) ---------
            ALU_WB: begin
                result_src  = 2'b00; // Use ALU result
                reg_write   = 1'b1;
                state_next  = FETCH;
            end

            //---- BRANCH State (Branch comparison) --------------------
            BRANCH: begin
                alu_src_a   = 2'b10;   // Compare rs1
                alu_src_b   = 2'b00;   // with rs2
                alu_op      = 2'b01;   // Subtraction for branch condition
                alu_control = ALU_CONTROL_SUB;
                result_src  = 2'b00;
                case (funct3)
                    BEQ:  pc_write = alu_zero_flags[4];
                    BNE:  pc_write = ~alu_zero_flags[4];
                    BLT:  pc_write = alu_zero_flags[3];
                    BGE:  pc_write = ~alu_zero_flags[3];
                    BLTU: pc_write = alu_zero_flags[2];
                    BGEU: pc_write = ~alu_zero_flags[2];
                    default: pc_write = 1'b0;
                endcase
                state_next = FETCH;
            end

            //---- AUIPC State (not otherwise used; placeholder) ------
            AUIPC: begin
                // Example placeholder for AUIPC functionality.
                alu_src_a   = 2'b01;  // Old PC
                alu_src_b   = 2'b01;  // Immediate offset
                alu_op      = 2'b00;  // Use ADD
                alu_control = ALU_CONTROL_ADD;
                result_src  = 2'b00;
                reg_write   = 1'b1;
                state_next  = FETCH;
            end

            //---- ECALL State (System call exception handling) -------
            ECALL: begin
                pc_write   = 1'b0;
                reg_write  = 1'b0;
                // Optionally, further trap control signals could be generated.
                state_next = FETCH;
            end

            //---- EBREAK State (Breakpoint exception handling) -------
            EBREAK: begin
                pc_write   = 1'b0;
                reg_write  = 1'b0;
                state_next = FETCH;
            end

            default: state_next = FETCH;
        endcase
    end

endmodule

