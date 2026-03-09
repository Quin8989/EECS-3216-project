`include "constants.svh"

module cpu #(
    parameter int AWIDTH = 32,
    parameter int DWIDTH = 32
)(
    input  logic              clk,
    input  logic              reset,

    // Data bus interface
    output logic [AWIDTH-1:0] dmem_addr_o,
    output logic [DWIDTH-1:0] dmem_wdata_o,
    input  logic [DWIDTH-1:0] dmem_rdata_i,
    output logic              dmem_wen_o,
    output logic              dmem_ren_o,
    output logic [2:0]        dmem_funct3_o
);

    // --- Fetch ---
    logic [AWIDTH-1:0] pc;
    logic [DWIDTH-1:0] insn;
    logic [DWIDTH-1:0] alu_res;
    logic              brtaken;

    fetch #(
        .DWIDTH(DWIDTH),
        .AWIDTH(AWIDTH)
    ) u_fetch (
        .clk       (clk),
        .rst       (reset),
        .next_pc_i (alu_res),
        .brtaken_i (brtaken),
        .pc_o      (pc),
        .insn_o    (insn)
    );

    // --- Decode (inlined) ---
    logic [6:0] opcode;
    logic [4:0] rd;
    logic [2:0] funct3;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [6:0] funct7;

    assign opcode = insn[6:0];
    assign rd     = insn[11:7];
    assign funct3 = insn[14:12];
    assign rs1    = insn[19:15];
    assign rs2    = insn[24:20];
    assign funct7 = insn[31:25];

    // --- Immediate generator ---
    logic [DWIDTH-1:0] imm;

    igen #(.DWIDTH(DWIDTH)) u_igen (
        .opcode_i (opcode),
        .insn_i   (insn),
        .imm_o    (imm)
    );

    // --- Control ---
    logic       pcsel, regwren, rs1sel, rs2sel, memren, memwren;
    logic [1:0] wbsel;
    logic [3:0] alusel;

    control u_control (
        .opcode_i  (opcode),
        .funct7_i  (funct7),
        .funct3_i  (funct3),
        .pcsel_o   (pcsel),
        .regwren_o (regwren),
        .rs1sel_o  (rs1sel),
        .rs2sel_o  (rs2sel),
        .memren_o  (memren),
        .memwren_o (memwren),
        .wbsel_o   (wbsel),
        .alusel_o  (alusel)
    );

    // --- Register file ---
    logic [DWIDTH-1:0] rs1_data, rs2_data, wb_data;

    register_file #(.DWIDTH(DWIDTH)) u_regfile (
        .clk       (clk),
        .rst       (reset),
        .rs1_i     (rs1),
        .rs2_i     (rs2),
        .rd_i      (rd),
        .datawb_i  (wb_data),
        .regwren_i (regwren),
        .rs1data_o (rs1_data),
        .rs2data_o (rs2_data)
    );

    // --- Operand muxes ---
    // LUI: force op1 to 0 (insn[19:15] is part of the immediate, not a register)
    logic [DWIDTH-1:0] alu_op1, alu_op2;
    assign alu_op1 = (opcode == `OPC_LUI) ? '0 : (rs1sel ? pc : rs1_data);
    assign alu_op2 = rs2sel ? imm : rs2_data;

    // --- ALU ---

    execute #(.DWIDTH(DWIDTH)) u_alu (
        .rs1_i    (alu_op1),
        .rs2_i    (alu_op2),
        .alusel_i (alusel),
        .res_o    (alu_res)
    );

    // --- Branch control ---
    logic breq, brlt, br_taken;

    branch_control #(.DWIDTH(DWIDTH)) u_branch (
        .funct3_i (funct3),
        .rs1_i    (rs1_data),
        .rs2_i    (rs2_data),
        .breq_o   (breq),
        .brlt_o   (brlt)
    );

    always_comb begin
        br_taken = 1'b0;
        if (opcode == `OPC_BRANCH) begin
            unique case (funct3)
                `F3_BEQ:  br_taken =  breq;
                `F3_BNE:  br_taken = ~breq;
                `F3_BLT:  br_taken =  brlt;
                `F3_BGE:  br_taken = ~brlt;
                `F3_BLTU: br_taken =  brlt;
                `F3_BGEU: br_taken = ~brlt;
                default:  br_taken = 1'b0;
            endcase
        end
    end

    assign brtaken = br_taken | pcsel;

    // --- Data bus outputs ---
    assign dmem_addr_o    = alu_res;
    assign dmem_wdata_o   = rs2_data;
    assign dmem_wen_o     = memwren;
    assign dmem_ren_o     = memren;
    assign dmem_funct3_o  = funct3;

    // --- Writeback (inlined) ---
    always_comb begin
        unique case (wbsel)
            `WB_ALU: wb_data = alu_res;
            `WB_MEM: wb_data = dmem_rdata_i;
            `WB_PC4: wb_data = pc + 32'd4;
            default: wb_data = alu_res;
        endcase
    end

endmodule : cpu
