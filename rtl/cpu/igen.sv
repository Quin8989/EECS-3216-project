`include "constants.svh"

module igen #(
    parameter int DWIDTH = 32
)(
    input  logic [6:0]        opcode_i,
    input  logic [DWIDTH-1:0] insn_i,
    output logic [31:0]       imm_o
);

    logic [2:0] funct3;
    assign funct3 = insn_i[14:12];

    function automatic logic [DWIDTH-1:0] imm_i_sext(input logic [DWIDTH-1:0] insn);
        return {{DWIDTH-12{insn[31]}}, insn[31:20]};
    endfunction

    function automatic logic [DWIDTH-1:0] imm_s_sext(input logic [DWIDTH-1:0] insn);
        return {{DWIDTH-12{insn[31]}}, insn[31:25], insn[11:7]};
    endfunction

    function automatic logic [DWIDTH-1:0] imm_b_sext(input logic [DWIDTH-1:0] insn);
        return {{DWIDTH-13{insn[31]}}, insn[31], insn[7], insn[30:25], insn[11:8], 1'b0};
    endfunction

    function automatic logic [DWIDTH-1:0] imm_j_sext(input logic [DWIDTH-1:0] insn);
        return {{DWIDTH-21{insn[31]}}, insn[31], insn[19:12], insn[20], insn[30:21], 1'b0};
    endfunction

    function automatic logic [DWIDTH-1:0] imm_u(input logic [DWIDTH-1:0] insn);
        return {insn[31:12], 12'b0};
    endfunction

    function automatic logic [DWIDTH-1:0] imm_shift_zext(input logic [DWIDTH-1:0] insn);
        return {{DWIDTH-12{1'b0}}, insn[31:20]};
    endfunction

    always_comb begin
        imm_o = '0;
        case (opcode_i)
            `OPC_JAL:              imm_o = imm_j_sext(insn_i);
            `OPC_STORE:            imm_o = imm_s_sext(insn_i);
            `OPC_LUI, `OPC_AUIPC: imm_o = imm_u(insn_i);
            `OPC_ITYPE: begin
                case (funct3)
                    `F3_SLL, `F3_SRL_SRA: imm_o = imm_shift_zext(insn_i);
                    default:               imm_o = imm_i_sext(insn_i);
                endcase
            end
            `OPC_BRANCH: imm_o = imm_b_sext(insn_i);
            `OPC_JALR:   imm_o = imm_i_sext(insn_i);
            `OPC_LOAD:   imm_o = imm_i_sext(insn_i);
            `OPC_RTYPE:  imm_o = '0;
            default:     imm_o = 'x;
        endcase
    end

endmodule : igen
