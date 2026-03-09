`include "constants.svh"

// Simple byte-addressable data RAM with size-aware reads and writes.
// This is the data memory only; instruction memory lives inside fetch.
module ram #(
    parameter int AWIDTH    = 32,
    parameter int DWIDTH    = 32,
    parameter int BASE_ADDR = 32'h0200_0000,
    parameter int DEPTH     = 65536
)(
    input  logic              clk,
    input  logic [AWIDTH-1:0] addr_i,
    input  logic [DWIDTH-1:0] data_i,
    input  logic              wen_i,
    input  logic              ren_i,
    input  logic [2:0]        funct3_i,
    output logic [DWIDTH-1:0] data_o
);

    logic [7:0] mem [0:DEPTH-1];
    logic [AWIDTH-1:0] idx;
    localparam logic [31:0] MASK = DEPTH - 1;

    assign idx = (addr_i - BASE_ADDR) & MASK;

    initial begin
        for (int i = 0; i < DEPTH; i++) mem[i] = 8'h00;
    end

    // Read: size-aware with sign/zero extension
    logic [7:0]  bv;
    logic [15:0] hv;
    logic [31:0] wv;

    always_comb begin
        bv = mem[idx];
        hv = {mem[(idx + 1) & MASK], mem[idx]};
        wv = {mem[(idx + 3) & MASK], mem[(idx + 2) & MASK],
              mem[(idx + 1) & MASK], mem[idx]};

        unique case (funct3_i)
            `F3_BYTE:  data_o = {{24{bv[7]}}, bv};
            `F3_HALF:  data_o = {{16{hv[15]}}, hv};
            `F3_WORD:  data_o = wv;
            `F3_BYTEU: data_o = {24'b0, bv};
            `F3_HALFU: data_o = {16'b0, hv};
            default:   data_o = wv;
        endcase
    end

    // Write: size-aware
    always_ff @(posedge clk) begin
        if (wen_i) begin
            unique case (funct3_i)
                `F3_BYTE: begin
                    mem[idx] <= data_i[7:0];
                end
                `F3_HALF: begin
                    mem[idx]              <= data_i[7:0];
                    mem[(idx + 1) & MASK] <= data_i[15:8];
                end
                default: begin
                    mem[idx]              <= data_i[7:0];
                    mem[(idx + 1) & MASK] <= data_i[15:8];
                    mem[(idx + 2) & MASK] <= data_i[23:16];
                    mem[(idx + 3) & MASK] <= data_i[31:24];
                end
            endcase
        end
    end

endmodule : ram
