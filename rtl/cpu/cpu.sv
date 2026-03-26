// ============================================================
// cpu.sv — RV32I+Zmmul CPU top-level (instantiation wrapper)
//
// Purpose:
//   Top-level CPU module.  Instantiates all datapath submodules
//   and handles glue logic that spans multiple stages:
//     • Stall orchestration (load, shift, MUL, external memory)
//     • Operand muxes (rs1sel / rs2sel, LUI op1 = 0)
//     • JALR LSB clear on the computed next-PC
//     • Load address hold register (dmem_addr_r)
//     • Data bus output assignments
//     • Branch signal combination (br_taken | pcsel)
//
// Submodules instantiated (instance names):
//   u_fetch   — fetch.sv         : PC register, ROM, instruction fetch
//   u_decode  — decode.sv        : instruction field extraction
//   u_imm_gen — imm_gen.sv       : immediate sign-extension / zero-extension
//   u_ctrl    — control.sv       : control signal generation
//   u_rf      — register_file.sv : 32×32 integer register file
//   u_alu     — alu.sv           : ALU + 2-cycle shift/MUL stall
//   u_branch  — branch_control.sv: branch condition evaluator
//   u_wb      — writeback.sv     : write-back source mux
//
// Stall policy:
//   any_stall = load_stall | shift_stall | mul_stall | mem_stall_i
//   During any_stall the PC does not advance (fetch.sv) and the
//   register file write-enable is suppressed (register_file.sv).
// ============================================================
`include "constants.svh"

module cpu #(
    parameter int AWIDTH = 32,
    parameter int DWIDTH = 32
)(
    input  logic              clk,
    input  logic              reset,

    // Data bus interface (to mem_map.sv)
    output logic [AWIDTH-1:0] dmem_addr_o,
    output logic [DWIDTH-1:0] dmem_wdata_o,
    input  logic [DWIDTH-1:0] dmem_rdata_i,
    output logic              dmem_wen_o,
    output logic              dmem_ren_o,
    output logic [2:0]        dmem_funct3_o,
    output logic              dmem_raw_ren_o,
    output logic              dmem_raw_wen_o,

    // External memory stall (e.g. SDRAM bridge)
    input  logic              mem_stall_i,

    // ROM data-bus read port (pass-through to fetch.sv)
    input  logic [AWIDTH-1:0] rom_daddr_i,
    output logic [DWIDTH-1:0] rom_drdata_o,

    // ROM data-bus write port (pass-through to fetch.sv)
    input  logic              rom_dwen_i,
    input  logic [DWIDTH-1:0] rom_dwdata_i,
    input  logic [2:0]        rom_dfunct3_i,

    // Debug
    output logic [AWIDTH-1:0] dbg_pc_o
);

    // ── Internal signals ────────────────────────────────────────
    logic [AWIDTH-1:0] pc;
    logic [DWIDTH-1:0] insn;
    logic [AWIDTH-1:0] next_pc;
    logic              brtaken;

    // Decode outputs
    logic [6:0] opcode;
    logic [4:0] rd;
    logic [2:0] funct3;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [6:0] funct7;

    // Immediate
    logic [DWIDTH-1:0] imm;

    // Control outputs
    logic        pcsel, regwren, rs1sel, rs2sel, memren, memwren;
    logic [1:0]  wbsel;
    logic [3:0]  alusel;

    // Register file outputs
    logic [DWIDTH-1:0] rs1_data, rs2_data;

    // Operand mux outputs
    logic [DWIDTH-1:0] alu_op1, alu_op2;

    // ALU outputs
    logic [DWIDTH-1:0] alu_res;
    logic              shift_stall, mul_stall;

    // Branch output
    logic br_taken;

    // Write-back data
    logic [DWIDTH-1:0] wb_data;

    // ── Stall signals ───────────────────────────────────────────
    // load_stall: high during cycle 1 of a LOAD (data not yet ready).
    // Suppressed for SDRAM loads (addr[31] set) — those go via mem_stall_i.
    logic load_stall;
    logic load_wb;   // high on cycle 2 of a LOAD (writeback cycle)

    always_ff @(posedge clk) begin
        if (reset) load_wb <= 1'b0;
        else       load_wb <= load_stall;
    end

    assign load_stall = memren & ~load_wb & ~alu_res[31];

    // Unified stall: ORed into fetch stall_i and register file any_stall_i
    logic any_stall;
    assign any_stall = load_stall | shift_stall | mul_stall | mem_stall_i;

    // ── JALR LSB clear ──────────────────────────────────────────
    // RISC-V spec §2.5: JALR clears bit 0 of the branch target.
    assign next_pc = (opcode == `OPC_JALR) ? {alu_res[AWIDTH-1:1], 1'b0} : alu_res;

    // ── brtaken = branch condition OR unconditional jump ────────
    // branch_control.sv outputs the branch comparison result only;
    // JAL/JALR redirect is captured by pcsel from control.sv.
    assign brtaken = br_taken | pcsel;

    // ── Operand muxes ───────────────────────────────────────────
    // rs1sel: 0 = rs1 register data, 1 = PC  (AUIPC, JAL, BRANCH)
    // LUI: op1 forced to 0 (imm already contains the upper bits)
    assign alu_op1 = (opcode == `OPC_LUI) ? '0 : (rs1sel ? pc : rs1_data);
    // rs2sel: 0 = rs2 register data, 1 = immediate
    assign alu_op2 = rs2sel ? imm : rs2_data;

    // ── Load address hold register ───────────────────────────────
    // During load_stall the PC advances to the next instruction, but
    // the memory address must remain stable for the RAM to produce data.
    logic [AWIDTH-1:0] dmem_addr_r;
    logic [2:0]        dmem_funct3_r;

    always_ff @(posedge clk) begin
        if (load_stall) begin
            dmem_addr_r   <= alu_res;
            dmem_funct3_r <= funct3;
        end
    end

    // ── Debug ───────────────────────────────────────────────────
    assign dbg_pc_o = pc;

    // ===========================================================
    // Submodule instantiations
    // ===========================================================

    // ── Fetch ───────────────────────────────────────────────────
    fetch #(
        .DWIDTH(DWIDTH),
        .AWIDTH(AWIDTH)
    ) u_fetch (
        .clk           (clk),
        .rst           (reset),
        .next_pc_i     (next_pc),
        .brtaken_i     (brtaken),
        .stall_i       (any_stall),
        .pc_o          (pc),
        .insn_o        (insn),
        .rom_daddr_i   (rom_daddr_i),
        .rom_drdata_o  (rom_drdata_o),
        .rom_dwen_i    (rom_dwen_i),
        .rom_dwdata_i  (rom_dwdata_i),
        .rom_dfunct3_i (rom_dfunct3_i)
    );

    // ── Decode ──────────────────────────────────────────────────
    decode #(
        .DWIDTH(DWIDTH)
    ) u_decode (
        .insn_i   (insn),
        .opcode_o (opcode),
        .rd_o     (rd),
        .funct3_o (funct3),
        .rs1_o    (rs1),
        .rs2_o    (rs2),
        .funct7_o (funct7)
    );

    // ── Immediate generator ─────────────────────────────────────
    imm_gen #(
        .DWIDTH(DWIDTH)
    ) u_imm_gen (
        .insn_i   (insn),
        .opcode_i (opcode),
        .funct3_i (funct3),
        .imm_o    (imm)
    );

    // ── Control unit ────────────────────────────────────────────
    control u_ctrl (
        .opcode_i  (opcode),
        .funct3_i  (funct3),
        .funct7_i  (funct7),
        .pcsel_o   (pcsel),
        .regwren_o (regwren),
        .rs1sel_o  (rs1sel),
        .rs2sel_o  (rs2sel),
        .memren_o  (memren),
        .memwren_o (memwren),
        .wbsel_o   (wbsel),
        .alusel_o  (alusel)
    );

    // ── Register file ───────────────────────────────────────────
    // Testbench reads result register via: dut.u_cpu.u_rf.registers_o[3]
    register_file #(
        .DWIDTH(DWIDTH)
    ) u_rf (
        .clk         (clk),
        .reset       (reset),
        .rs1_i       (rs1),
        .rs2_i       (rs2),
        .rs1_o       (rs1_data),
        .rs2_o       (rs2_data),
        .rd_i        (rd),
        .wb_data_i   (wb_data),
        .wen_i       (regwren),
        .any_stall_i (any_stall),
        .registers_o () // unused at top-level; only for testbench hierarchical probe
    );

    // ── ALU + shift/MUL stall ───────────────────────────────────
    alu #(
        .DWIDTH(DWIDTH)
    ) u_alu (
        .clk          (clk),
        .reset        (reset),
        .alu_op1_i    (alu_op1),
        .alu_op2_i    (alu_op2),
        .alusel_i     (alusel),
        .result_o     (alu_res),
        .shift_stall_o(shift_stall),
        .mul_stall_o  (mul_stall)
    );

    // ── Branch condition evaluator ──────────────────────────────
    branch_control u_branch (
        .opcode_i   (opcode),
        .funct3_i   (funct3),
        .rs1_data_i (rs1_data),
        .rs2_data_i (rs2_data),
        .br_taken_o (br_taken)
    );

    // ── Write-back mux ──────────────────────────────────────────
    writeback u_wb (
        .wbsel_i      (wbsel),
        .alu_res_i    (alu_res),
        .dmem_rdata_i (dmem_rdata_i),
        .pc_i         (pc),
        .wb_data_o    (wb_data)
    );

    // ── Data bus outputs ────────────────────────────────────────
    // During load_wb, hold the address and funct3 from the stall cycle.
    assign dmem_addr_o    = load_wb ? dmem_addr_r   : alu_res;
    assign dmem_wdata_o   = rs2_data;
    assign dmem_wen_o     = memwren & ~any_stall;
    assign dmem_ren_o     = memren  & ~any_stall; // suppress side-effect reads during stall
    assign dmem_funct3_o  = load_wb ? dmem_funct3_r : funct3;
    assign dmem_raw_ren_o = memren;
    assign dmem_raw_wen_o = memwren;

endmodule : cpu
