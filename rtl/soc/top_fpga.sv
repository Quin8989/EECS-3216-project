// FPGA top-level wrapper for Intel DE10-Lite (10M50DAF484C7G)
//
// Maps DE10-Lite board pins to the headless SoC top module.
//   - 50 MHz board oscillator → 25 MHz system clock (divide-by-2)
//   - KEY[0] (active-low) → synchronised reset
//   - LEDR[9:0] accent LEDs (active-high) for debug
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

    // ── Reset synchroniser (2-FF, active-high) ────
    logic rst_raw;
    assign rst_raw = ~KEY[0];           // KEY[0] pressed → reset

    // ── 25 MHz system clock (divide-by-2 from 50 MHz) ────
    // Free-running divider — no reset, avoids runt clock pulses.
    // MAX 10 initialises registers to 0 after configuration.
    logic clk_25m = 1'b0;
    always_ff @(posedge MAX10_CLK1_50)
        clk_25m <= ~clk_25m;

    // ── Reset synchroniser (2-FF on 25 MHz domain) ────
    logic [1:0] rst_sync;
    always_ff @(posedge clk_25m) begin
        rst_sync <= {rst_sync[0], rst_raw};
    end

    logic reset;
    assign reset = rst_sync[1];

    // ── SoC ───────────────────────────────────────
    logic uart_tx_w;
    logic [31:0] dbg_pc;
    logic        dbg_vga_wr;

    // ── SDRAM bus signals (from SoC/CPU) ──────────
    logic [23:0] cpu_sdram_addr;
    logic [31:0] cpu_sdram_wdata, sdram_q;
    logic        cpu_sdram_we, cpu_sdram_req, cpu_sdram_ack, sdram_valid;
    logic [23:0] vga_sdram_addr;
    logic        vga_sdram_req, vga_sdram_ack, vga_sdram_valid;
    logic        cpu_sdram_valid;

    // ── JTAG master (Intel IP) signals ──────────────
    logic [31:0] jtag_master_addr;
    logic [31:0] jtag_master_rdata;
    logic [31:0] jtag_master_wdata;
    logic        jtag_master_read;
    logic        jtag_master_write;
    logic        jtag_master_waitrequest;
    logic        jtag_master_readdatavalid;
    logic [3:0]  jtag_master_byteenable;

    // ── Arbitrated SDRAM bus ──────────────────────
    logic [23:0] sdram_addr;
    logic [31:0] sdram_wdata;
    logic        sdram_we, sdram_req, sdram_ack;
    typedef enum logic [1:0] {RESP_NONE, RESP_CPU, RESP_VGA, RESP_JTAG} resp_t;
    resp_t read_resp_target;
    logic grant_cpu, grant_vga, grant_jtag, grant_jtag_sdram;

    localparam logic [31:0] JTAG_KBD_INJECT_ADDR = 32'h4FFF_FF00;
    logic       jtag_kbd_inject_hit;
    logic       jtag_kbd_valid;
    logic [7:0] jtag_kbd_code;

    // Intel JTAG-to-Avalon Master IP
    jtag_master u_jtag_master (
        .clk_clk              (clk_25m),
        .reset_reset_n        (~reset),
        .master_address       (jtag_master_addr),
        .master_readdata      (jtag_master_rdata),
        .master_read          (jtag_master_read),
        .master_write         (jtag_master_write),
        .master_writedata     (jtag_master_wdata),
        .master_waitrequest   (jtag_master_waitrequest),
        .master_readdatavalid (jtag_master_readdatavalid),
        .master_byteenable    (jtag_master_byteenable)
    );

    // ── SDRAM Arbitration ─────────────────────────
    // Priority: JTAG > CPU > VGA. Only one read response may be outstanding.
    // A reserved JTAG write address injects keyboard scan codes directly.
    assign jtag_kbd_inject_hit = (read_resp_target == RESP_NONE)
                              && jtag_master_write
                              && (jtag_master_addr == JTAG_KBD_INJECT_ADDR);
    assign grant_jtag_sdram = (read_resp_target == RESP_NONE)
                           && (jtag_master_read | jtag_master_write)
                           && !jtag_kbd_inject_hit;
    assign grant_jtag = grant_jtag_sdram | jtag_kbd_inject_hit;
    assign grant_cpu  = (read_resp_target == RESP_NONE) && !grant_jtag && cpu_sdram_req;
    assign grant_vga  = (read_resp_target == RESP_NONE) && !grant_jtag && !grant_cpu && vga_sdram_req;

    assign cpu_sdram_ack = grant_cpu & sdram_ack;
    assign vga_sdram_ack = grant_vga & sdram_ack;
    assign jtag_master_waitrequest = (jtag_master_read | jtag_master_write)
                                  && !((grant_jtag_sdram && sdram_ack) || jtag_kbd_inject_hit);
    assign jtag_master_readdatavalid = sdram_valid & (read_resp_target == RESP_JTAG);
    assign jtag_master_rdata = sdram_q;
    assign cpu_sdram_valid = sdram_valid & (read_resp_target == RESP_CPU);
    assign vga_sdram_valid = sdram_valid & (read_resp_target == RESP_VGA);

    always_ff @(posedge clk_25m) begin
        if (reset) begin
            jtag_kbd_valid <= 1'b0;
            jtag_kbd_code  <= 8'h00;
        end else begin
            jtag_kbd_valid <= 1'b0;
            if (jtag_kbd_inject_hit) begin
                jtag_kbd_valid <= 1'b1;
                jtag_kbd_code  <= jtag_master_wdata[7:0];
            end
        end
    end

    always_comb begin
        sdram_addr  = 24'd0;
        sdram_wdata = 32'd0;
        sdram_we    = 1'b0;
        sdram_req   = 1'b0;

        if (grant_jtag_sdram) begin
            sdram_addr  = jtag_master_addr[25:2];
            sdram_wdata = jtag_master_wdata;
            sdram_we    = jtag_master_write;
            sdram_req   = 1'b1;
        end else if (grant_cpu) begin
            sdram_addr  = cpu_sdram_addr;
            sdram_wdata = cpu_sdram_wdata;
            sdram_we    = cpu_sdram_we;
            sdram_req   = cpu_sdram_req;
        end else if (grant_vga) begin
            sdram_addr  = vga_sdram_addr;
            sdram_wdata = 32'd0;
            sdram_we    = 1'b0;
            sdram_req   = vga_sdram_req;
        end
    end

    always_ff @(posedge clk_25m) begin
        if (reset) begin
            read_resp_target <= RESP_NONE;
        end else begin
            if (read_resp_target == RESP_NONE) begin
                if (grant_jtag_sdram && sdram_ack && !jtag_master_write)
                    read_resp_target <= RESP_JTAG;
                else if (grant_cpu && sdram_ack && !cpu_sdram_we)
                    read_resp_target <= RESP_CPU;
                else if (grant_vga && sdram_ack)
                    read_resp_target <= RESP_VGA;
            end else if (sdram_valid) begin
                read_resp_target <= RESP_NONE;
            end
        end
    end

    top u_soc (
        .clk          (clk_25m),
        .reset        (reset),
        .vga_r        (VGA_R),
        .vga_g        (VGA_G),
        .vga_b        (VGA_B),
        .vga_hsync    (VGA_HS),
        .vga_vsync    (VGA_VS),
        .uart_tx_o    (uart_tx_w),
        .uart_rx_i    (1'b1),
        .jtag_kbd_valid_i(jtag_kbd_valid),
        .jtag_kbd_code_i (jtag_kbd_code),
        .sdram_addr_o (cpu_sdram_addr),
        .sdram_wdata_o(cpu_sdram_wdata),
        .sdram_we_o   (cpu_sdram_we),
        .sdram_req_o  (cpu_sdram_req),
        .sdram_ack_i  (cpu_sdram_ack),
        .sdram_valid_i(cpu_sdram_valid),
        .vga_sdram_addr_o(vga_sdram_addr),
        .vga_sdram_req_o (vga_sdram_req),
        .vga_sdram_ack_i (vga_sdram_ack),
        .vga_sdram_valid_i(vga_sdram_valid),
        .sdram_q_i     (sdram_q),
        .vga_sdram_q_i (sdram_q),
        .dbg_pc_o     (dbg_pc),
        .dbg_vga_wr_o (dbg_vga_wr)
    );

    // ── Debug LEDs ────────────────────────────────
    // LEDR[0]: heartbeat (≈ 0.75 Hz from MSB of a counter at 25 MHz)
    logic [24:0] hb_cnt;
    always_ff @(posedge clk_25m) begin
        if (reset) hb_cnt <= '0;
        else       hb_cnt <= hb_cnt + 25'd1;
    end
    assign LEDR[0] = hb_cnt[24];

    // LEDR[1]: reset active indicator
    assign LEDR[1] = reset;

    // LEDR[2]: VGA write ever occurred
    assign LEDR[2] = dbg_vga_wr;

    // LEDR[3]: PC has left reset address (CPU is running)
    assign LEDR[3] = (dbg_pc != 32'h0100_0000);

    // LEDR[9:4]: PC bits [7:2] (instruction offset, changes as CPU executes)
    assign LEDR[9:4] = dbg_pc[7:2];

    // ── GPIO: UART TX ────────────────────────────
    assign GPIO[0] = uart_tx_w;

    // ── SDRAM controller & clock ──────────────────
    // The SDRAM core expects the external DRAM clock to be the inverted phase
    // of the internal 25 MHz controller clock.
    assign DRAM_CLK = ~clk_25m;

    sdram_ctrl u_sdram_ctrl (
        .reset      (reset),
        .clk        (clk_25m),
        .addr       (sdram_addr),
        .data       (sdram_wdata),
        .we         (sdram_we),
        .req        (sdram_req),
        .ack        (sdram_ack),
        .valid      (sdram_valid),
        .q          (sdram_q),
        .sdram_a    (DRAM_ADDR),
        .sdram_ba   (DRAM_BA),
        .sdram_dq   (DRAM_DQ),
        .sdram_cke  (DRAM_CKE),
        .sdram_cs_n (DRAM_CS_N),
        .sdram_ras_n(DRAM_RAS_N),
        .sdram_cas_n(DRAM_CAS_N),
        .sdram_we_n (DRAM_WE_N),
        .sdram_dqml (DRAM_LDQM),
        .sdram_dqmh (DRAM_UDQM)
    );

endmodule : top_fpga
