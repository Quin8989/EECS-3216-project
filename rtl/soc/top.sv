`include "constants.svh"

module top (
    input  logic       clk,
    input  logic       reset,
    // VGA outputs
    output logic [3:0] vga_r,
    output logic [3:0] vga_g,
    output logic [3:0] vga_b,
    output logic       vga_hsync,
    output logic       vga_vsync,
    // UART
    output logic       uart_tx_o,
    // PS/2 keyboard
    input  logic       ps2_clk_i,
    input  logic       ps2_data_i
);

    // CPU data bus
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic        dmem_wen, dmem_ren;
    logic [2:0]  dmem_funct3;

    cpu u_cpu (
        .clk           (clk),
        .reset         (reset),
        .dmem_addr_o   (dmem_addr),
        .dmem_wdata_o  (dmem_wdata),
        .dmem_rdata_i  (dmem_rdata),
        .dmem_wen_o    (dmem_wen),
        .dmem_ren_o    (dmem_ren),
        .dmem_funct3_o (dmem_funct3)
    );

    // Device buses
    logic [31:0] ram_addr,   ram_wdata,   ram_rdata;
    logic        ram_wen,    ram_ren;
    logic [2:0]  ram_funct3;

    logic [31:0] uart_addr,  uart_wdata,  uart_rdata;
    logic        uart_wen,   uart_ren;

    logic [31:0] timer_addr, timer_wdata, timer_rdata;
    logic        timer_wen,  timer_ren;

    logic [31:0] vga_addr,   vga_wdata,   vga_rdata;
    logic        vga_wen,    vga_ren;

    logic [31:0] kbd_addr,   kbd_wdata,   kbd_rdata;
    logic        kbd_wen,    kbd_ren;

    // Memory map
    mem_map u_mem_map (
        .addr_i     (dmem_addr),
        .wdata_i    (dmem_wdata),
        .wen_i      (dmem_wen),
        .ren_i      (dmem_ren),
        .funct3_i   (dmem_funct3),
        .rdata_o    (dmem_rdata),

        .ram_addr_o   (ram_addr),
        .ram_wdata_o  (ram_wdata),
        .ram_wen_o    (ram_wen),
        .ram_ren_o    (ram_ren),
        .ram_funct3_o (ram_funct3),
        .ram_rdata_i  (ram_rdata),

        .uart_addr_o  (uart_addr),
        .uart_wdata_o (uart_wdata),
        .uart_wen_o   (uart_wen),
        .uart_ren_o   (uart_ren),
        .uart_rdata_i (uart_rdata),

        .timer_addr_o  (timer_addr),
        .timer_wdata_o (timer_wdata),
        .timer_wen_o   (timer_wen),
        .timer_ren_o   (timer_ren),
        .timer_rdata_i (timer_rdata),

        .vga_addr_o  (vga_addr),
        .vga_wdata_o (vga_wdata),
        .vga_wen_o   (vga_wen),
        .vga_ren_o   (vga_ren),
        .vga_rdata_i (vga_rdata),

        .kbd_addr_o  (kbd_addr),
        .kbd_wdata_o (kbd_wdata),
        .kbd_wen_o   (kbd_wen),
        .kbd_ren_o   (kbd_ren),
        .kbd_rdata_i (kbd_rdata)
    );

    // Data RAM
    ram u_ram (
        .clk      (clk),
        .addr_i   (ram_addr),
        .data_i   (ram_wdata),
        .wen_i    (ram_wen),
        .ren_i    (ram_ren),
        .funct3_i (ram_funct3),
        .data_o   (ram_rdata)
    );

    // UART
    uart u_uart (
        .clk     (clk),
        .rst     (reset),
        .addr_i  (uart_addr),
        .wdata_i (uart_wdata),
        .wen_i   (uart_wen),
        .ren_i   (uart_ren),
        .rdata_o (uart_rdata),
        .tx_o    (uart_tx_o)
    );

    // Timer
    timer u_timer (
        .clk     (clk),
        .rst     (reset),
        .addr_i  (timer_addr),
        .wdata_i (timer_wdata),
        .wen_i   (timer_wen),
        .ren_i   (timer_ren),
        .rdata_o (timer_rdata)
    );

    // Keyboard
    keyboard u_kbd (
        .clk        (clk),
        .rst        (reset),
        .addr_i     (kbd_addr),
        .wdata_i    (kbd_wdata),
        .wen_i      (kbd_wen),
        .ren_i      (kbd_ren),
        .rdata_o    (kbd_rdata),
        .ps2_clk_i  (ps2_clk_i),
        .ps2_data_i (ps2_data_i)
    );

    // Pixel clock: divide system clock by 2 (50 MHz → 25 MHz)
    logic clk_pixel;
    always_ff @(posedge clk) begin
        if (reset)
            clk_pixel <= 1'b0;
        else
            clk_pixel <= ~clk_pixel;
    end

    // VGA text-mode controller
    vga_text u_vga (
        .clk       (clk),
        .rst       (reset),
        .addr_i    (vga_addr),
        .wdata_i   (vga_wdata),
        .wen_i     (vga_wen),
        .ren_i     (vga_ren),
        .rdata_o   (vga_rdata),
        .clk_pixel (clk_pixel),
        .vga_r     (vga_r),
        .vga_g     (vga_g),
        .vga_b     (vga_b),
        .vga_hsync (vga_hsync),
        .vga_vsync (vga_vsync)
    );

endmodule : top
