`include "constants.svh"

module fetch #(
    parameter int DWIDTH    = 32,
    parameter int AWIDTH    = 32,
    parameter int BASE_ADDR = 32'h0100_0000,
    parameter int DEPTH     = 1024
)(
    input  logic              clk,
    input  logic              rst,
    input  logic [AWIDTH-1:0] next_pc_i,
    input  logic              brtaken_i,
    output logic [AWIDTH-1:0] pc_o,
    output logic [DWIDTH-1:0] insn_o,
    // Data-bus read port (shares instruction ROM — avoids a duplicate)
    input  logic [AWIDTH-1:0] rom_daddr_i,
    output logic [DWIDTH-1:0] rom_drdata_o,
    // Data-bus write port (allows stores to ROM region — needed for ISA tests)
    input  logic              rom_dwen_i,
    input  logic [DWIDTH-1:0] rom_dwdata_i,
    input  logic [2:0]        rom_dfunct3_i
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

    // Instruction ROM (NOP default = addi x0,x0,0)
    (* ramstyle = "no_rw_check" *)
    logic [31:0] imem [0:DEPTH-1];

    initial $readmemh(`MEM_PATH, imem);

    assign insn_o = imem[(pc_q - BASE_ADDR) >> 2];

    // Second read port: data-bus access to instruction ROM
    assign rom_drdata_o = imem[(rom_daddr_i - BASE_ADDR) >> 2];

    // Data-bus write port — allows stores to the ROM region (ISA tests
    // store data into the same address space as code).
    logic [$clog2(DEPTH)-1:0] wr_idx;
    logic [1:0]               wr_boff;
    assign wr_idx  = (rom_daddr_i - BASE_ADDR) >> 2;
    assign wr_boff = rom_daddr_i[1:0];

    always_ff @(posedge clk) begin
        if (rom_dwen_i) begin
            case (rom_dfunct3_i[1:0])
                2'b00:   imem[wr_idx][wr_boff*8 +: 8]      <= rom_dwdata_i[7:0];    // SB
                2'b01:   imem[wr_idx][wr_boff[1]*16 +: 16] <= rom_dwdata_i[15:0];   // SH
                default: imem[wr_idx]                       <= rom_dwdata_i;          // SW
            endcase
        end
    end

endmodule : fetch
