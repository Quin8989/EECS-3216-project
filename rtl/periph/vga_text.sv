// Text-mode VGA controller
//
// 80 columns × 30 rows, 8×16 pixels per character (8×8 font, doubled vertically).
// Text buffer: 2400 bytes, word-addressed from CPU side.
//
// CPU register map (base 0x3000_0000):
//   +4*N  (N = 0..2399) — read/write character at position N
//         col = N % 80, row = N / 80
//         Write: lower 8 bits = ASCII code
//         Read:  returns stored ASCII code (zero-extended to 32 bits)
//
// VGA side reads the buffer and generates pixels using the font ROM.

module vga_text (
    // System clock (CPU side)
    input  logic        clk,
    input  logic        rst,

    // CPU bus
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        wen_i,
    input  logic        ren_i,
    output logic [31:0] rdata_o,

    // Pixel clock (VGA side — 25 MHz)
    input  logic        clk_pixel,

    // VGA outputs
    output logic [3:0]  vga_r,
    output logic [3:0]  vga_g,
    output logic [3:0]  vga_b,
    output logic        vga_hsync,
    output logic        vga_vsync
);

    // ── Parameters ──────────────────────────────────────────
    localparam COLS     = 80;
    localparam ROWS     = 30;
    localparam BUF_SIZE = COLS * ROWS;  // 2400

    // ── Text buffer (dual-port: CPU writes, VGA reads) ──────
    logic [7:0] text_buf [0:BUF_SIZE-1];

    initial begin
        for (int i = 0; i < BUF_SIZE; i++)
            text_buf[i] = 8'h20;  // fill with spaces
    end

    // CPU address decode: offset = addr[13:2] (word index)
    logic [11:0] cpu_idx;
    assign cpu_idx = addr_i[13:2];

    // CPU write
    always_ff @(posedge clk) begin
        if (!rst && wen_i && cpu_idx < BUF_SIZE)
            text_buf[cpu_idx] <= wdata_i[7:0];
    end

    // CPU read
    always_comb begin
        if (cpu_idx < BUF_SIZE)
            rdata_o = {24'b0, text_buf[cpu_idx]};
        else
            rdata_o = 32'h0;
    end

    // ── Font ROM (128 chars × 8 rows = 1024 bytes) ─────────
    logic [7:0] font_rom [0:1023];

    initial begin
        for (int i = 0; i < 1024; i++) font_rom[i] = 8'h00;
        $readmemh(`FONT_PATH, font_rom);
    end

    // ── VGA timing ──────────────────────────────────────────
    logic [9:0] h_count, v_count;
    logic        active;

    vga_timing u_timing (
        .clk_pixel (clk_pixel),
        .rst       (rst),
        .h_count   (h_count),
        .v_count   (v_count),
        .hsync     (vga_hsync),
        .vsync     (vga_vsync),
        .active    (active)
    );

    // ── Pixel generation ────────────────────────────────────
    // Character grid position
    logic [6:0] char_col;   // 0–79
    logic [4:0] char_row;   // 0–29
    assign char_col = h_count[9:3];         // h / 8
    assign char_row = v_count[9:4];         // v / 16

    // Text buffer index: row*80 = (row<<6) + (row<<4), avoids hardware multiplier
    logic [11:0] char_idx;
    assign char_idx = {1'b0, char_row, 6'b0} + {3'b0, char_row, 4'b0} + {5'b0, char_col};

    // Character code from buffer
    logic [7:0] char_code;
    assign char_code = text_buf[char_idx];

    // Font row: 8×8 font doubled vertically → use v_count[3:1]
    logic [2:0] font_row;
    assign font_row = v_count[3:1];

    // Font byte for this character + row
    logic [7:0] font_byte;
    assign font_byte = font_rom[{char_code[6:0], font_row}];

    // Pixel bit: MSB = leftmost → use inverted sub-pixel column
    logic [2:0] sub_col;
    assign sub_col = h_count[2:0];

    logic pixel_on;
    assign pixel_on = font_byte[3'd7 - sub_col];

    // RGB output: white text on black background
    always_comb begin
        if (active && pixel_on) begin
            vga_r = 4'hF;
            vga_g = 4'hF;
            vga_b = 4'hF;
        end else begin
            vga_r = 4'h0;
            vga_g = 4'h0;
            vga_b = 4'h0;
        end
    end

endmodule : vga_text
