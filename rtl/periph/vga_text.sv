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
    // No initial block — allows M9K inference; software clears at boot

    // CPU address decode: offset = addr[13:2] (word index)
    logic [11:0] cpu_idx;
    assign cpu_idx = addr_i[13:2];

    // CPU write
    always_ff @(posedge clk) begin
        if (!rst && wen_i && cpu_idx < BUF_SIZE)
            text_buf[cpu_idx] <= wdata_i[7:0];
    end

    // CPU read — synchronous for M9K inference
    logic [7:0] text_read_q;
    always_ff @(posedge clk) begin
        text_read_q <= text_buf[cpu_idx];
    end
    assign rdata_o = {24'b0, text_read_q};

    // ── Font ROM (128 chars × 8 rows = 1024 bytes) ─────────
    // Declared inside ifdef blocks below (Stage 2 section).

    // ── VGA timing (inlined from vga_timing.sv) ──────────
    // 640×480 @ 60 Hz, pixel clock 25 MHz
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK; // 800
    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK; // 525

    logic [9:0] h_count, v_count;
    logic       active;

    always_ff @(posedge clk_pixel) begin
        if (rst) begin
            h_count <= '0;
            v_count <= '0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= '0;
                if (v_count == V_TOTAL - 1)
                    v_count <= '0;
                else
                    v_count <= v_count + 1'b1;
            end else begin
                h_count <= h_count + 1'b1;
            end
        end
    end

    assign vga_hsync = ~(h_count >= H_VISIBLE + H_FRONT &&
                         h_count <  H_VISIBLE + H_FRONT + H_SYNC);
    assign vga_vsync = ~(v_count >= V_VISIBLE + V_FRONT &&
                         v_count <  V_VISIBLE + V_FRONT + V_SYNC);
    assign active    = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

    // ── Pixel generation ────────────────────────────────────
    // Character grid position
    logic [6:0] char_col;   // 0–79
    logic [4:0] char_row;   // 0–29
    assign char_col = h_count[9:3];         // h / 8
    assign char_row = v_count[8:4];         // v / 16 (max 29, fits 5 bits)

    // Text buffer index: row*80 = (row<<6) + (row<<4), avoids hardware multiplier
    logic [11:0] char_idx;
    assign char_idx = {1'b0, char_row, 6'b0} + {3'b0, char_row, 4'b0} + {5'b0, char_col};

    // Font row: 8×8 font doubled vertically → use v_count[3:1]
    logic [2:0] font_row;
    assign font_row = v_count[3:1];

    // Pixel bit: MSB = leftmost → use inverted sub-pixel column
    logic [2:0] sub_col;
    assign sub_col = h_count[2:0];

    // ── Pipeline: 2 pixel-clock stages (sync reads for M9K inference) ──
    // Stage 1: read char_code from text_buf (synchronous on pixel clock)
    logic [7:0] char_code_r;
    logic [2:0] font_row_r;
    logic [2:0] sub_col_s1;
    logic       active_s1;

    always_ff @(posedge clk_pixel) begin
        char_code_r <= text_buf[char_idx];
        font_row_r  <= font_row;
        sub_col_s1  <= sub_col;
        active_s1   <= active;
    end

    // Stage 2: read font_byte from font_rom (synchronous on pixel clock)
    logic [7:0] font_byte_r;
    logic [2:0] sub_col_r;
    logic       active_r;

    always_ff @(posedge clk_pixel) begin
        sub_col_r <= sub_col_s1;
        active_r  <= active_s1;
    end

`ifdef SYNTHESIS
    // Direct M9K ROM via altsyncram — works around Quartus
    // "MIF not supported for the selected family" inference bug.
    // UNREGISTERED output: M9K internal address register provides
    // the 1-cycle read latency, matching the behavioral model.
    altsyncram #(
        .operation_mode        ("ROM"),
        .width_a               (8),
        .widthad_a             (10),
        .numwords_a            (1024),
        .outdata_reg_a         ("UNREGISTERED"),
        .init_file             ("../data/font8x8.mif"),
        .clock_enable_input_a  ("BYPASS"),
        .intended_device_family("MAX 10"),
        .lpm_type              ("altsyncram")
    ) font_rom_inst (
        .clock0        (clk_pixel),
        .address_a     ({char_code_r[6:0], font_row_r}),
        .q_a           (font_byte_r),
        .aclr0         (1'b0),
        .aclr1         (1'b0),
        .address_b     (1'b1),
        .addressstall_a(1'b0),
        .addressstall_b(1'b0),
        .byteena_a     (1'b1),
        .byteena_b     (1'b1),
        .clock1        (1'b1),
        .clocken0      (1'b1),
        .clocken1      (1'b1),
        .clocken2      (1'b1),
        .clocken3      (1'b1),
        .data_a        (8'hFF),
        .data_b        (1'b1),
        .eccstatus     (),
        .q_b           (),
        .rden_a        (1'b1),
        .rden_b        (1'b1),
        .wren_a        (1'b0),
        .wren_b        (1'b0)
    );
`else
    // Behavioral model for simulation
    logic [7:0] font_rom [0:1023];
    initial $readmemh(`FONT_PATH, font_rom);

    always_ff @(posedge clk_pixel)
        font_byte_r <= font_rom[{char_code_r[6:0], font_row_r}];
`endif

    logic pixel_on;
    assign pixel_on = font_byte_r[3'd7 - sub_col_r];

    // RGB output: white text on black background
    always_comb begin
        if (active_r && pixel_on) begin
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
