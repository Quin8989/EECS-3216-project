// ============================================================
// alu.sv — Arithmetic Logic Unit + multi-cycle operation stalls
//
// Purpose:
//   Executes the arithmetic or logic operation selected by
//   alusel_i and produces a 32-bit result.  Also manages the
//   multi-cycle stall pipelines for shift, MUL, and DIV/REM
//   instructions so they don't sit on the critical timing path.
//
// Single-cycle operations (result valid on same clock edge):
//   ADD, SUB, AND, OR, XOR, SLT, SLTU
//
// Two-cycle operations (stall for 1 extra cycle):
//   SLL, SRL, SRA — barrel shifter result registered in cycle 1,
//                   written back in cycle 2.
//   MUL/MULH/MULHSU/MULHU — same 2-cycle pattern.
//
// 34-cycle operations (stall for 33 extra cycles):
//   DIV, DIVU, REM, REMU — inline iterative restoring division
//   (1 setup + 32 iteration cycles + 1 wb).
//   Special cases (div-by-zero, signed overflow) are resolved
//   in 1 cycle without invoking the iterative path.
// ============================================================
`include "constants.svh"

module alu #(
    parameter int DWIDTH = 32
)(
    input  logic              clk,
    input  logic              reset,

    input  logic [DWIDTH-1:0] alu_op1_i,    // operand 1 (rs1_data or PC)
    input  logic [DWIDTH-1:0] alu_op2_i,    // operand 2 (rs2_data or immediate)
    input  logic [4:0]        alusel_i,     // operation select from control.sv

    output logic [DWIDTH-1:0] result_o,     // final result (1 or 2 cycles)
    output logic              shift_stall_o,// 1 during cycle 1 of a shift
    output logic              mul_stall_o,  // 1 during cycle 1 of a MUL
    output logic              div_stall_o   // 1 while DIV/REM is in progress
);

    // ── Combinational ALU core ──────────────────────────────────
    logic [DWIDTH-1:0]   alu_res_comb;  // single-cycle result
    logic [2*DWIDTH-1:0] mul_full_res;  // 64-bit MUL product

    // RISC-V signed-overflow constants (DIV / REM spec §7.2)
    localparam logic [DWIDTH-1:0] INT_MIN  = {1'b1, {(DWIDTH-1){1'b0}}};  // 0x80000000
    localparam logic [DWIDTH-1:0] ALL_ONES = '1;                           // 0xffffffff (-1)

    always_comb begin
        alu_res_comb = '0;
        mul_full_res = '0;
        case (alusel_i)
            `ALU_ADD:  alu_res_comb = alu_op1_i + alu_op2_i;
            `ALU_SUB:  alu_res_comb = alu_op1_i - alu_op2_i;
            `ALU_AND:  alu_res_comb = alu_op1_i & alu_op2_i;
            `ALU_OR:   alu_res_comb = alu_op1_i | alu_op2_i;
            `ALU_XOR:  alu_res_comb = alu_op1_i ^ alu_op2_i;
            `ALU_SLL:  alu_res_comb = alu_op1_i << alu_op2_i[4:0];
            `ALU_SRL:  alu_res_comb = alu_op1_i >> alu_op2_i[4:0];
            `ALU_SRA:  alu_res_comb = $signed(alu_op1_i) >>> alu_op2_i[4:0];
            `ALU_SLT:  alu_res_comb = ($signed(alu_op1_i) < $signed(alu_op2_i)) ? 32'd1 : 32'd0;
            `ALU_SLTU: alu_res_comb = (alu_op1_i < alu_op2_i) ? 32'd1 : 32'd0;
            `ALU_MUL:
                mul_full_res = $signed(alu_op1_i) * $signed(alu_op2_i);
            `ALU_MULH:
                mul_full_res = $signed(alu_op1_i) * $signed(alu_op2_i);
            `ALU_MULHSU:
                mul_full_res = $signed({{DWIDTH{alu_op1_i[DWIDTH-1]}}, alu_op1_i}) *
                               $signed({{DWIDTH{1'b0}}, alu_op2_i});
            `ALU_MULHU:
                mul_full_res = {{DWIDTH{1'b0}}, alu_op1_i} * {{DWIDTH{1'b0}}, alu_op2_i};
            // DIV/DIVU/REM/REMU handled by iterative divider below
            default:   alu_res_comb = '0;
        endcase
    end

    // ── Shift 2-cycle stall ─────────────────────────────────────
    logic is_shift;
    logic shift_wb;
    logic [DWIDTH-1:0] shift_result_r;

    assign is_shift      = (alusel_i == `ALU_SLL) |
                           (alusel_i == `ALU_SRL) |
                           (alusel_i == `ALU_SRA);
    assign shift_stall_o = is_shift & ~shift_wb;

    always_ff @(posedge clk) begin
        if (reset)  shift_wb <= 1'b0;
        else        shift_wb <= shift_stall_o;
    end

    always_ff @(posedge clk) begin
        if (shift_stall_o)
            shift_result_r <= alu_res_comb;
    end

    // ── MUL 2-cycle stall (MUL, MULH, MULHSU, MULHU) ───────────
    logic is_mul;
    logic mul_wb;
    logic [DWIDTH-1:0] mul_result_r;

    assign is_mul      = (alusel_i == `ALU_MUL)   | (alusel_i == `ALU_MULH) |
                         (alusel_i == `ALU_MULHSU) | (alusel_i == `ALU_MULHU);
    assign mul_stall_o = is_mul & ~mul_wb;

    always_ff @(posedge clk) begin
        if (reset)  mul_wb <= 1'b0;
        else        mul_wb <= mul_stall_o;
    end

    // Select lower or upper half of the 64-bit multiply product.
    // Feeds only mul_result_r (registered), keeping the multiplier
    // carry chain off the single-cycle alu_res_comb critical path.
    logic [DWIDTH-1:0] mul_result_sel;
    assign mul_result_sel = (alusel_i == `ALU_MUL)
                          ? mul_full_res[DWIDTH-1:0]
                          : mul_full_res[2*DWIDTH-1:DWIDTH];

    always_ff @(posedge clk) begin
        if (mul_stall_o)
            mul_result_r <= mul_result_sel;
    end

    // ── DIV/REM — inline iterative restoring divider (33 cycles) ──
    logic              is_div;

    // Unsigned restoring divider state
    logic [DWIDTH-1:0] div_quo;       // quotient accumulator
    logic [DWIDTH:0]   div_rem;       // remainder accumulator (WIDTH+1 bits)
    logic [DWIDTH-1:0] div_dvsr_r;    // latched divisor
    logic [5:0]        div_count;     // iteration counter (0..32)
    logic              div_running;

    wire div_done = div_running && (div_count == 0);

    // Combinational trial subtraction
    logic [DWIDTH:0] div_rem_shifted, div_rem_trial;
    always_comb begin
        div_rem_shifted = {div_rem[DWIDTH-1:0], div_quo[DWIDTH-1]};
        div_rem_trial   = div_rem_shifted - {1'b0, div_dvsr_r};
    end

    assign is_div = (alusel_i == `ALU_DIV)  | (alusel_i == `ALU_DIVU) |
                    (alusel_i == `ALU_REM)  | (alusel_i == `ALU_REMU);

    // Sign handling for signed DIV/REM: feed absolute values to the
    // unsigned divider, then fix up the signs of quotient and remainder.
    logic op1_neg, op2_neg;
    assign op1_neg = alu_op1_i[DWIDTH-1];
    assign op2_neg = alu_op2_i[DWIDTH-1];

    logic is_signed_div;
    assign is_signed_div = (alusel_i == `ALU_DIV) | (alusel_i == `ALU_REM);

    logic is_rem_op;
    assign is_rem_op = (alusel_i == `ALU_REM) | (alusel_i == `ALU_REMU);

    // Absolute values for signed operations
    logic [DWIDTH-1:0] abs_op1, abs_op2;
    assign abs_op1 = (is_signed_div && op1_neg) ? (~alu_op1_i + 1) : alu_op1_i;
    assign abs_op2 = (is_signed_div && op2_neg) ? (~alu_op2_i + 1) : alu_op2_i;

    // Sign-corrected results (combinational, used on div_done cycle)
    logic [DWIDTH-1:0] div_quo_fixed, div_rem_fixed;
    assign div_quo_fixed = div_negate_quo_r ? (~div_quo + 1) : div_quo;
    assign div_rem_fixed = div_negate_rem_r ? (~div_rem[DWIDTH-1:0] + 1) : div_rem[DWIDTH-1:0];

    // Division state machine
    typedef enum logic [1:0] {
        DIV_IDLE,
        DIV_SPECIAL,    // 1 extra stall cycle for special-case result
        DIV_RUNNING,    // iterative divider in progress
        DIV_WB          // writeback cycle — result ready
    } div_state_t;

    div_state_t div_state, div_state_next;
    logic [DWIDTH-1:0] div_result_r;

    // Latch the operation type at start so we know quotient vs remainder
    // and sign fixup even after alusel_i changes (though with stall it shouldn't).
    logic div_is_rem_r, div_negate_quo_r, div_negate_rem_r;

    always_ff @(posedge clk) begin
        if (reset)
            div_state <= DIV_IDLE;
        else
            div_state <= div_state_next;
    end

    always_comb begin
        div_state_next = div_state;

        case (div_state)
            DIV_IDLE: begin
                if (is_div) begin
                    if (alu_op2_i == '0) begin
                        div_state_next = DIV_SPECIAL;
                    end else if (is_signed_div && alu_op1_i == INT_MIN && alu_op2_i == ALL_ONES) begin
                        div_state_next = DIV_SPECIAL;
                    end else begin
                        div_state_next = DIV_RUNNING;
                    end
                end
            end
            DIV_SPECIAL: begin
                div_state_next = DIV_WB;
            end
            DIV_RUNNING: begin
                if (div_done)
                    div_state_next = DIV_WB;
            end
            DIV_WB: begin
                div_state_next = DIV_IDLE;
            end
        endcase
    end

    // Unsigned restoring divider iteration + result/sign latch
    always_ff @(posedge clk) begin
        if (reset) begin
            div_running <= 1'b0;
            div_count   <= '0;
            div_quo     <= '0;
            div_rem     <= '0;
            div_dvsr_r  <= '0;
        end else if (div_state == DIV_IDLE && is_div) begin
            // Latch sign flags and operation type
            div_is_rem_r     <= is_rem_op;
            div_negate_quo_r <= is_signed_div && (op1_neg ^ op2_neg);
            div_negate_rem_r <= is_signed_div && op1_neg;

            if (alu_op2_i == '0) begin
                // Div by zero: DIV→all-ones, REM→dividend
                div_result_r <= is_rem_op ? alu_op1_i : ALL_ONES;
            end else if (is_signed_div && alu_op1_i == INT_MIN && alu_op2_i == ALL_ONES) begin
                // Signed overflow: DIV→INT_MIN, REM→0
                div_result_r <= is_rem_op ? '0 : INT_MIN;
            end else begin
                // Normal case — start iterative divider
                div_running <= 1'b1;
                div_count   <= DWIDTH[5:0];
                div_quo     <= abs_op1;
                div_rem     <= '0;
                div_dvsr_r  <= abs_op2;
            end
        end else if (div_running) begin
            if (div_count == 0) begin
                // Division complete — latch sign-corrected result, stop
                div_running  <= 1'b0;
                div_result_r <= div_is_rem_r ? div_rem_fixed : div_quo_fixed;
            end else begin
                if (!div_rem_trial[DWIDTH]) begin
                    div_rem <= div_rem_trial;
                    div_quo <= {div_quo[DWIDTH-2:0], 1'b1};
                end else begin
                    div_rem <= div_rem_shifted;
                    div_quo <= {div_quo[DWIDTH-2:0], 1'b0};
                end
                div_count <= div_count - 1;
            end
        end
    end

    // Stall: high from IDLE→SPECIAL/RUNNING until WB
    assign div_stall_o = (div_state == DIV_SPECIAL) |
                         (div_state == DIV_RUNNING)  |
                         (div_state == DIV_IDLE && is_div);

    logic div_wb;
    assign div_wb = (div_state == DIV_WB);

    // ── Final result mux ────────────────────────────────────────
    assign result_o = div_wb   ? div_result_r   :
                      mul_wb   ? mul_result_r   :
                      shift_wb ? shift_result_r :
                                 alu_res_comb;

endmodule : alu
