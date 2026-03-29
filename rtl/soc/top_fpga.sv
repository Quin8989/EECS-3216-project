// FPGA top-level wrapper for Intel DE10-Lite (10M50DAF484C7G)
//
// Maps board pins to the SoC.  SDRAM is unused — pins driven to safe
// idle values so the physical chip doesn't draw spurious current.
//
//   - 50 MHz board oscillator → 25 MHz system clock (divide-by-2)
//   - KEY[0] (active-low) → synchronised reset
//   - LEDR[0] heartbeat, LEDR[1] reset indicator
//   - GPIO[0] = UART TX

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

    // ── SDRAM (directly to IS42S16320D on DE10-Lite) ──
    // Not used — pins driven to safe idle values.
    output logic [12:0] DRAM_ADDR,
    output logic [1:0]  DRAM_BA,
    inout  wire  [15:0] DRAM_DQ,
    output logic        DRAM_CKE,
    output logic        DRAM_CLK,
    output logic        DRAM_CS_N,
    output logic        DRAM_RAS_N,
    output logic        DRAM_CAS_N,
    output logic        DRAM_WE_N,
    output logic        DRAM_UDQM,
    output logic        DRAM_LDQM
);

    // ── 25 MHz system clock (divide-by-2 from 50 MHz) ────
    logic clk_25m = 1'b0;
    always_ff @(posedge MAX10_CLK1_50)
        clk_25m <= ~clk_25m;

    // ── Power-on reset: hold CPU in reset for 256 cycles after config ────
    logic [7:0] por_cnt = 8'd0;  // Initialized to 0 on config
    logic       por_done;
    always_ff @(posedge clk_25m) begin
        if (!por_done)
            por_cnt <= por_cnt + 1'b1;
    end
    assign por_done = (por_cnt == 8'hFF);

    // ── Reset synchroniser (2-FF on 25 MHz domain) ────
    logic [1:0] rst_sync;
    always_ff @(posedge clk_25m)
        rst_sync <= {rst_sync[0], ~KEY[0]};

    logic reset;
    logic jtag_soft_reset;
    assign reset = rst_sync[1] | jtag_soft_reset | ~por_done;

    // ── SoC signals ───────────────────────────────
    logic        uart_tx_w;
    logic [31:0] dbg_pc;

    // ── JTAG master ──────────────────────────────────
    logic [31:0] jtag_master_addr, jtag_master_rdata, jtag_master_wdata;
    logic        jtag_master_read, jtag_master_write;
    logic        jtag_master_waitrequest, jtag_master_readdatavalid;
    logic [3:0]  jtag_master_byteenable;

    jtag_master u_jtag_master (
        .clk_clk              (clk_25m),
        .reset_reset_n        (~rst_sync[1]),
        .master_address       (jtag_master_addr),
        .master_readdata      (jtag_master_rdata),
        .master_read          (jtag_master_read),
        .master_write         (jtag_master_write),
        .master_writedata     (jtag_master_wdata),
        .master_waitrequest   (jtag_master_waitrequest),
        .master_readdatavalid (jtag_master_readdatavalid),
        .master_byteenable    (jtag_master_byteenable)
    );

    // ── JTAG special-address intercept ───────────────
    // Only keyboard injection and soft-reset are supported.
    // All other JTAG accesses complete immediately as no-ops.
    localparam logic [31:0] JTAG_KBD_ADDR       = 32'h4FFF_FF00;
    localparam logic [31:0] JTAG_SOFT_RESET_ADDR = 32'h4FFF_FF10;

    wire jtag_kbd_hit   = jtag_master_write && (jtag_master_addr == JTAG_KBD_ADDR);
    wire jtag_reset_hit = jtag_master_write && (jtag_master_addr == JTAG_SOFT_RESET_ADDR);

    logic       jtag_kbd_valid;
    logic [7:0] jtag_kbd_code;

    always_ff @(posedge clk_25m) begin
        if (rst_sync[1]) begin
            jtag_kbd_valid  <= 1'b0;
            jtag_kbd_code   <= 8'h00;
            jtag_soft_reset <= 1'b0;
        end else begin
            jtag_kbd_valid <= 1'b0;
            if (jtag_kbd_hit) begin
                jtag_kbd_valid <= 1'b1;
                jtag_kbd_code  <= jtag_master_wdata[7:0];
            end
            if (jtag_reset_hit)
                jtag_soft_reset <= jtag_master_wdata[0];
        end
    end

    // Complete every JTAG transaction in one cycle (no wait)
    assign jtag_master_waitrequest   = 1'b0;
    assign jtag_master_readdatavalid = jtag_master_read;
    assign jtag_master_rdata         = 32'd0;

    // ── SoC instantiation ─────────────────────────────
    top u_soc (
        .clk              (clk_25m),
        .reset            (reset),
        .vga_r            (VGA_R),
        .vga_g            (VGA_G),
        .vga_b            (VGA_B),
        .vga_hsync        (VGA_HS),
        .vga_vsync        (VGA_VS),
        .vga_blanking_o   (),
        .uart_tx_o        (uart_tx_w),
        .uart_rx_i        (1'b1),
        .jtag_kbd_valid_i (jtag_kbd_valid),
        .jtag_kbd_code_i  (jtag_kbd_code),
        .dbg_pc_o         (dbg_pc)
    );

    // ── Debug LEDs ────────────────────────────────────
    logic [24:0] hb_cnt;
    always_ff @(posedge clk_25m)
        if (reset) hb_cnt <= '0;
        else       hb_cnt <= hb_cnt + 25'd1;

    assign LEDR[0]   = hb_cnt[24];   // Heartbeat (~0.75 Hz)
    assign LEDR[1]   = reset;
    assign LEDR[9:2] = '0;

    // ── GPIO: UART TX ────────────────────────────────
    assign GPIO[0] = uart_tx_w;

    // ── SDRAM pins — idle / safe values ──────────────
    assign DRAM_CLK   = 1'b0;
    assign DRAM_CKE   = 1'b0;
    assign DRAM_CS_N  = 1'b1;   // deselected
    assign DRAM_RAS_N = 1'b1;
    assign DRAM_CAS_N = 1'b1;
    assign DRAM_WE_N  = 1'b1;
    assign DRAM_ADDR  = 13'd0;
    assign DRAM_BA    = 2'd0;
    assign DRAM_UDQM  = 1'b1;
    assign DRAM_LDQM  = 1'b1;
    assign DRAM_DQ    = 16'bz;  // tri-state

endmodule : top_fpga
