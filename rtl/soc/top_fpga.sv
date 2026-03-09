// FPGA top-level wrapper for Intel DE10-Lite (10M50DAF484C7G)
//
// Maps DE10-Lite board pins to the SoC top module.
//   - 50 MHz board clock → system clock
//   - KEY[0] (active-low) → synchronised reset
//   - VGA DAC (4-bit RGB, HSYNC, VSYNC)
//   - LEDR[9:0] accent LEDs (active-high) for debug
//   - GPIO[0] reserved for UART TX (active when real TX is added)

module top_fpga (
    // ── Clock ──────────────────────────────────────
    input  logic        MAX10_CLK1_50,

    // ── Push-buttons (active low) ─────────────────
    input  logic [1:0]  KEY,

    // ── Slide switches ────────────────────────────
    input  logic [9:0]  SW,

    // ── LEDs (active high) ────────────────────────
    output logic [9:0]  LEDR,

    // ── VGA ───────────────────────────────────────
    output logic [3:0]  VGA_R,
    output logic [3:0]  VGA_G,
    output logic [3:0]  VGA_B,
    output logic        VGA_HS,
    output logic        VGA_VS,

    // ── GPIO header ──────────────────────────────────
    output logic [0:0]  GPIO   // GPIO[0] = UART TX
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
    top u_soc (
        .clk       (MAX10_CLK1_50),
        .reset     (reset),
        .vga_r     (VGA_R),
        .vga_g     (VGA_G),
        .vga_b     (VGA_B),
        .vga_hsync (VGA_HS),
        .vga_vsync (VGA_VS)
    );

    // ── Debug LEDs ────────────────────────────────
    // LEDR[0]: heartbeat (≈ 1.5 Hz from MSB of a counter)
    logic [24:0] hb_cnt;
    always_ff @(posedge MAX10_CLK1_50) begin
        if (reset) hb_cnt <= '0;
        else       hb_cnt <= hb_cnt + 1;
    end
    assign LEDR[0] = hb_cnt[24];

    // LEDR[1]: reset active indicator
    assign LEDR[1] = reset;

    // LEDR[9:2]: unused — tie off
    assign LEDR[9:2] = '0;

    // ── GPIO: UART TX placeholder ─────────────────
    // Will be driven by a real uart_tx module later.
    assign GPIO[0] = 1'b1;  // idle-high (UART idle state)

endmodule : top_fpga
