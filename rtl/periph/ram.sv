`include "constants.svh"

// Word-addressed data RAM using 4 byte-banks for efficient block-RAM inference.
// Each bank is WORDS × 8-bit → 4 banks = DEPTH total bytes.
// Byte-lane steering handles LB/LH/LW/SB/SH/SW with funct3.
// Aligned accesses only (RISC-V base spec allows trapping on misalignment).
//
// Read path is combinational so the single-cycle CPU can use data in the
// same cycle.  Quartus may infer this as MLAB (distributed) rather than
// M9K block RAM.  For 8 KB that fits comfortably in the MAX 10's MLABs.
module ram #(
    parameter int AWIDTH    = 32,
    parameter int DWIDTH    = 32,
    parameter int BASE_ADDR = 32'h0200_0000,
    parameter int DEPTH     = 8192           // total bytes (8 KB)
)(
    input  logic              clk,
    input  logic [AWIDTH-1:0] addr_i,
    input  logic [DWIDTH-1:0] data_i,
    input  logic              wen_i,
    input  logic              ren_i,
    input  logic [2:0]        funct3_i,
    output logic [DWIDTH-1:0] data_o
);

    // ── address decomposition ──
    localparam int WORDS = DEPTH / 4;
    localparam int WBITS = $clog2(WORDS);

    logic [AWIDTH-1:0] offset;
    logic [WBITS-1:0]  waddr;
    logic [1:0]        boff;

    assign offset = addr_i - BASE_ADDR;
    assign waddr  = offset[WBITS+1:2];
    assign boff   = offset[1:0];

    // ── four byte-wide memories ──
    (* ramstyle = "no_rw_check" *)  logic [7:0] bank0 [0:WORDS-1];
    (* ramstyle = "no_rw_check" *)  logic [7:0] bank1 [0:WORDS-1];
    (* ramstyle = "no_rw_check" *)  logic [7:0] bank2 [0:WORDS-1];
    (* ramstyle = "no_rw_check" *)  logic [7:0] bank3 [0:WORDS-1];

    // ── combinational read ──
    logic [7:0]  rd0, rd1, rd2, rd3;
    assign rd0 = bank0[waddr];
    assign rd1 = bank1[waddr];
    assign rd2 = bank2[waddr];
    assign rd3 = bank3[waddr];

    logic [31:0] word_rd;
    logic [7:0]  byte_rd;
    logic [15:0] half_rd;

    assign word_rd = {rd3, rd2, rd1, rd0};

    always_comb begin
        unique case (boff)
            2'd0: byte_rd = rd0;
            2'd1: byte_rd = rd1;
            2'd2: byte_rd = rd2;
            2'd3: byte_rd = rd3;
        endcase

        half_rd = boff[1] ? {rd3, rd2} : {rd1, rd0};

        unique case (funct3_i)
            `F3_BYTE:  data_o = {{24{byte_rd[7]}}, byte_rd};
            `F3_HALF:  data_o = {{16{half_rd[15]}}, half_rd};
            `F3_WORD:  data_o = word_rd;
            `F3_BYTEU: data_o = {24'b0, byte_rd};
            `F3_HALFU: data_o = {16'b0, half_rd};
            default:   data_o = word_rd;
        endcase
    end

    // ── byte-enable generation ──
    logic [3:0] be;
    always_comb begin
        be = 4'b0000;
        unique case (funct3_i)
            `F3_BYTE, `F3_BYTEU: begin
                be[boff] = 1'b1;
            end
            `F3_HALF, `F3_HALFU: begin
                be[boff]     = 1'b1;
                be[boff | 1] = 1'b1;
            end
            default: begin
                be = 4'b1111;
            end
        endcase
    end

    // ── write: data routing per byte-lane ──
    // SB: rs2[7:0] goes to the selected bank
    // SH: rs2[15:0] goes to the selected pair of banks
    // SW: rs2[31:0] goes to all 4 banks
    logic [7:0] wd0, wd1, wd2, wd3;

    always_comb begin
        // Default: word store — straightforward mapping
        wd0 = data_i[ 7: 0];
        wd1 = data_i[15: 8];
        wd2 = data_i[23:16];
        wd3 = data_i[31:24];

        unique case (funct3_i)
            `F3_BYTE, `F3_BYTEU: begin
                // Replicate the low byte to all lanes; byte-enable selects which bank
                wd0 = data_i[7:0];
                wd1 = data_i[7:0];
                wd2 = data_i[7:0];
                wd3 = data_i[7:0];
            end
            `F3_HALF, `F3_HALFU: begin
                // Replicate the low halfword to both pairs
                wd0 = data_i[ 7:0];
                wd1 = data_i[15:8];
                wd2 = data_i[ 7:0];
                wd3 = data_i[15:8];
            end
            default: ; // word — keep defaults
        endcase
    end

    always_ff @(posedge clk) begin
        if (wen_i) begin
            if (be[0]) bank0[waddr] <= wd0;
            if (be[1]) bank1[waddr] <= wd1;
            if (be[2]) bank2[waddr] <= wd2;
            if (be[3]) bank3[waddr] <= wd3;
        end
    end

endmodule : ram
