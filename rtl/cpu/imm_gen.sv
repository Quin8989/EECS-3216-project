// ============================================================
// imm_gen.sv — Immediate generator
//
// Purpose:
//   Reconstructs the sign-extended 32-bit immediate value from
//   the scattered bit fields of a RISC-V instruction.  Each
//   instruction format packs its immediate differently to keep
//   rs1/rs2/rd in consistent positions across all formats.
//
// Inputs:
//   insn_i   — raw 32-bit instruction word (from fetch.sv)
//   opcode_i — opcode field (from decode.sv); selects which
//              format to apply
//   funct3_i — funct3 field; distinguishes shift immediates
//              (zero-extended 5-bit shamt) from regular I-type
//
// Output:
//   imm_o    — 32-bit sign-extended immediate, ready for the ALU
//
// Immediate formats (RISC-V spec §2.3):
//   I-type : 12-bit signed, ins[31:20]
//   S-type : 12-bit signed, bits split across [31:25] and [11:7]
//   B-type : 13-bit signed PC-relative branch offset, bit-scrambled
//   U-type : 20-bit upper immediate, placed in bits [31:12], low 12 = 0
//   J-type : 21-bit signed PC-relative jump offset, bit-scrambled
//   Shift  : 5-bit zero-extended shift amount, ins[24:20]
// ============================================================
`include "constants.svh"

module imm_gen #(
    parameter int DWIDTH = 32
)(
    input  logic [DWIDTH-1:0] insn_i,   // raw instruction word
    input  logic [6:0]        opcode_i, // from decode.sv
    input  logic [2:0]        funct3_i, // from decode.sv

    output logic [DWIDTH-1:0] imm_o    // sign-extended immediate
);

    // ── Format helper functions ─────────────────────────────────
    // Each function reconstructs one immediate format from the
    // scattered bits defined by the RISC-V encoding spec.

    // I-type: simple 12-bit signed immediate (loads, JALR, ADDI…)
    function automatic logic [DWIDTH-1:0] imm_i_sext(input logic [DWIDTH-1:0] ins);
        return {{DWIDTH-12{ins[31]}}, ins[31:20]};
    endfunction

    // S-type: store offset split across [31:25] and [11:7]
    function automatic logic [DWIDTH-1:0] imm_s_sext(input logic [DWIDTH-1:0] ins);
        return {{DWIDTH-12{ins[31]}}, ins[31:25], ins[11:7]};
    endfunction

    // B-type: branch offset — bit-scrambled to keep rs1/rs2 in place
    // Reconstructed order: {ins[31], ins[7], ins[30:25], ins[11:8], 1'b0}
    // LSB is always 0 because branch targets are 2-byte aligned
    function automatic logic [DWIDTH-1:0] imm_b_sext(input logic [DWIDTH-1:0] ins);
        return {{DWIDTH-13{ins[31]}}, ins[31], ins[7], ins[30:25], ins[11:8], 1'b0};
    endfunction

    // J-type: jump offset — bit-scrambled to keep rd in place
    // Reconstructed order: {ins[31], ins[19:12], ins[20], ins[30:21], 1'b0}
    function automatic logic [DWIDTH-1:0] imm_j_sext(input logic [DWIDTH-1:0] ins);
        return {{DWIDTH-21{ins[31]}}, ins[31], ins[19:12], ins[20], ins[30:21], 1'b0};
    endfunction

    // U-type: upper immediate (LUI, AUIPC) — top 20 bits, low 12 forced to 0
    function automatic logic [DWIDTH-1:0] imm_u(input logic [DWIDTH-1:0] ins);
        return {ins[31:12], 12'b0};
    endfunction

    // Shift amount: zero-extended 5-bit shamt from ins[24:20]
    // (same bit position as rs2, but used as a literal value not a register index)
    function automatic logic [DWIDTH-1:0] imm_shift_zext(input logic [DWIDTH-1:0] ins);
        return {{DWIDTH-5{1'b0}}, ins[24:20]};
    endfunction

    // ── Format selection ────────────────────────────────────────
    always_comb begin
        imm_o = '0; // default: safe zero for instructions with no immediate
        case (opcode_i)
            `OPC_JAL:              imm_o = imm_j_sext(insn_i);   // 21-bit jump offset
            `OPC_STORE:            imm_o = imm_s_sext(insn_i);   // 12-bit store offset
            `OPC_LUI, `OPC_AUIPC: imm_o = imm_u(insn_i);        // 20-bit upper immediate
            `OPC_ITYPE: begin
                // Shift instructions encode a 5-bit amount, not a signed 12-bit value
                case (funct3_i)
                    `F3_SLL, `F3_SRL_SRA: imm_o = imm_shift_zext(insn_i);
                    default:               imm_o = imm_i_sext(insn_i);
                endcase
            end
            `OPC_BRANCH: imm_o = imm_b_sext(insn_i); // 13-bit branch offset
            `OPC_JALR:   imm_o = imm_i_sext(insn_i); // 12-bit JALR offset
            `OPC_LOAD:   imm_o = imm_i_sext(insn_i); // 12-bit load offset
            default:     imm_o = '0;
        endcase
    end

endmodule : imm_gen
