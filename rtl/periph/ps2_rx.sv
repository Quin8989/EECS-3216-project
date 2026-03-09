// PS/2 receiver — deserializes PS/2 clock + data into 8-bit scancodes
//
// PS/2 protocol (device → host):
//   1 start bit (0), 8 data bits (LSB first), 1 parity bit (odd), 1 stop bit (1)
//   PS/2 clock is driven by the device at 10–16.7 kHz.
//   Data is valid on the FALLING edge of ps2_clk.
//
// This module:
//   - Synchronises ps2_clk and ps2_data to the system clock
//   - Detects falling edges of ps2_clk
//   - Shifts in 11 bits (start + 8 data + parity + stop)
//   - Outputs code_o[7:0] with a one-cycle valid_o pulse
//
// For simulation, valid_o / code_o can be driven externally via a test stub.

module ps2_rx (
    input  logic       clk,
    input  logic       rst,
    input  logic       ps2_clk_i,
    input  logic       ps2_data_i,
    output logic [7:0] code_o,
    output logic       valid_o
);

    // ── Synchronise PS/2 signals (2-FF) ───────────
    logic [2:0] clk_sync;
    logic [1:0] data_sync;

    always_ff @(posedge clk) begin
        if (rst) begin
            clk_sync  <= 3'b111;
            data_sync <= 2'b11;
        end else begin
            clk_sync  <= {clk_sync[1:0], ps2_clk_i};
            data_sync <= {data_sync[0], ps2_data_i};
        end
    end

    // Falling edge of PS/2 clock: was high, now low
    logic ps2_clk_fall;
    assign ps2_clk_fall = clk_sync[2] & ~clk_sync[1];

    logic ps2_data;
    assign ps2_data = data_sync[1];

    // ── Shift register ────────────────────────────
    logic [10:0] shift_reg;   // start + 8 data + parity + stop
    logic [3:0]  bit_cnt;     // 0..10

    // Watchdog: if no falling edge for ~2 ms (100k clocks @ 50 MHz),
    // reset the receiver to handle glitches / partial frames.
    logic [16:0] watchdog;

    always_ff @(posedge clk) begin
        if (rst) begin
            shift_reg <= '0;
            bit_cnt   <= '0;
            valid_o   <= 1'b0;
            code_o    <= '0;
            watchdog  <= '0;
        end else begin
            valid_o <= 1'b0;  // default: one-cycle pulse

            if (ps2_clk_fall) begin
                watchdog  <= '0;
                shift_reg <= {ps2_data, shift_reg[10:1]};  // shift in from MSB
                bit_cnt   <= bit_cnt + 1;

                if (bit_cnt == 4'd10) begin
                    // All 11 bits received
                    // shift_reg[0] = start (should be 0)
                    // shift_reg[8:1] = data
                    // shift_reg[9] = parity
                    // shift_reg[10] = stop (should be 1)
                    code_o  <= shift_reg[8:1];
                    valid_o <= 1'b1;
                    bit_cnt <= '0;
                end
            end else begin
                // Watchdog timeout → reset frame
                if (bit_cnt != 0) begin
                    watchdog <= watchdog + 1;
                    if (watchdog[16]) begin
                        bit_cnt <= '0;
                    end
                end
            end
        end
    end

endmodule : ps2_rx
