// FPGA top-level wrapper for Intel DE10-Lite (10M50DAF484C7G)
//
// Maps DE10-Lite board pins to the SoC top module.
//   - 50 MHz board clock → system clock
//   - KEY[0] (active-low) → synchronised reset
//   - VGA DAC (4-bit RGB, HSYNC, VSYNC)
//   - LEDR[9:0] accent LEDs (active-high) for debug
//   - GPIO[0] = UART TX, UART_RX = serial input

module top_fpga (
    // ── Clock ──────────────────────────────────────
    input  logic        MAX10_CLK1_50,

    // ── Push-button (active low) ──────────────────
    input  logic [0:0]  KEY,

    // ── LEDs (active high) ────────────────────────
    output logic [9:0]  LEDR,

    // ── VGA ───────────────────────────────────────
    output logic [3:0]  VGA_R,
    output logic [3:0]  VGA_G,
    output logic [3:0]  VGA_B,
    output logic        VGA_HS,
    output logic        VGA_VS,

    // ── GPIO header ──────────────────────────────────
    output logic [0:0]  GPIO,  // GPIO[0] = UART TX

    // ── UART RX ──────────────────────────────────────
    input  logic        UART_RX,

    // ── PS/2 keyboard (directly on FPGA pads) ─────────
    input  logic        PS2_CLK,
    input  logic        PS2_DAT
);

    // ── Reset synchroniser (2-FF, active-high) ────
    logic rst_raw;
    assign rst_raw = ~KEY[0];           // KEY[0] pressed → reset

    logic [1:0] rst_sync;
    always_ff @(posedge MAX10_CLK1_50) begin
        rst_sync <= {rst_sync[0], rst_raw};
    end

    logic reset;
    assign reset = rst_sync[1];

    // ── SoC ───────────────────────────────────────
    logic uart_tx_w;

    top u_soc (
        .clk       (MAX10_CLK1_50),
        .reset     (reset),
        .vga_r     (VGA_R),
        .vga_g     (VGA_G),
        .vga_b     (VGA_B),
        .vga_hsync (VGA_HS),
        .vga_vsync (VGA_VS),
        .uart_tx_o (uart_tx_w),
        .uart_rx_i (UART_RX),
        .ps2_clk_i (PS2_CLK),
        .ps2_data_i(PS2_DAT)
    );

    // ── Debug LEDs ────────────────────────────────
    // LEDR[0]: heartbeat (≈ 1.5 Hz from MSB of a counter)
    logic [24:0] hb_cnt;
    always_ff @(posedge MAX10_CLK1_50) begin
        if (reset) hb_cnt <= '0;
        else       hb_cnt <= hb_cnt + 25'd1;
    end
    assign LEDR[0] = hb_cnt[24];

    // LEDR[1]: reset active indicator
    assign LEDR[1] = reset;

    // LEDR[9:2]: unused — tie off
    assign LEDR[9:2] = '0;

    // ── GPIO: UART TX ────────────────────────────
    assign GPIO[0] = uart_tx_w;

endmodule : top_fpga
