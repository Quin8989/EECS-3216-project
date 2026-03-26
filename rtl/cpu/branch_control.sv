// ============================================================
// branch_control.sv — Branch comparator and taken signal
//
// Purpose:
//   Evaluates branch conditions by comparing rs1_data and
//   rs2_data, then asserts br_taken_o when the branch should
//   be taken.  Unconditional jump redirect (JAL/JALR via pcsel)
//   is ORed in by the parent cpu.sv:
//     brtaken = br_taken_o | pcsel
//
// Branch conditions (RISC-V spec §2.5):
//   BEQ  — branch if rs1 == rs2
//   BNE  — branch if rs1 != rs2
//   BLT  — branch if rs1 <  rs2 (signed)
//   BGE  — branch if rs1 >= rs2 (signed)
//   BLTU — branch if rs1 <  rs2 (unsigned)
//   BGEU — branch if rs1 >= rs2 (unsigned)
//
// Inputs:
//   opcode_i   — from decode.sv; comparator only active for BRANCH
//   funct3_i   — from decode.sv; selects which condition to test
//   rs1_data_i — from register_file.sv
//   rs2_data_i — from register_file.sv
//
// Output:
//   br_taken_o — 1 = branch condition is satisfied
//                (OR'd with pcsel in cpu.sv to form brtaken)
//
// Connected to:
//   cpu.sv (br_taken_o | pcsel → fetch.sv brtaken_i)
// ============================================================
`include "constants.svh"

module branch_control (
    input  logic [6:0]  opcode_i,    // from decode.sv
    input  logic [2:0]  funct3_i,    // branch condition selector
    input  logic [31:0] rs1_data_i,  // from register_file.sv
    input  logic [31:0] rs2_data_i,  // from register_file.sv

    output logic        br_taken_o   // 1 = branch condition met
);

    logic breq;  // rs1 == rs2
    logic brlt;  // rs1 <  rs2 (signed or unsigned depending on funct3)

    // ── Equality comparison ─────────────────────────────────────
    assign breq = (rs1_data_i == rs2_data_i);

    // ── Less-than comparison ────────────────────────────────────
    // funct3[2:1] encodes which comparison flavour:
    //   2'b10 → BLT/BGE  (signed)
    //   2'b11 → BLTU/BGEU (unsigned)
    always_comb begin
        case (funct3_i[2:1])
            2'b10:   brlt = ($signed(rs1_data_i) < $signed(rs2_data_i)); // signed
            2'b11:   brlt = (rs1_data_i < rs2_data_i);                   // unsigned
            default: brlt = 1'b0;
        endcase
    end

    // ── Condition select ────────────────────────────────────────
    always_comb begin
        br_taken_o = 1'b0;
        if (opcode_i == `OPC_BRANCH) begin
            unique case (funct3_i)
                `F3_BEQ:  br_taken_o =  breq;   // equal
                `F3_BNE:  br_taken_o = ~breq;   // not equal
                `F3_BLT:  br_taken_o =  brlt;   // less-than signed
                `F3_BGE:  br_taken_o = ~brlt;   // greater-or-equal signed (complement of brlt)
                `F3_BLTU: br_taken_o =  brlt;   // less-than unsigned (brlt computed unsigned above)
                `F3_BGEU: br_taken_o = ~brlt;   // greater-or-equal unsigned
                default:  br_taken_o = 1'b0;
            endcase
        end
    end

endmodule : branch_control

