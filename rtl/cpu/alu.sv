// ============================================================
// alu.sv — Arithmetic Logic Unit + multi-cycle operation stalls
//
// Purpose:
//   Executes the arithmetic or logic operation selected by
//   alusel_i and produces a 32-bit result.  Also manages the
//   2-cycle stall pipelines for shift and MUL instructions so
//   they don't sit on the critical timing path.
//
// Single-cycle operations (result valid on same clock edge):
//   ADD, SUB, AND, OR, XOR, SLT, SLTU
//
// Two-cycle operations (stall for 1 extra cycle):
//   SLL, SRL, SRA — barrel shifter result registered in cycle 1,
//                   written back in cycle 2.  Keeps the shifter
//                   off the critical path (saves ~8-10 ns).
//   MUL           — same 2-cycle pattern.  Only lower 32 bits
//                   of the 64-bit product are kept (Zmmul spec).
//
// Stall outputs:
//   shift_stall_o and mul_stall_o are asserted during cycle 1
//   (the compute cycle) to freeze fetch and register writeback.
//   They deassert in cycle 2 so the result propagates normally.
//
// Inputs:
//   clk, reset
//   alu_op1_i, alu_op2_i — operands from cpu.sv operand muxes
//   alusel_i             — operation select from control.sv
//
// Outputs:
//   result_o     — final ALU result (combinational or registered)
//   shift_stall_o, mul_stall_o — stall request to cpu.sv
//
// Connected to:
//   cpu.sv (any_stall, next_pc via alu_res)
//   register_file.sv (wb_data via writeback.sv)
//   data bus (dmem_addr = alu_res for loads/stores)
// ============================================================
`include "constants.svh"

module alu #(
    parameter int DWIDTH = 32
)(
    input  logic              clk,
    input  logic              reset,

    input  logic [DWIDTH-1:0] alu_op1_i,    // operand 1 (rs1_data or PC)
    input  logic [DWIDTH-1:0] alu_op2_i,    // operand 2 (rs2_data or immediate)
    input  logic [3:0]        alusel_i,     // operation select from control.sv

    output logic [DWIDTH-1:0] result_o,     // final result (1 or 2 cycles)
    output logic              shift_stall_o,// 1 during cycle 1 of a shift
    output logic              mul_stall_o   // 1 during cycle 1 of a MUL
);

    // ── Combinational ALU core ──────────────────────────────────
    logic [DWIDTH-1:0]   alu_res_comb;  // single-cycle result
    logic [2*DWIDTH-1:0] mul_full_res;  // 64-bit MUL product (only lower 32 used)

    always_comb begin
        alu_res_comb = '0;
        mul_full_res = '0;
        case (alusel_i)
            `ALU_ADD:  alu_res_comb = alu_op1_i + alu_op2_i;
            `ALU_SUB:  alu_res_comb = alu_op1_i - alu_op2_i;
            `ALU_AND:  alu_res_comb = alu_op1_i & alu_op2_i;
            `ALU_OR:   alu_res_comb = alu_op1_i | alu_op2_i;
            `ALU_XOR:  alu_res_comb = alu_op1_i ^ alu_op2_i;
            // Shift amount is in the low 5 bits of op2 (spec §2.6)
            `ALU_SLL:  alu_res_comb = alu_op1_i << alu_op2_i[4:0];
            `ALU_SRL:  alu_res_comb = alu_op1_i >> alu_op2_i[4:0];
            // $signed cast makes >>> an arithmetic (sign-extending) right shift
            `ALU_SRA:  alu_res_comb = $signed(alu_op1_i) >>> alu_op2_i[4:0];
            // Signed less-than: $signed cast before comparison
            `ALU_SLT:  alu_res_comb = ($signed(alu_op1_i) < $signed(alu_op2_i)) ? 32'd1 : 32'd0;
            // Unsigned less-than: no cast needed (default interpretation)
            `ALU_SLTU: alu_res_comb = (alu_op1_i < alu_op2_i) ? 32'd1 : 32'd0;
            `ALU_MUL: begin
                // 64-bit signed product; only lower 32 bits kept (RV32M MUL)
                mul_full_res = $signed(alu_op1_i) * $signed(alu_op2_i);
                alu_res_comb = mul_full_res[DWIDTH-1:0];
            end
            default:   alu_res_comb = '0;
        endcase
    end

    // ── Shift 2-cycle stall ─────────────────────────────────────
    logic is_shift;
    logic shift_wb;            // high during the writeback cycle
    logic [DWIDTH-1:0] shift_result_r;  // registered barrel-shifter output

    assign is_shift      = (alusel_i == `ALU_SLL) |
                           (alusel_i == `ALU_SRL) |
                           (alusel_i == `ALU_SRA);

    // Stall asserted on cycle 1 (compute), deasserts on cycle 2 (writeback)
    assign shift_stall_o = is_shift & ~shift_wb;

    always_ff @(posedge clk) begin
        if (reset)  shift_wb <= 1'b0;
        else        shift_wb <= shift_stall_o;  // shift_wb = 1 exactly one cycle later
    end

    // Capture the barrel-shifter result during the stall cycle
    always_ff @(posedge clk) begin
        if (shift_stall_o)
            shift_result_r <= alu_res_comb;
    end

    // ── MUL 2-cycle stall ───────────────────────────────────────
    logic is_mul;
    logic mul_wb;              // high during the writeback cycle
    logic [DWIDTH-1:0] mul_result_r;    // registered multiplier output

    assign is_mul      = (alusel_i == `ALU_MUL);
    assign mul_stall_o = is_mul & ~mul_wb;

    always_ff @(posedge clk) begin
        if (reset)  mul_wb <= 1'b0;
        else        mul_wb <= mul_stall_o;
    end

    always_ff @(posedge clk) begin
        if (mul_stall_o)
            mul_result_r <= alu_res_comb;
    end

    // ── Final result mux ────────────────────────────────────────
    // On the writeback cycle of a multi-cycle op, use the registered result;
    // otherwise pass through the combinational output directly.
    assign result_o = mul_wb   ? mul_result_r   :
                      shift_wb ? shift_result_r :
                                 alu_res_comb;

endmodule : alu
