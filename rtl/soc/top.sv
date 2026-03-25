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
    // Desktop keyboard bridge over JTAG (scan-code injection)
    input  logic       jtag_kbd_valid_i,
    input  logic [7:0] jtag_kbd_code_i,
    // SDRAM controller bus
    output logic [23:0] sdram_addr_o,
    output logic [31:0] sdram_wdata_o,
    output logic        sdram_we_o,
    output logic        sdram_req_o,
    input  logic        sdram_ack_i,
    input  logic        sdram_valid_i,
    output logic [23:0] vga_sdram_addr_o,
    output logic        vga_sdram_req_o,
    input  logic        vga_sdram_ack_i,
    input  logic        vga_sdram_valid_i,
    input  logic [31:0] sdram_q_i,
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

    logic [31:0] kbd_addr,   kbd_wdata,   kbd_rdata;
    logic        kbd_wen,    kbd_ren;

    // SDRAM bridge
    logic        sdram_stall, sdram_selected, sdram_access;
    logic [31:0] sdram_word, sdram_rdata;
    logic        dmem_raw_ren, dmem_raw_wen;

    localparam FB_BYTES = 320 * 240;

    // Debug: expose PC from fetch unit
    logic [31:0] pc_w;
    assign dbg_pc_o = pc_w;

    logic vga_wr_seen;
    always_ff @(posedge clk)
        if (reset) vga_wr_seen <= 1'b0;
        else if (dmem_raw_wen && sdram_selected && dmem_addr[25:0] < FB_BYTES) vga_wr_seen <= 1'b1;
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
        .dmem_raw_ren_o(dmem_raw_ren),
        .dmem_raw_wen_o(dmem_raw_wen),
        .mem_stall_i   (sdram_stall),
        .rom_daddr_i   (rom_addr),
        .rom_drdata_o  (rom_word),
        .rom_dwen_i    (rom_wen),
        .rom_dwdata_i  (rom_wdata),
        .rom_dfunct3_i (rom_funct3),
        .dbg_pc_o      (pc_w)
    );

    // ── Memory map (inlined from mem_map.sv) ──────────────
    // Address map:
    //   0x0100_0000  ROM          0x0200_0000  RAM
    //   0x1000_0000  UART TX      0x2000_0000  Timer
    //   0x3000_0000  Reserved     0x4000_0000  Reserved

    logic [7:0] sel;
    assign sel = dmem_addr[31:24];

    // SDRAM selected for 0x80xxxxxx only (bit 31)
    assign sdram_selected = dmem_addr[31];
    assign sdram_access   = sdram_selected & (dmem_raw_ren | dmem_raw_wen);

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
    assign kbd_addr     = dmem_addr;
    assign kbd_wdata    = dmem_wdata;
    // Write enables: only the selected device gets the write
    always_comb begin
        rom_wen   = 1'b0;
        ram_wen   = 1'b0;
        uart_wen  = 1'b0;
        timer_wen = 1'b0;
        kbd_wen   = 1'b0;

        case (sel)
            SEL_ROM:   rom_wen   = dmem_wen;
            SEL_RAM:   ram_wen   = dmem_wen;
            SEL_UART:  uart_wen  = dmem_wen;
            SEL_TIMER: timer_wen = dmem_wen;
            SEL_KBD:   kbd_wen   = dmem_wen;
            default:   ;
        endcase
    end

    // Read enables
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
        if (sdram_selected)
            dmem_rdata = sdram_rdata;
        else begin
            case (sel)
                SEL_ROM:   dmem_rdata = rom_rdata;
                SEL_RAM:   dmem_rdata = ram_rdata;
                SEL_UART:  dmem_rdata = uart_rdata;
                SEL_TIMER: dmem_rdata = timer_rdata;
                SEL_VGA:   dmem_rdata = 32'h0;
                SEL_KBD:   dmem_rdata = kbd_rdata;
                default:   dmem_rdata = 32'hDEAD_BEEF;
            endcase
        end
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

    // On-chip data RAM with byte extraction (uses registered addr/funct3)
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

    keyboard u_kbd (
        .clk                (clk),
        .rst                (reset),
        .addr_i             (kbd_addr),
        .wdata_i            (kbd_wdata),
        .wen_i              (kbd_wen),
        .ren_i              (kbd_ren),
        .rdata_o            (kbd_rdata),
        .jtag_inject_valid_i(jtag_kbd_valid_i),
        .jtag_inject_code_i (jtag_kbd_code_i)
    );

    vga_fb u_vga (
        .clk_pixel   (clk),
        .rst         (reset),
        .sdram_addr_o(vga_sdram_addr_o),
        .sdram_req_o (vga_sdram_req_o),
        .sdram_ack_i (vga_sdram_ack_i),
        .sdram_valid_i(vga_sdram_valid_i),
        .sdram_q_i   (sdram_q_i),
        .vga_r       (vga_r),
        .vga_g       (vga_g),
        .vga_b       (vga_b),
        .vga_hsync   (vga_hsync),
        .vga_vsync   (vga_vsync)
    );

    // SDRAM bridge (returns raw 32-bit word, byte extraction below)
    sdram_bridge u_sdram_bridge (
        .clk        (clk),
        .reset      (reset),
        .access_i   (sdram_access),
        .write_i    (dmem_raw_wen),
        .addr_i     (dmem_addr[25:2]),
        .wdata_i    (dmem_wdata),
        .rdata_o    (sdram_word),
        .stall_o    (sdram_stall),
        .ctrl_addr  (sdram_addr_o),
        .ctrl_data  (sdram_wdata_o),
        .ctrl_we    (sdram_we_o),
        .ctrl_req   (sdram_req_o),
        .ctrl_ack   (sdram_ack_i),
        .ctrl_valid (sdram_valid_i),
        .ctrl_q     (sdram_q_i)
    );

    // Byte extraction for SDRAM reads (same pattern as ROM)
    logic [1:0]  sdram_byte_off;
    logic [7:0]  sdram_bv;
    logic [15:0] sdram_hv;
    assign sdram_byte_off = dmem_addr[1:0];
    assign sdram_bv = sdram_word[sdram_byte_off*8 +: 8];
    assign sdram_hv = sdram_word[sdram_byte_off[1]*16 +: 16];

    always_comb begin
        case (dmem_funct3)
            `F3_BYTE:  sdram_rdata = {{24{sdram_bv[7]}}, sdram_bv};
            `F3_BYTEU: sdram_rdata = {24'b0, sdram_bv};
            `F3_HALF:  sdram_rdata = {{16{sdram_hv[15]}}, sdram_hv};
            `F3_HALFU: sdram_rdata = {16'b0, sdram_hv};
            default:   sdram_rdata = sdram_word;
        endcase
    end

endmodule : top
