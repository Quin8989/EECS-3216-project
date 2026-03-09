`include "constants.svh"

module control (
    input  logic [6:0] opcode_i,
    input  logic [6:0] funct7_i,
    input  logic [2:0] funct3_i,
    output logic       pcsel_o,
    output logic       regwren_o,
    output logic       rs1sel_o,
    output logic       rs2sel_o,
    output logic       memren_o,
    output logic       memwren_o,
    output logic [1:0] wbsel_o,
    output logic [3:0] alusel_o
);

    always_comb begin
        pcsel_o   = 1'b0;
        regwren_o = 1'b0;
        rs1sel_o  = 1'b0;
        rs2sel_o  = 1'b0;
        memren_o  = 1'b0;
        memwren_o = 1'b0;
        wbsel_o   = `WB_OFF;
        alusel_o  = `ALU_ADD;

        unique case (opcode_i)
            `OPC_RTYPE: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_ALU;
                unique case (funct3_i)
                    `F3_ADD_SUB: alusel_o = (funct7_i == `FUNCT7_ALT) ? `ALU_SUB : `ALU_ADD;
                    `F3_SLL:     alusel_o = `ALU_SLL;
                    `F3_SLT:     alusel_o = `ALU_SLT;
                    `F3_SLTU:    alusel_o = `ALU_SLTU;
                    `F3_XOR:     alusel_o = `ALU_XOR;
                    `F3_SRL_SRA: alusel_o = (funct7_i == `FUNCT7_ALT) ? `ALU_SRA : `ALU_SRL;
                    `F3_OR:      alusel_o = `ALU_OR;
                    `F3_AND:     alusel_o = `ALU_AND;
                    default:     alusel_o = 'x;
                endcase
            end
            `OPC_ITYPE: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_ALU;
                rs2sel_o  = 1'b1;
                unique case (funct3_i)
                    `F3_ADD_SUB: alusel_o = `ALU_ADD;
                    `F3_SLT:     alusel_o = `ALU_SLT;
                    `F3_SLTU:    alusel_o = `ALU_SLTU;
                    `F3_XOR:     alusel_o = `ALU_XOR;
                    `F3_OR:      alusel_o = `ALU_OR;
                    `F3_AND:     alusel_o = `ALU_AND;
                    `F3_SLL:     alusel_o = `ALU_SLL;
                    `F3_SRL_SRA: alusel_o = (funct7_i == `FUNCT7_ALT) ? `ALU_SRA : `ALU_SRL;
                    default:     alusel_o = 'x;
                endcase
            end
            `OPC_LOAD: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_MEM;
                rs2sel_o  = 1'b1;
                memren_o  = 1'b1;
            end
            `OPC_STORE: begin
                rs2sel_o  = 1'b1;
                memwren_o = 1'b1;
            end
            `OPC_BRANCH: begin
                rs1sel_o  = 1'b1;
                rs2sel_o  = 1'b1;
            end
            `OPC_JAL: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_PC4;
                rs1sel_o  = 1'b1;
                rs2sel_o  = 1'b1;
                pcsel_o   = 1'b1;
            end
            `OPC_JALR: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_PC4;
                rs2sel_o  = 1'b1;
                pcsel_o   = 1'b1;
            end
            `OPC_LUI: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_ALU;
                rs2sel_o  = 1'b1;
            end
            `OPC_AUIPC: begin
                regwren_o = 1'b1;
                wbsel_o   = `WB_ALU;
                rs1sel_o  = 1'b1;
                rs2sel_o  = 1'b1;
            end
            `OPC_FENCE:  begin /* NOP */ end
            `OPC_SYSTEM: begin /* NOP - ecall handled by testbench */ end
            default: begin
                pcsel_o   = 'x;
                regwren_o = 'x;
                rs1sel_o  = 'x;
                rs2sel_o  = 'x;
                memren_o  = 'x;
                memwren_o = 'x;
                wbsel_o   = 'x;
                alusel_o  = 'x;
            end
        endcase
    end

endmodule : control
