// UART TX shift register — 115200 baud, 8N1
//
// Clocked at CLK_FREQ (default 50 MHz).
// Transmits one byte per valid_i pulse.
//
// Protocol: 1 start bit (0), 8 data bits (LSB first), 1 stop bit (1).
//
// Handshake:
//   valid_i  — pulse high for one clock when data_i is valid
//   ready_o  — high when idle and able to accept a new byte
//   tx_o     — serial output (idle high)

module uart_tx #(
    parameter int CLK_FREQ = 50_000_000,
    parameter int BAUD     = 115_200
)(
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] data_i,
    input  logic       valid_i,
    output logic       ready_o,
    output logic       tx_o
);

    // Baud divider: number of clock ticks per bit
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD;  // 434 @ 50 MHz/115200

    // State
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;

    state_t state_q, state_d;

    logic [8:0]  baud_cnt;    // counts 0 .. CLKS_PER_BIT-1
    logic [2:0]  bit_idx;     // 0..7 data bits
    logic [7:0]  shift_q;     // TX shift register
    logic        tx_q;

    assign ready_o = (state_q == IDLE);
    assign tx_o    = tx_q;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_q  <= IDLE;
            baud_cnt <= '0;
            bit_idx  <= '0;
            shift_q  <= '0;
            tx_q     <= 1'b1;  // idle high
        end else begin
            case (state_q)
                // ── IDLE: wait for valid ──────────────────
                IDLE: begin
                    tx_q     <= 1'b1;
                    baud_cnt <= '0;
                    bit_idx  <= '0;
                    if (valid_i) begin
                        shift_q <= data_i;
                        state_q <= START;
                    end
                end

                // ── START bit (low) ──────────────────────
                START: begin
                    tx_q <= 1'b0;
                    if (baud_cnt == CLKS_PER_BIT - 1) begin
                        baud_cnt <= '0;
                        state_q  <= DATA;
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                // ── DATA bits (LSB first) ────────────────
                DATA: begin
                    tx_q <= shift_q[0];
                    if (baud_cnt == CLKS_PER_BIT - 1) begin
                        baud_cnt <= '0;
                        shift_q  <= {1'b0, shift_q[7:1]};
                        if (bit_idx == 3'd7) begin
                            state_q <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                // ── STOP bit (high) ──────────────────────
                STOP: begin
                    tx_q <= 1'b1;
                    if (baud_cnt == CLKS_PER_BIT - 1) begin
                        baud_cnt <= '0;
                        state_q  <= IDLE;
                    end else begin
                        baud_cnt <= baud_cnt + 1;
                    end
                end

                default: state_q <= IDLE;
            endcase
        end
    end

endmodule : uart_tx
