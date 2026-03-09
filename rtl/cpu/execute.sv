`include "constants.svh"

module execute #(
    parameter int DWIDTH = 32
)(
    input  logic [DWIDTH-1:0] rs1_i,
    input  logic [DWIDTH-1:0] rs2_i,
    input  logic [3:0]        alusel_i,
    output logic [DWIDTH-1:0] res_o
);

    always_comb begin
        res_o = '0;
        unique case (alusel_i)
            `ALU_ADD:  res_o = rs1_i + rs2_i;
            `ALU_SUB:  res_o = rs1_i - rs2_i;
            `ALU_AND:  res_o = rs1_i & rs2_i;
            `ALU_OR:   res_o = rs1_i | rs2_i;
            `ALU_XOR:  res_o = rs1_i ^ rs2_i;
            `ALU_SLL:  res_o = rs1_i << rs2_i[4:0];
            `ALU_SRL:  res_o = rs1_i >> rs2_i[4:0];
            `ALU_SRA:  res_o = $signed(rs1_i) >>> rs2_i[4:0];
            `ALU_SLT:  res_o = ($signed(rs1_i) < $signed(rs2_i)) ? 32'd1 : 32'd0;
            `ALU_SLTU: res_o = (rs1_i < rs2_i) ? 32'd1 : 32'd0;
            default:   res_o = 'x;
        endcase
    end

endmodule : execute
