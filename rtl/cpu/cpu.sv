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
    output logic [2:0]        dmem_funct3_o,
    output logic              dmem_raw_ren_o,
    output logic              dmem_raw_wen_o,
    // External memory stall (e.g. SDRAM bridge)
    input  logic              mem_stall_i,
    // ROM data-bus read port (pass-through to fetch)
    input  logic [AWIDTH-1:0] rom_daddr_i,
    output logic [DWIDTH-1:0] rom_drdata_o,
    // ROM data-bus write port (pass-through to fetch)
    input  logic              rom_dwen_i,
    input  logic [DWIDTH-1:0] rom_dwdata_i,
    input  logic [2:0]        rom_dfunct3_i,
    // Debug
    output logic [AWIDTH-1:0]  dbg_pc_o
);

    // --- Fetch ---
    logic [AWIDTH-1:0] pc;
    assign dbg_pc_o = pc;
    logic [DWIDTH-1:0] insn;
    logic [DWIDTH-1:0] alu_res;
    logic              brtaken;

    logic [AWIDTH-1:0] next_pc;

    // --- Load stall logic ---
    // Synchronous memories need 1 extra cycle; stall the pipe on loads.
    logic load_stall;   // combinational: high during the initial load cycle
    logic load_wb;      // registered: high during the writeback cycle

    always_ff @(posedge clk) begin
        if (reset)
            load_wb <= 1'b0;
        else
            load_wb <= load_stall;
    end

    // --- Shift stall logic ---
    // Two-cycle shifts: register the barrel-shifter result in cycle 1,
    // write back in cycle 2.  Removes the barrel shifter from the
    // single-cycle critical path (saves ~8-10 ns).
    logic is_shift;
    logic shift_stall, shift_wb;
    logic [DWIDTH-1:0] shift_result_r;

    // --- Multiply stall logic ---
    // Minimal RV32M support: MUL only.
    // Mirrors the existing 2-cycle shift/writeback pattern.
    logic is_mul;
    logic mul_stall, mul_wb;
    logic [DWIDTH-1:0] mul_result_r;
    logic [2*DWIDTH-1:0] mul_full_res;

    // Unified stall visible to fetch and write-enable gating
    logic any_stall;
    assign any_stall = load_stall | shift_stall | mul_stall | mem_stall_i;

    fetch #(
        .DWIDTH(DWIDTH),
        .AWIDTH(AWIDTH)
    ) u_fetch (
        .clk          (clk),
        .rst          (reset),
        .next_pc_i    (next_pc),
        .brtaken_i    (brtaken),
        .stall_i      (any_stall),
        .pc_o         (pc),
        .insn_o       (insn),
        .rom_daddr_i    (rom_daddr_i),
        .rom_drdata_o   (rom_drdata_o),
        .rom_dwen_i     (rom_dwen_i),
        .rom_dwdata_i   (rom_dwdata_i),
        .rom_dfunct3_i  (rom_dfunct3_i)
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

    // JALR clears the LSB of the computed target (RISC-V spec §2.5)
    assign next_pc = (opcode == `OPC_JALR) ? {alu_res[AWIDTH-1:1], 1'b0} : alu_res;

    // --- Immediate generator (inlined from igen.sv) ---
    logic [DWIDTH-1:0] imm;

    function automatic logic [DWIDTH-1:0] imm_i_sext(input logic [DWIDTH-1:0] ins);
        return {{DWIDTH-12{ins[31]}}, ins[31:20]};
    endfunction

    function automatic logic [DWIDTH-1:0] imm_s_sext(input logic [DWIDTH-1:0] ins);
        return {{DWIDTH-12{ins[31]}}, ins[31:25], ins[11:7]};
    endfunction

    function automatic logic [DWIDTH-1:0] imm_b_sext(input logic [DWIDTH-1:0] ins);
        return {{DWIDTH-13{ins[31]}}, ins[31], ins[7], ins[30:25], ins[11:8], 1'b0};
    endfunction

    function automatic logic [DWIDTH-1:0] imm_j_sext(input logic [DWIDTH-1:0] ins);
        return {{DWIDTH-21{ins[31]}}, ins[31], ins[19:12], ins[20], ins[30:21], 1'b0};
    endfunction

    function automatic logic [DWIDTH-1:0] imm_u(input logic [DWIDTH-1:0] ins);
        return {ins[31:12], 12'b0};
    endfunction

    function automatic logic [DWIDTH-1:0] imm_shift_zext(input logic [DWIDTH-1:0] ins);
        return {{DWIDTH-12{1'b0}}, ins[31:20]};
    endfunction

    always_comb begin
        imm = '0;
        case (opcode)
            `OPC_JAL:              imm = imm_j_sext(insn);
            `OPC_STORE:            imm = imm_s_sext(insn);
            `OPC_LUI, `OPC_AUIPC: imm = imm_u(insn);
            `OPC_ITYPE: begin
                case (funct3)
                    `F3_SLL, `F3_SRL_SRA: imm = imm_shift_zext(insn);
                    default:               imm = imm_i_sext(insn);
                endcase
            end
            `OPC_BRANCH: imm = imm_b_sext(insn);
            `OPC_JALR:   imm = imm_i_sext(insn);
            `OPC_LOAD:   imm = imm_i_sext(insn);
            default:     imm = 'x;
        endcase
    end

    // --- Control (inlined from control.sv) ---
    logic       pcsel, regwren, rs1sel, rs2sel, memren, memwren;
    logic [1:0] wbsel;
    logic [3:0] alusel;

    always_comb begin
        pcsel   = 1'b0;
        regwren = 1'b0;
        rs1sel  = 1'b0;
        rs2sel  = 1'b0;
        memren  = 1'b0;
        memwren = 1'b0;
        wbsel   = `WB_OFF;
        alusel  = `ALU_ADD;

        unique case (opcode)
            `OPC_RTYPE: begin
                regwren = 1'b1;
                wbsel   = `WB_ALU;
                if (funct7 == `FUNCT7_M) begin
                    unique case (funct3)
                        `F3_ADD_SUB: alusel = `ALU_MUL;
                        default:     alusel = 'x;
                    endcase
                end else begin
                    unique case (funct3)
                        `F3_ADD_SUB: alusel = (funct7 == `FUNCT7_ALT) ? `ALU_SUB : `ALU_ADD;
                        `F3_SLL:     alusel = `ALU_SLL;
                        `F3_SLT:     alusel = `ALU_SLT;
                        `F3_SLTU:    alusel = `ALU_SLTU;
                        `F3_XOR:     alusel = `ALU_XOR;
                        `F3_SRL_SRA: alusel = (funct7 == `FUNCT7_ALT) ? `ALU_SRA : `ALU_SRL;
                        `F3_OR:      alusel = `ALU_OR;
                        `F3_AND:     alusel = `ALU_AND;
                        default:     alusel = 'x;
                    endcase
                end
            end
            `OPC_ITYPE: begin
                regwren = 1'b1;
                wbsel   = `WB_ALU;
                rs2sel  = 1'b1;
                unique case (funct3)
                    `F3_ADD_SUB: alusel = `ALU_ADD;
                    `F3_SLT:     alusel = `ALU_SLT;
                    `F3_SLTU:    alusel = `ALU_SLTU;
                    `F3_XOR:     alusel = `ALU_XOR;
                    `F3_OR:      alusel = `ALU_OR;
                    `F3_AND:     alusel = `ALU_AND;
                    `F3_SLL:     alusel = `ALU_SLL;
                    `F3_SRL_SRA: alusel = (funct7 == `FUNCT7_ALT) ? `ALU_SRA : `ALU_SRL;
                    default:     alusel = 'x;
                endcase
            end
            `OPC_LOAD: begin
                regwren = 1'b1;
                wbsel   = `WB_MEM;
                rs2sel  = 1'b1;
                memren  = 1'b1;
            end
            `OPC_STORE: begin
                rs2sel  = 1'b1;
                memwren = 1'b1;
            end
            `OPC_BRANCH: begin
                rs1sel  = 1'b1;
                rs2sel  = 1'b1;
            end
            `OPC_JAL: begin
                regwren = 1'b1;
                wbsel   = `WB_PC4;
                rs1sel  = 1'b1;
                rs2sel  = 1'b1;
                pcsel   = 1'b1;
            end
            `OPC_JALR: begin
                regwren = 1'b1;
                wbsel   = `WB_PC4;
                rs2sel  = 1'b1;
                pcsel   = 1'b1;
            end
            `OPC_LUI: begin
                regwren = 1'b1;
                wbsel   = `WB_ALU;
                rs2sel  = 1'b1;
            end
            `OPC_AUIPC: begin
                regwren = 1'b1;
                wbsel   = `WB_ALU;
                rs1sel  = 1'b1;
                rs2sel  = 1'b1;
            end
            `OPC_FENCE:  begin /* NOP */ end
            `OPC_SYSTEM: begin /* NOP - ecall handled by testbench */ end
            default: begin
                pcsel   = 'x;
                regwren = 'x;
                rs1sel  = 'x;
                rs2sel  = 'x;
                memren  = 'x;
                memwren = 'x;
                wbsel   = 'x;
                alusel  = 'x;
            end
        endcase
    end

    // --- Register file (inlined from register_file.sv) ---
    logic [DWIDTH-1:0] rs1_data, rs2_data, wb_data;
    logic [DWIDTH-1:0] registers [0:31];

    assign rs1_data = registers[rs1];
    assign rs2_data = registers[rs2];

    // Suppress register writes during any stall cycle; allow during writeback
    logic actual_regwren;
    assign actual_regwren = regwren & ~any_stall;

    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 32; i++)
                registers[i] <= '0;
        end else if (actual_regwren && (rd != 5'd0)) begin
            registers[rd] <= wb_data;
        end
    end

    // --- Operand muxes ---
    // LUI: force op1 to 0 (insn[19:15] is part of the immediate, not a register)
    logic [DWIDTH-1:0] alu_op1, alu_op2;
    assign alu_op1 = (opcode == `OPC_LUI) ? '0 : (rs1sel ? pc : rs1_data);
    assign alu_op2 = rs2sel ? imm : rs2_data;

    // --- ALU (inlined from execute.sv) ---
    logic [DWIDTH-1:0] alu_res_comb;
    always_comb begin
        alu_res_comb = '0;
        mul_full_res = '0;
        unique case (alusel)
            `ALU_ADD:  alu_res_comb = alu_op1 + alu_op2;
            `ALU_SUB:  alu_res_comb = alu_op1 - alu_op2;
            `ALU_AND:  alu_res_comb = alu_op1 & alu_op2;
            `ALU_OR:   alu_res_comb = alu_op1 | alu_op2;
            `ALU_XOR:  alu_res_comb = alu_op1 ^ alu_op2;
            `ALU_SLL:  alu_res_comb = alu_op1 << alu_op2[4:0];
            `ALU_SRL:  alu_res_comb = alu_op1 >> alu_op2[4:0];
            `ALU_SRA:  alu_res_comb = $signed(alu_op1) >>> alu_op2[4:0];
            `ALU_SLT:  alu_res_comb = ($signed(alu_op1) < $signed(alu_op2)) ? 32'd1 : 32'd0;
            `ALU_SLTU: alu_res_comb = (alu_op1 < alu_op2) ? 32'd1 : 32'd0;
            `ALU_MUL: begin
                mul_full_res = $signed(alu_op1) * $signed(alu_op2);
                alu_res_comb = mul_full_res[DWIDTH-1:0];
            end
            default:   alu_res_comb = 'x;
        endcase
    end

    // Shift detection and stall (forward-declared above; defined here
    // after alusel is available)
    assign is_shift = (alusel == `ALU_SLL) | (alusel == `ALU_SRL) | (alusel == `ALU_SRA);
    assign shift_stall = is_shift & ~shift_wb;

    always_ff @(posedge clk) begin
        if (reset)
            shift_wb <= 1'b0;
        else
            shift_wb <= shift_stall;
    end

    // Register the barrel-shifter result during the stall cycle
    always_ff @(posedge clk) begin
        if (shift_stall)
            shift_result_r <= alu_res_comb;
    end

    assign is_mul = (alusel == `ALU_MUL);
    assign mul_stall = is_mul & ~mul_wb;

    always_ff @(posedge clk) begin
        if (reset)
            mul_wb <= 1'b0;
        else
            mul_wb <= mul_stall;
    end

    always_ff @(posedge clk) begin
        if (mul_stall)
            mul_result_r <= alu_res_comb;
    end

    // Final ALU output: use registered result on shift writeback cycle
    assign alu_res = mul_wb ? mul_result_r : (shift_wb ? shift_result_r : alu_res_comb);

    // --- Branch control (inlined from branch_control.sv) ---
    logic breq, brlt, br_taken;

    always_comb begin
        breq = (rs1_data == rs2_data);
        case (funct3[2:1])
            2'b10:   brlt = ($signed(rs1_data) < $signed(rs2_data));
            2'b11:   brlt = (rs1_data < rs2_data);
            default: brlt = 1'b0;
        endcase
    end

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

    // load_stall: asserted during the first cycle of a load (before data is ready).
    // Suppressed for SDRAM loads — the SDRAM bridge handles those via mem_stall_i.
    assign load_stall = memren & ~load_wb & ~alu_res[31];

    // Hold address and funct3 stable during load_wb (instruction has advanced,
    // but RAM data is from the previous cycle's address)
    logic [AWIDTH-1:0] dmem_addr_r;
    logic [2:0]        dmem_funct3_r;

    always_ff @(posedge clk) begin
        if (load_stall) begin
            dmem_addr_r   <= alu_res;
            dmem_funct3_r <= funct3;
        end
    end

    // --- Data bus outputs ---
    assign dmem_addr_o    = load_wb ? dmem_addr_r : alu_res;
    assign dmem_wdata_o   = rs2_data;
    assign dmem_wen_o     = memwren & ~any_stall;
    assign dmem_ren_o     = memren  & ~any_stall;   // suppress side-effect reads during stall
    assign dmem_funct3_o  = load_wb ? dmem_funct3_r : funct3;
    assign dmem_raw_ren_o = memren;
    assign dmem_raw_wen_o = memwren;

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
