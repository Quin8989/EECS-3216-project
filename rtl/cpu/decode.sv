// ============================================================
// decode.sv — Instruction decode (field extraction)
//
// Purpose:
//   Cracks a raw 32-bit RISC-V instruction word into its named
//   fields.  No logic here — purely combinational bit-slicing.
//
// Inputs:
//   insn_i  — 32-bit instruction word from fetch.sv
//
// Outputs:
//   opcode, rd, funct3, rs1, rs2, funct7
//   — forwarded to control.sv, imm_gen.sv, register_file.sv,
//     alu.sv, and branch_control.sv
//
// RISC-V instruction encoding (R-type shown; fields are the same
// bit positions across all formats):
//   [6:0]   opcode
//   [11:7]  rd      (destination register index)
//   [14:12] funct3  (selects operation within an opcode group)
//   [19:15] rs1     (source register 1 index)
//   [24:20] rs2     (source register 2 index / shift amount / upper imm bits)
//   [31:25] funct7  (further opcode qualifier: SUB vs ADD, SRA vs SRL, M-ext)
// ============================================================
`include "constants.svh"

module decode #(
    parameter int DWIDTH = 32
)(
    input  logic [DWIDTH-1:0] insn_i,   // raw instruction from fetch

    output logic [6:0] opcode_o,        // major opcode group
    output logic [4:0] rd_o,            // destination register index (0–31)
    output logic [2:0] funct3_o,        // sub-operation selector
    output logic [4:0] rs1_o,           // source register 1 index
    output logic [4:0] rs2_o,           // source register 2 index
    output logic [6:0] funct7_o         // extended opcode qualifier
);

    // All fields are fixed bit positions in the 32-bit encoding.
    assign opcode_o = insn_i[6:0];
    assign rd_o     = insn_i[11:7];
    assign funct3_o = insn_i[14:12];
    assign rs1_o    = insn_i[19:15];
    assign rs2_o    = insn_i[24:20];
    assign funct7_o = insn_i[31:25];

endmodule : decode
