`include "constants.svh"

module fetch #(
    parameter int DWIDTH    = 32,
    parameter int AWIDTH    = 32,
    parameter int BASE_ADDR = 32'h0100_0000,
    parameter int DEPTH     = 16384
)(
    input  logic              clk,
    input  logic              rst,
    input  logic [AWIDTH-1:0] next_pc_i,
    input  logic              brtaken_i,
    output logic [AWIDTH-1:0] pc_o,
    output logic [DWIDTH-1:0] insn_o
);

    // PC register
    logic [AWIDTH-1:0] pc_q = BASE_ADDR;
    assign pc_o = pc_q;

    always_ff @(posedge clk) begin
        if (rst)
            pc_q <= BASE_ADDR;
        else if (brtaken_i)
            pc_q <= next_pc_i;
        else
            pc_q <= pc_q + 32'd4;
    end

    // Instruction ROM
    logic [31:0] imem [0:DEPTH-1];

    initial begin
        for (int i = 0; i < DEPTH; i++) imem[i] = 32'h0000_0013; // NOP (addi x0, x0, 0)
        $readmemh(`MEM_PATH, imem);
    end

    assign insn_o = imem[(pc_q - BASE_ADDR) >> 2];

endmodule : fetch
