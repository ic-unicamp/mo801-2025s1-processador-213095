//------------------------------------------------------------------------------
// Module: core
// Description:
//   Top-level core module for a RISC-V multicycle processor.
//   This module instantiates the datapath and control units, and connects
//   the internal memory interface to the external memory ports.
// 
//   For more details, refer to documentation and diagram (documentation/riscv_diagram.jpeg) and
//   the RISC-V ISA documentation (https://msyksphinz-self.github.io/riscv-isadoc/html/rvi.html).
//------------------------------------------------------------------------------

// --- Datapath Component Includes ---
`include "./datapath/alu.v"
`include "./datapath/flipflop.v"
`include "./datapath/extend.v"
`include "./datapath/mux.v"
`include "./datapath/regfile.v"
`include "./datapath/memstage.v"

// --- Control Component Includes ---
`include "./control/control.v"

module core (
    input         clk,       // Clock signal
    input         resetn,    // Active-low reset signal
    input  [31:0] data_in,   // Data from external memory
    output [31:0] address,   // Memory address (to external memory)
    output [31:0] data_out,  // Data output to external memory
    output        we         // Write enable for external memory
);

    //==========================================================================
    // Datapath Signals
    //==========================================================================
    // Core intermediate values (black wires in the diagram)
    wire [31:0] result;       // Result after final mux; goes to register file/PC
    wire [31:0] pc;           // Program counter
    wire [31:0] old_pc;       // Old program counter (latched)
    wire [31:0] instr;        // Instruction word (latched)

    // ALU-related signals
    wire [31:0] alu_result;   // Raw ALU result
    wire [31:0] alu_out;      // Latched ALU result (used for writeback/address calc)
    wire [4:0]  alu_zero_flags; // 5-bit vector: {zero, lt, ltu, sign, overflow}
    wire [31:0] imm_ext;      // Extended immediate

    // Register file signals
    wire [4:0]  rs1, rs2, rd; // Register addresses (extracted from instr)
    wire [31:0] rd1, rd2;     // Data read from register file
    wire [31:0] rd1_lat, rd2_lat; // Latched values from register file
    wire [31:0] src_a, src_b;     // ALU source inputs

    //==========================================================================
    // Memory Interface Signals
    //==========================================================================
    // Memory read data passes through a latch and then into the memory staging unit.
    wire [31:0] mem_data_unstaged, mem_data_staged;

    //==========================================================================
    // Instantiate Datapath Components
    //==========================================================================

    // PC Register: Updates PC with the next value (result)
    flipflop_d_en ff_pc (
        .clk(clk),
        .resetn(resetn),
        .en(pc_write),  // from control
        .d(result),
        .q(pc)
    );

    // PC Address Mux: Chooses between PC and result (e.g. for branch target)
    mux2 mux_addr (
        .s(adr_src),  // from control: selects PC vs. ALU result
        .d0(pc),
        .d1(result),
        .q(address)
    );

    // --- Memory Interface ---
    // Latch the external memory data for processing by the memstager unit.
    flipflop_d ff_mem_data (
        .clk(clk),
        .resetn(resetn),
        .d(data_in),
        .q(mem_data_unstaged)
    );

    memstager memstager_inst (
        .data_in(mem_data_unstaged),
        .write_data(rd2_lat),      // Write data comes from latched register file output
        .address_offset(address[1:0]),
        .funct3(instr[14:12]),
        .load_data(mem_data_staged), // Output for load operation
        .store_data(data_out)        // Direct connection to external data_out
    );

    // --- Instruction Latching ---
    // These two flipflops form the "tall latch" that passes the PC and
    // memory data to the register file / immediate extraction.
    flipflop_d_en ff_old_pc (
        .clk(clk),
        .resetn(resetn),
        .en(ir_write),  // Enables on instruction fetch
        .d(pc),
        .q(old_pc)
    );
    flipflop_d_en ff_instr (
        .clk(clk),
        .resetn(resetn),
        .en(ir_write),
        .d(data_in),
        .q(instr)
    );

    // --- Register File ---
    // The register file extracts source registers from the instruction.
    regfile regfile_inst (
        .clk(clk),
        .resetn(resetn),
        .we3(reg_write),
        .rs1(instr[19:15]),
        .rs2(instr[24:20]),
        .rd(instr[11:7]),
        .wd3(result),  // Write back result (from final mux)
        .rd1(rd1),
        .rd2(rd2)
    );

    // --- Immediate Extension ---
    extend extend_inst (
        .instr(instr[31:7]),
        .imm_src(imm_src),  // from control, 2:0 selector for immediate type
        .imm_ext(imm_ext)
    );

    // --- Pre-ALU Latching ---
    // Latch the register file outputs to form the ALU inputs.
    flipflop_d ff_rd1_lat (
        .clk(clk),
        .resetn(resetn),
        .d(rd1),
        .q(rd1_lat)
    );
    flipflop_d ff_rd2_lat (
        .clk(clk),
        .resetn(resetn),
        .d(rd2),
        .q(rd2_lat)
    );

    // --- ALU Source Selection ---
    mux3 mux_srcA (
        .s(alu_src_a),   // from control
        .d0(pc),         // option 0: PC (e.g., for branch target calculation)
        .d1(old_pc),     // option 1: old PC value (e.g., jump address calculation)
        .d2(rd1_lat),    // option 2: Register file output (rs1)
        .q(src_a)
    );
    mux3 mux_srcB (
        .s(alu_src_b),   // from control
        .d0(rd2_lat),    // option 0: Register file output (rs2)
        .d1(imm_ext),    // option 1: Extended immediate
        .d2(32'd4),      // option 2: Constant value 4 (for PC + 4)
        .q(src_b)
    );

    // --- ALU Unit ---
    alu alu_inst (
        .src_a(src_a),
        .src_b(src_b),
        .alu_control(alu_control),   // from alu_dec below
        .alu_result(alu_result),
        .alu_zero_flags(alu_zero_flags)
    );

    // Latch ALU result before final selection
    flipflop_d ff_alu_out (
        .clk(clk),
        .resetn(resetn),
        .d(alu_result),
        .q(alu_out)
    );

    // Final result multiplexer: Selects data to write back (to register file or PC)
    mux3 mux_result (
        .s(result_src),   // from control
        .d0(alu_out),     // Option 0: Latched ALU result
        .d1(mem_data_staged), // Option 1: Processed memory load data
        .d2(alu_result),  // Option 2: Direct ALU result (if needed)
        .q(result)
    );

    //==========================================================================
    // Control Signals and Control Unit Instantiation
    //==========================================================================
    // Control signals are generated by the FSM based on the current instruction
    // and datapath status. These control signals include PC update, ALU source
    // selectors, memory control signals, register file write enable, and ALU op codes.
    wire         pc_write;      // Enables PC update
    wire         adr_src;       // Selects memory address source (PC vs. ALU result)
    wire         ir_write;      // Enables instruction register update
    wire  [1:0]  result_src;    // Selects the source for final result write-back
    wire  [3:0]  alu_control;   // Operation selector for the ALU
    wire  [1:0]  alu_src_a;     // Selects ALU input A source
    wire  [1:0]  alu_src_b;     // Selects ALU input B source
    wire  [2:0]  imm_src;       // Immediate format selector (2:0)
    wire         reg_write;     // Enables register file write


    // Instantiate controller/finite-state machine
    // Had to join the decoders and fsm because they were not working properly together
    control controller (
        .clk(clk),
        .resetn(resetn),
        .opcode(instr[6:0]),
        .funct3(instr[14:12]),
        .funct7(instr[31:25]),
        .alu_zero_flags(alu_zero_flags),
        .pc_write(pc_write),
        .adr_src(adr_src),
        .mem_write(we),      // External memory write enable
        .ir_write(ir_write),
        .result_src(result_src),
        .alu_control(alu_control),
        .alu_src_b(alu_src_b),
        .alu_src_a(alu_src_a),
        .imm_src(imm_src),
        .reg_write(reg_write)
    );


endmodule

