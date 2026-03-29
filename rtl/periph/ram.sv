`include "constants.svh"

// Simple 32-bit data RAM with byte-lane write enables.
// Uses registered byte offset for proper timing with 2-cycle loads.
module ram #(
    parameter int AWIDTH = 32,
    parameter int DWIDTH = 32,
    parameter int DEPTH  = 8192           // total bytes (8 KB)
)(
    input  logic              clk,
    input  logic [AWIDTH-1:0] addr_i,
    input  logic [DWIDTH-1:0] data_i,
    input  logic              wen_i,
    input  logic [2:0]        funct3_i,
    output logic [DWIDTH-1:0] data_o
);

    localparam int WORDS = DEPTH / 4;
    localparam int WBITS = $clog2(WORDS);

    logic [WBITS-1:0] waddr;
    logic [1:0]       boff;
    assign waddr = addr_i[WBITS+1:2];
    assign boff  = addr_i[1:0];

    // Byte-enable generation for writes
    logic [3:0] be;
    always_comb begin
        case (funct3_i)
            `F3_BYTE, `F3_BYTEU: be = 4'b0001 << boff;
            `F3_HALF, `F3_HALFU: be = boff[1] ? 4'b1100 : 4'b0011;
            default:             be = 4'b1111;
        endcase
    end

    // Write-data routing (replicate byte/half to correct lanes)
    logic [7:0] wd0, wd1, wd2, wd3;
    always_comb begin
        case (funct3_i)
            `F3_BYTE, `F3_BYTEU: {wd3, wd2, wd1, wd0} = {4{data_i[7:0]}};
            `F3_HALF, `F3_HALFU: {wd3, wd2, wd1, wd0} = {2{data_i[15:0]}};
            default:             {wd3, wd2, wd1, wd0} = data_i;
        endcase
    end

    // Four byte-wide banks — each in its own submodule for guaranteed M9K inference
    logic [7:0] rd0, rd1, rd2, rd3;
    logic [1:0] boff_r;
    logic [2:0] funct3_r;

    bram #(.DEPTH(WORDS), .DUAL_PORT(0)) u_bank0 (
        .clk(clk), .addr_a(waddr), .wdata_a(wd0), .we_a(wen_i & be[0]),
        .rdata_a(rd0), .addr_b('0), .rdata_b()
    );
    bram #(.DEPTH(WORDS), .DUAL_PORT(0)) u_bank1 (
        .clk(clk), .addr_a(waddr), .wdata_a(wd1), .we_a(wen_i & be[1]),
        .rdata_a(rd1), .addr_b('0), .rdata_b()
    );
    bram #(.DEPTH(WORDS), .DUAL_PORT(0)) u_bank2 (
        .clk(clk), .addr_a(waddr), .wdata_a(wd2), .we_a(wen_i & be[2]),
        .rdata_a(rd2), .addr_b('0), .rdata_b()
    );
    bram #(.DEPTH(WORDS), .DUAL_PORT(0)) u_bank3 (
        .clk(clk), .addr_a(waddr), .wdata_a(wd3), .we_a(wen_i & be[3]),
        .rdata_a(rd3), .addr_b('0), .rdata_b()
    );

    always_ff @(posedge clk) begin
        boff_r   <= boff;
        funct3_r <= funct3_i;
    end

    // Byte/half extraction with registered offset
    logic [31:0] word;
    logic [7:0]  bval;
    logic [15:0] hval;
    assign word = {rd3, rd2, rd1, rd0};

    always_comb begin
        case (boff_r)
            2'd0: bval = word[ 7: 0];
            2'd1: bval = word[15: 8];
            2'd2: bval = word[23:16];
            2'd3: bval = word[31:24];
        endcase
        hval = boff_r[1] ? word[31:16] : word[15:0];
    end

    always_comb begin
        case (funct3_r)
            `F3_BYTE:  data_o = {{24{bval[7]}}, bval};
            `F3_BYTEU: data_o = {24'b0, bval};
            `F3_HALF:  data_o = {{16{hval[15]}}, hval};
            `F3_HALFU: data_o = {16'b0, hval};
            default:   data_o = word;
        endcase
    end

endmodule : ram
