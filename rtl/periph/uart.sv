// UART peripheral
//
// Register map:
//   +0x0  TX_DATA  (write: send byte)
//   +0x4  STATUS   (read: bit 0 = tx_ready)
//   +0x8  RX_DATA  (read: always zero in this TX-only build)
//
// TX shift register only (115200 8N1).
// In simulation, TX also prints via $write for convenience.

module uart #(
    parameter int CLK_FREQ = 25_000_000,
    parameter int BAUD     = 115_200
)(
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        wen_i,
    input  logic        ren_i,
    output logic [31:0] rdata_o,
    output logic        tx_o,       // serial TX line (idle high)
    input  logic        rx_i        // unused in this build
);

    localparam ADDR_TX_DATA = 4'h0;  // offset +0
    localparam ADDR_STATUS  = 4'h4;  // offset +4
    localparam ADDR_RX_DATA = 4'h8;  // offset +8
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD;  // 217 @ 25 MHz/115200

    logic [3:0] offset;
    assign offset = addr_i[3:0];

    // ── TX shift register ─────────────────────────────────
    logic tx_valid;
    logic tx_ready;

    assign tx_valid = wen_i && (offset == ADDR_TX_DATA);

    typedef enum logic [1:0] {
        TX_IDLE  = 2'b00,
        TX_START = 2'b01,
        TX_DATA  = 2'b10,
        TX_STOP  = 2'b11
    } tx_state_t;

    tx_state_t tx_state_q;

    logic [8:0]  tx_baud_cnt;
    logic [2:0]  tx_bit_idx;
    logic [7:0]  tx_shift_q;
    logic        tx_q;

    assign tx_ready = (tx_state_q == TX_IDLE);
    assign tx_o     = tx_q;

    always_ff @(posedge clk) begin
        if (rst) begin
            tx_state_q  <= TX_IDLE;
            tx_baud_cnt <= '0;
            tx_bit_idx  <= '0;
            tx_shift_q  <= '0;
            tx_q        <= 1'b1;
        end else begin
            case (tx_state_q)
                TX_IDLE: begin
                    tx_q        <= 1'b1;
                    tx_baud_cnt <= '0;
                    tx_bit_idx  <= '0;
                    if (tx_valid) begin
                        tx_shift_q <= wdata_i[7:0];
                        tx_state_q <= TX_START;
                    end
                end
                TX_START: begin
                    tx_q <= 1'b0;
                    if (tx_baud_cnt == 9'(CLKS_PER_BIT - 1)) begin
                        tx_baud_cnt <= '0;
                        tx_state_q  <= TX_DATA;
                    end else begin
                        tx_baud_cnt <= tx_baud_cnt + 9'd1;
                    end
                end
                TX_DATA: begin
                    tx_q <= tx_shift_q[0];
                    if (tx_baud_cnt == 9'(CLKS_PER_BIT - 1)) begin
                        tx_baud_cnt <= '0;
                        tx_shift_q  <= {1'b0, tx_shift_q[7:1]};
                        if (tx_bit_idx == 3'd7)
                            tx_state_q <= TX_STOP;
                        else
                            tx_bit_idx <= tx_bit_idx + 3'd1;
                    end else begin
                        tx_baud_cnt <= tx_baud_cnt + 9'd1;
                    end
                end
                TX_STOP: begin
                    tx_q <= 1'b1;
                    if (tx_baud_cnt == 9'(CLKS_PER_BIT - 1)) begin
                        tx_baud_cnt <= '0;
                        tx_state_q  <= TX_IDLE;
                    end else begin
                        tx_baud_cnt <= tx_baud_cnt + 9'd1;
                    end
                end
                default: tx_state_q <= TX_IDLE;
            endcase
        end
    end

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
            ADDR_STATUS:  rdata_o = {31'b0, tx_ready};
            ADDR_RX_DATA: rdata_o = 32'h0;
            default:      rdata_o = 32'h0;
        endcase
    end

endmodule : uart
