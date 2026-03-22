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
    input  logic              stall_i,
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
        else if (!stall_i) begin
            if (brtaken_i)
                pc_q <= next_pc_i;
            else
                pc_q <= pc_q + 32'd4;
        end
    end

    // ── Four byte-wide banks for block-RAM inference ──
    localparam int ABITS = $clog2(DEPTH);

    (* ramstyle = "no_rw_check" *)  logic [7:0] bank0 [0:DEPTH-1];
    (* ramstyle = "no_rw_check" *)  logic [7:0] bank1 [0:DEPTH-1];
    (* ramstyle = "no_rw_check" *)  logic [7:0] bank2 [0:DEPTH-1];
    (* ramstyle = "no_rw_check" *)  logic [7:0] bank3 [0:DEPTH-1];

    // Initialise banks from a single 32-bit hex file
    integer i;
    logic [31:0] imem_init [0:DEPTH-1];
    initial begin
        $readmemh(`MEM_PATH, imem_init);
        for (i = 0; i < DEPTH; i = i + 1) begin
            bank0[i] = imem_init[i][ 7: 0];
            bank1[i] = imem_init[i][15: 8];
            bank2[i] = imem_init[i][23:16];
            bank3[i] = imem_init[i][31:24];
        end
    end

    // ── Instruction read (port A) — synchronous pre-fetch ──
    // Address for NEXT cycle's instruction, computed combinationally
    logic [ABITS-1:0] pc_idx;
    assign pc_idx = ABITS'((pc_q - BASE_ADDR) >> 2);

    logic [ABITS-1:0] ifetch_addr;
    always_comb begin
        if (stall_i || rst)
            ifetch_addr = pc_idx;       // Re-fetch current / first instruction
        else if (brtaken_i)
            ifetch_addr = ABITS'((next_pc_i - BASE_ADDR) >> 2);
        else
            ifetch_addr = pc_idx + ABITS'(1);   // Sequential next
    end

    always_ff @(posedge clk) begin
        insn_o <= {bank3[ifetch_addr], bank2[ifetch_addr],
                   bank1[ifetch_addr], bank0[ifetch_addr]};
    end

    // ── Data-bus read (port B) — synchronous ──
    logic [ABITS-1:0] d_idx;
    assign d_idx = ABITS'((rom_daddr_i - BASE_ADDR) >> 2);

    always_ff @(posedge clk) begin
        rom_drdata_o <= {bank3[d_idx], bank2[d_idx],
                         bank1[d_idx], bank0[d_idx]};
    end

    // ── Data-bus write with byte-enables ──
    logic [ABITS-1:0] wr_idx;
    logic [1:0]       wr_boff;
    logic [3:0]       be;

    assign wr_idx  = ABITS'((rom_daddr_i - BASE_ADDR) >> 2);
    assign wr_boff = rom_daddr_i[1:0];

    always_comb begin
        be = 4'b0000;
        case (rom_dfunct3_i[1:0])
            2'b00:   be[wr_boff] = 1'b1;                                // SB
            2'b01:   begin be[wr_boff] = 1'b1; be[wr_boff | 1] = 1'b1; end // SH
            default: be = 4'b1111;                                       // SW
        endcase
    end

    // Write-data routing (same pattern as ram.sv)
    logic [7:0] wd0, wd1, wd2, wd3;
    always_comb begin
        wd0 = rom_dwdata_i[ 7: 0];
        wd1 = rom_dwdata_i[15: 8];
        wd2 = rom_dwdata_i[23:16];
        wd3 = rom_dwdata_i[31:24];
        case (rom_dfunct3_i[1:0])
            2'b00: begin wd0 = rom_dwdata_i[7:0]; wd1 = rom_dwdata_i[7:0];
                         wd2 = rom_dwdata_i[7:0]; wd3 = rom_dwdata_i[7:0]; end
            2'b01: begin wd0 = rom_dwdata_i[7:0]; wd1 = rom_dwdata_i[15:8];
                         wd2 = rom_dwdata_i[7:0]; wd3 = rom_dwdata_i[15:8]; end
            default: ;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rom_dwen_i) begin
            if (be[0]) bank0[wr_idx] <= wd0;
            if (be[1]) bank1[wr_idx] <= wd1;
            if (be[2]) bank2[wr_idx] <= wd2;
            if (be[3]) bank3[wr_idx] <= wd3;
        end
    end

endmodule : fetch
