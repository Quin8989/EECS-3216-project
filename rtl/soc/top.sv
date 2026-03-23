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
    input  logic       uart_rx_i,
    // PS/2 keyboard
    input  logic       ps2_clk_i,
    input  logic       ps2_data_i,
    // Debug
    output logic [31:0] dbg_pc_o,
    output logic        dbg_vga_wr_o
);

    // CPU data bus
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic        dmem_wen, dmem_ren;
    logic [2:0]  dmem_funct3;

    // Device buses
    logic [31:0] rom_addr,   rom_rdata,   rom_word,  rom_wdata;
    logic        rom_wen;
    logic [2:0]  rom_funct3;

    logic [31:0] ram_addr,   ram_wdata,   ram_rdata;
    logic        ram_wen;
    logic [2:0]  ram_funct3;

    logic [31:0] uart_addr,  uart_wdata,  uart_rdata;
    logic        uart_wen,   uart_ren;

    logic [31:0] timer_addr, timer_wdata, timer_rdata;
    logic        timer_wen;

    logic [31:0] vga_addr,   vga_wdata,   vga_rdata;
    logic        vga_wen;

    logic [31:0] kbd_addr,   kbd_rdata;
    logic        kbd_ren;

    // Debug: expose PC from fetch unit
    logic [31:0] pc_w;
    assign dbg_pc_o = pc_w;

    // Debug: latch if any VGA write ever occurred
    logic vga_wr_seen;
    always_ff @(posedge clk)
        if (reset) vga_wr_seen <= 1'b0;
        else if (vga_wen) vga_wr_seen <= 1'b1;
    assign dbg_vga_wr_o = vga_wr_seen;

    cpu u_cpu (
        .clk           (clk),
        .reset         (reset),
        .dmem_addr_o   (dmem_addr),
        .dmem_wdata_o  (dmem_wdata),
        .dmem_rdata_i  (dmem_rdata),
        .dmem_wen_o    (dmem_wen),
        .dmem_ren_o    (dmem_ren),
        .dmem_funct3_o (dmem_funct3),
        .rom_daddr_i   (rom_addr),
        .rom_drdata_o  (rom_word),
        .rom_dwen_i    (rom_wen),
        .rom_dwdata_i  (rom_wdata),
        .rom_dfunct3_i (rom_funct3),
        .dbg_pc_o      (pc_w)
    );

    // ── Memory map (inlined from mem_map.sv) ──────────────
    // Address map:
    //   0x0100_0000  ROM      0x0200_0000  RAM
    //   0x1000_0000  UART     0x2000_0000  Timer
    //   0x3000_0000  VGA      0x4000_0000  Keyboard

    logic [7:0] sel;
    assign sel = dmem_addr[31:24];

    localparam SEL_ROM   = 8'h01;
    localparam SEL_RAM   = 8'h02;
    localparam SEL_UART  = 8'h10;
    localparam SEL_TIMER = 8'h20;
    localparam SEL_VGA   = 8'h30;
    localparam SEL_KBD   = 8'h40;

    // Forward address and data to all devices
    assign rom_addr     = dmem_addr;
    assign rom_wdata    = dmem_wdata;
    assign rom_funct3   = dmem_funct3;
    assign ram_addr     = dmem_addr;
    assign ram_wdata    = dmem_wdata;
    assign ram_funct3   = dmem_funct3;
    assign uart_addr    = dmem_addr;
    assign uart_wdata   = dmem_wdata;
    assign timer_addr   = dmem_addr;
    assign timer_wdata  = dmem_wdata;
    assign vga_addr     = dmem_addr;
    assign vga_wdata    = dmem_wdata;
    assign kbd_addr     = dmem_addr;

    // Write enables: only the selected device gets the write
    always_comb begin
        rom_wen   = 1'b0;
        ram_wen   = 1'b0;
        uart_wen  = 1'b0;
        timer_wen = 1'b0;
        vga_wen   = 1'b0;

        case (sel)
            SEL_ROM:   rom_wen   = dmem_wen;
            SEL_RAM:   ram_wen   = dmem_wen;
            SEL_UART:  uart_wen  = dmem_wen;
            SEL_TIMER: timer_wen = dmem_wen;
            SEL_VGA:   vga_wen   = dmem_wen;
            default:   ;
        endcase
    end

    // Read enables (only for peripherals with read side-effects)
    always_comb begin
        uart_ren = 1'b0;
        kbd_ren  = 1'b0;

        case (sel)
            SEL_UART: uart_ren = dmem_ren;
            SEL_KBD:  kbd_ren  = dmem_ren;
            default:  ;
        endcase
    end

    // Read data mux
    always_comb begin
        case (sel)
            SEL_ROM:   dmem_rdata = rom_rdata;
            SEL_RAM:   dmem_rdata = ram_rdata;
            SEL_UART:  dmem_rdata = uart_rdata;
            SEL_TIMER: dmem_rdata = timer_rdata;
            SEL_VGA:   dmem_rdata = vga_rdata;
            SEL_KBD:   dmem_rdata = kbd_rdata;
            default:   dmem_rdata = 32'hDEAD_BEEF;
        endcase
    end

    // Byte extraction for ROM data-bus reads
    logic [1:0]  rom_byte_off;
    assign rom_byte_off = rom_addr[1:0];

    logic [7:0]  rom_bv;
    logic [15:0] rom_hv;
    assign rom_bv = rom_word[rom_byte_off*8 +: 8];
    assign rom_hv = rom_word[rom_byte_off[1]*16 +: 16];

    always_comb begin
        case (dmem_funct3)
            `F3_BYTE:  rom_rdata = {{24{rom_bv[7]}}, rom_bv};
            `F3_BYTEU: rom_rdata = {24'b0, rom_bv};
            `F3_HALF:  rom_rdata = {{16{rom_hv[15]}}, rom_hv};
            `F3_HALFU: rom_rdata = {16'b0, rom_hv};
            default:   rom_rdata = rom_word;  // F3_WORD
        endcase
    end

    // Data RAM
    ram u_ram (
        .clk      (clk),
        .addr_i   (ram_addr),
        .data_i   (ram_wdata),
        .wen_i    (ram_wen),
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
        .tx_o    (uart_tx_o),
        .rx_i    (uart_rx_i)
    );

    // Timer
    timer u_timer (
        .clk     (clk),
        .rst     (reset),
        .addr_i  (timer_addr),
        .wdata_i (timer_wdata),
        .wen_i   (timer_wen),
        .rdata_o (timer_rdata)
    );

    // Keyboard
    keyboard u_kbd (
        .clk        (clk),
        .rst        (reset),
        .addr_i     (kbd_addr),
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
        .rdata_o   (vga_rdata),
        .clk_pixel (clk_pixel),
        .vga_r     (vga_r),
        .vga_g     (vga_g),
        .vga_b     (vga_b),
        .vga_hsync (vga_hsync),
        .vga_vsync (vga_vsync)
    );

endmodule : top
