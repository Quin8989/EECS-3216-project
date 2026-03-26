// ============================================================
// control.sv — Main control unit
//
// Purpose:
//   Decodes the current instruction's opcode, funct3, and funct7
//   into a set of control signals that steer every other datapath
//   stage: which ALU operation to perform, whether to read/write
//   memory, which value to write back to the register file, etc.
//
// Inputs:
//   opcode_i  — from decode.sv: major instruction group
//   funct3_i  — from decode.sv: sub-operation (shifts, branches…)
//   funct7_i  — from decode.sv: distinguishes ADD/SUB, SRL/SRA, M ext
//
// Outputs:
//   pcsel_o   — 1 = ALU result drives next PC (JAL/JALR)
//   regwren_o — 1 = write-back to rd is enabled this cycle
//   rs1sel_o  — 0 = ALU op1 from register file
//               1 = ALU op1 from PC (AUIPC, JAL, BRANCH)
//   rs2sel_o  — 0 = ALU op2 from register file
//               1 = ALU op2 from immediate generator
//   memren_o  — 1 = issue a data-memory read (LOAD)
//   memwren_o — 1 = issue a data-memory write (STORE)
//   wbsel_o   — selects writeback source:
//               WB_ALU (01) = ALU result
//               WB_MEM (10) = data memory read data
//               WB_PC4 (11) = PC + 4 (link address for JAL/JALR)
//               WB_OFF (00) = no writeback (don't-care, regwren=0)
//   alusel_o  — selects ALU operation (see constants.svh ALU_* defines)
//
// Connected to:
//   operand muxes (rs1sel, rs2sel → alu_op1/op2)
//   alu.sv            (alusel)
//   register_file.sv  (regwren, wbsel)
//   data bus logic    (memren, memwren)
//   fetch.sv / cpu.sv (pcsel → next_pc mux)
// ============================================================
`include "constants.svh"

module control (
    input  logic [6:0] opcode_i,  // major opcode
    input  logic [2:0] funct3_i,  // sub-operation
    input  logic [6:0] funct7_i,  // extended qualifier

    output logic       pcsel_o,   // 1 = ALU result is next PC
    output logic       regwren_o, // 1 = write result to rd
    output logic       rs1sel_o,  // 0=rs1_data / 1=PC → ALU op1
    output logic       rs2sel_o,  // 0=rs2_data / 1=imm → ALU op2
    output logic       memren_o,  // 1 = load from data memory
    output logic       memwren_o, // 1 = store to data memory
    output logic [1:0] wbsel_o,   // writeback source select
    output logic [3:0] alusel_o   // ALU operation select
);

    always_comb begin
        // Safe defaults — all outputs deasserted; ALU defaults to ADD
        // so it can still compute a base address even on NOP-like instructions.
        pcsel_o   = 1'b0;
        regwren_o = 1'b0;
        rs1sel_o  = 1'b0;
        rs2sel_o  = 1'b0;
        memren_o  = 1'b0;
        memwren_o = 1'b0;
        wbsel_o   = `WB_OFF;
        alusel_o  = `ALU_ADD;

        case (opcode_i)
            // ── R-type: register OP register ──────────────────────
            `OPC_RTYPE: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_ALU;
                if (funct7_i == `FUNCT7_M) begin
                    // M-extension (funct7=0x01): MUL/MULH etc.
                    // Only MUL (funct3=000) is implemented; others default to ADD.
                    case (funct3_i)
                        `F3_ADD_SUB: alusel_o = `ALU_MUL;
                        default:     alusel_o = `ALU_ADD;
                    endcase
                end else begin
                    // Base integer (funct7=0x00 or 0x20)
                    case (funct3_i)
                        `F3_ADD_SUB: alusel_o = (funct7_i == `FUNCT7_ALT) ? `ALU_SUB : `ALU_ADD;
                        `F3_SLL:     alusel_o = `ALU_SLL;
                        `F3_SLT:     alusel_o = `ALU_SLT;
                        `F3_SLTU:    alusel_o = `ALU_SLTU;
                        `F3_XOR:     alusel_o = `ALU_XOR;
                        `F3_SRL_SRA: alusel_o = (funct7_i == `FUNCT7_ALT) ? `ALU_SRA : `ALU_SRL;
                        `F3_OR:      alusel_o = `ALU_OR;
                        `F3_AND:     alusel_o = `ALU_AND;
                    endcase
                end
            end

            // ── I-type: register OP immediate ─────────────────────
            `OPC_ITYPE: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_ALU;
                rs2sel_o  = 1'b1;  // op2 = immediate
                case (funct3_i)
                    `F3_ADD_SUB: alusel_o = `ALU_ADD;
                    `F3_SLT:     alusel_o = `ALU_SLT;
                    `F3_SLTU:    alusel_o = `ALU_SLTU;
                    `F3_XOR:     alusel_o = `ALU_XOR;
                    `F3_OR:      alusel_o = `ALU_OR;
                    `F3_AND:     alusel_o = `ALU_AND;
                    `F3_SLL:     alusel_o = `ALU_SLL;
                    // funct7[5] distinguishes SRLI (logical) from SRAI (arithmetic)
                    `F3_SRL_SRA: alusel_o = (funct7_i == `FUNCT7_ALT) ? `ALU_SRA : `ALU_SRL;
                endcase
            end

            // ── LOAD: address = rs1 + imm ─────────────────────────
            `OPC_LOAD: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_MEM;  // writeback from memory, not ALU
                rs2sel_o  = 1'b1;     // op2 = sign-extended offset
                memren_o  = 1'b1;
                // ALU_ADD computes the effective byte address
            end

            // ── STORE: address = rs1 + imm ────────────────────────
            `OPC_STORE: begin
                rs2sel_o  = 1'b1;     // op2 = sign-extended offset
                memwren_o = 1'b1;
                // No regwren: stores don't write the register file
            end

            // ── BRANCH: compare rs1 and rs2 ───────────────────────
            `OPC_BRANCH: begin
                rs1sel_o  = 1'b1;  // op1 = PC (for branch target ADD in fetch)
                rs2sel_o  = 1'b1;  // op2 = B-imm branch offset
                // branch_control.sv performs the actual comparison on rs1_data/rs2_data
            end

            // ── JAL: unconditional jump, link PC+4 ────────────────
            `OPC_JAL: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_PC4;  // rd = return address (PC + 4)
                rs1sel_o  = 1'b1;     // op1 = PC (target = PC + J-imm)
                rs2sel_o  = 1'b1;
                pcsel_o   = 1'b1;     // ALU result → next PC
            end

            // ── JALR: indirect jump through register ──────────────
            `OPC_JALR: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_PC4;  // rd = return address (PC + 4)
                rs2sel_o  = 1'b1;     // op2 = I-imm offset (op1 = rs1_data)
                pcsel_o   = 1'b1;     // ALU result → next PC (LSB cleared by cpu.sv)
            end

            // ── LUI: load upper immediate ─────────────────────────
            `OPC_LUI: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_ALU;
                rs2sel_o  = 1'b1;   // op2 = U-imm; op1 forced to 0 in cpu.sv operand mux
            end

            // ── AUIPC: add upper immediate to PC ──────────────────
            `OPC_AUIPC: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_ALU;
                rs1sel_o  = 1'b1;  // op1 = PC
                rs2sel_o  = 1'b1;  // op2 = U-imm
            end

            `OPC_FENCE:  begin /* NOP — memory ordering; single-issue so fence is a no-op */ end
            `OPC_SYSTEM: begin /* NOP — ecall/ebreak detected by testbench as halt signal  */ end
            default:     begin end  // Undefined opcode → all signals stay at safe defaults
        endcase
    end

endmodule : control
