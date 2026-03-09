// UART peripheral
//
// Register map:
//   +0x0  TX_DATA  (write: send byte)
//   +0x4  STATUS   (read: bit 0 = tx_ready)
//
// Contains a real uart_tx shift register for FPGA (115200 8N1).
// In simulation, also prints via $write for convenience.

module uart (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        wen_i,
    input  logic        ren_i,
    output logic [31:0] rdata_o,
    output logic        tx_o        // serial TX line (idle high)
);

    localparam ADDR_TX_DATA = 3'h0;  // offset +0
    localparam ADDR_STATUS  = 3'h4;  // offset +4

    logic [2:0] offset;
    assign offset = addr_i[2:0];

    // ── TX shift register ─────────────────────────────────
    logic tx_valid;
    logic tx_ready;

    assign tx_valid = wen_i && (offset == ADDR_TX_DATA);

    uart_tx u_tx (
        .clk     (clk),
        .rst     (rst),
        .data_i  (wdata_i[7:0]),
        .valid_i (tx_valid),
        .ready_o (tx_ready),
        .tx_o    (tx_o)
    );

    // ── Sim: also print via $write ────────────────────────
    // synthesis translate_off
    always_ff @(posedge clk) begin
        if (!rst && tx_valid)
            $write("%c", wdata_i[7:0]);
    end
    // synthesis translate_on

    // ── Read mux ──────────────────────────────────────────
    always_comb begin
        case (offset)
            ADDR_STATUS: rdata_o = {30'b0, 1'b0, tx_ready};  // bit0=tx_ready
            default:     rdata_o = 32'h0;
        endcase
    end

endmodule : uart
