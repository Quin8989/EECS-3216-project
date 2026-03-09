// Memory map: routes CPU data bus to devices by address.
//
// Address map:
//   0x0200_0000  Data RAM    (64 KB)
//   0x1000_0000  UART        (data @ +0, status @ +4)
//   0x2000_0000  Timer       (count @ +0, compare @ +4)
//   0x3000_0000  VGA         (framebuffer)
//   0x4000_0000  Keyboard    (data @ +0, status @ +4)

module mem_map (
    // CPU side
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        wen_i,
    input  logic        ren_i,
    input  logic [2:0]  funct3_i,
    output logic [31:0] rdata_o,

    // RAM
    output logic [31:0] ram_addr_o,
    output logic [31:0] ram_wdata_o,
    output logic        ram_wen_o,
    output logic        ram_ren_o,
    output logic [2:0]  ram_funct3_o,
    input  logic [31:0] ram_rdata_i,

    // UART
    output logic [31:0] uart_addr_o,
    output logic [31:0] uart_wdata_o,
    output logic        uart_wen_o,
    output logic        uart_ren_o,
    input  logic [31:0] uart_rdata_i,

    // Timer
    output logic [31:0] timer_addr_o,
    output logic [31:0] timer_wdata_o,
    output logic        timer_wen_o,
    output logic        timer_ren_o,
    input  logic [31:0] timer_rdata_i,

    // VGA
    output logic [31:0] vga_addr_o,
    output logic [31:0] vga_wdata_o,
    output logic        vga_wen_o,
    output logic        vga_ren_o,
    input  logic [31:0] vga_rdata_i,

    // Keyboard
    output logic [31:0] kbd_addr_o,
    output logic [31:0] kbd_wdata_o,
    output logic        kbd_wen_o,
    output logic        kbd_ren_o,
    input  logic [31:0] kbd_rdata_i
);

    // Device select from upper address byte
    logic [7:0] sel;
    assign sel = addr_i[31:24];

    localparam SEL_RAM   = 8'h02;
    localparam SEL_UART  = 8'h10;
    localparam SEL_TIMER = 8'h20;
    localparam SEL_VGA   = 8'h30;
    localparam SEL_KBD   = 8'h40;

    // Forward address and data to all devices
    assign ram_addr_o   = addr_i;
    assign ram_wdata_o  = wdata_i;
    assign ram_funct3_o = funct3_i;

    assign uart_addr_o  = addr_i;
    assign uart_wdata_o = wdata_i;

    assign timer_addr_o  = addr_i;
    assign timer_wdata_o = wdata_i;

    assign vga_addr_o  = addr_i;
    assign vga_wdata_o = wdata_i;

    assign kbd_addr_o  = addr_i;
    assign kbd_wdata_o = wdata_i;

    // Write enables: only the selected device gets the write
    always_comb begin
        ram_wen_o   = 1'b0;
        uart_wen_o  = 1'b0;
        timer_wen_o = 1'b0;
        vga_wen_o   = 1'b0;
        kbd_wen_o   = 1'b0;

        case (sel)
            SEL_RAM:   ram_wen_o   = wen_i;
            SEL_UART:  uart_wen_o  = wen_i;
            SEL_TIMER: timer_wen_o = wen_i;
            SEL_VGA:   vga_wen_o   = wen_i;
            SEL_KBD:   kbd_wen_o   = wen_i;
            default:   ;
        endcase
    end

    // Read enables
    always_comb begin
        ram_ren_o   = 1'b0;
        uart_ren_o  = 1'b0;
        timer_ren_o = 1'b0;
        vga_ren_o   = 1'b0;
        kbd_ren_o   = 1'b0;

        case (sel)
            SEL_RAM:   ram_ren_o   = ren_i;
            SEL_UART:  uart_ren_o  = ren_i;
            SEL_TIMER: timer_ren_o = ren_i;
            SEL_VGA:   vga_ren_o   = ren_i;
            SEL_KBD:   kbd_ren_o   = ren_i;
            default:   ;
        endcase
    end

    // Read data mux
    always_comb begin
        case (sel)
            SEL_RAM:   rdata_o = ram_rdata_i;
            SEL_UART:  rdata_o = uart_rdata_i;
            SEL_TIMER: rdata_o = timer_rdata_i;
            SEL_VGA:   rdata_o = vga_rdata_i;
            SEL_KBD:   rdata_o = kbd_rdata_i;
            default:   rdata_o = 32'hDEAD_BEEF;
        endcase
    end

endmodule : mem_map
