// 320×240 8 bpp (RGB332) on-chip framebuffer with VGA scanout.
//
// The framebuffer lives in on-chip dual-port block RAM (76 800 bytes,
// organised as 19 200 × 32-bit words).  Port A is the CPU read/write
// port; port B is the VGA read-only scanout port.
//
// Each source pixel is doubled horizontally and vertically → 640×480.
// VGA timing: 640×480 @ ~60 Hz, 25 MHz pixel clock.

module vga_fb (
    input  logic        clk,
    input  logic        rst,

    // CPU read/write port (directly memory-mapped)
    input  logic [16:0] fb_addr_i,      // byte address within FB (0–76799)
    input  logic [31:0] fb_wdata_i,
    input  logic        fb_we_i,
    input  logic [2:0]  fb_funct3_i,    // SB/SH/SW width
    output logic [31:0] fb_rdata_o,

    // VGA output
    output logic [3:0]  vga_r,
    output logic [3:0]  vga_g,
    output logic [3:0]  vga_b,
    output logic        vga_hsync,
    output logic        vga_vsync,
    output logic        blanking_o
);

    // ── Parameters ────────────────────────────────────
    localparam int FB_W = 320, FB_H = 240;
    localparam int WORDS_PER_LINE = FB_W / 4;          // 80
    localparam int FB_WORDS       = FB_W * FB_H / 4;   // 19200

    // 640×480 @ 60 Hz  (25.175 MHz ≈ 25 MHz pixel clock)
    localparam int H_VIS = 640, H_FP = 16, H_SYNC = 96, H_BP = 48;
    localparam int H_TOT = H_VIS + H_FP + H_SYNC + H_BP;   // 800
    localparam int V_VIS = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33;
    localparam int V_TOT = V_VIS + V_FP + V_SYNC + V_BP;    // 525

    // ── Port A: CPU access ────────────────────────────
    logic [14:0] cpu_word_addr;
    assign cpu_word_addr = fb_addr_i[16:2];

    // Byte enables (same pattern as ram.sv)
    logic [3:0] be;
    logic [1:0] boff;
    assign boff = fb_addr_i[1:0];

    always_comb begin
        be = 4'b0000;
        case (fb_funct3_i[1:0])
            2'b00:   be[boff] = 1'b1;                                // SB
            2'b01:   be = boff[1] ? 4'b1100 : 4'b0011;              // SH
            default: be = 4'b1111;                                    // SW
        endcase
    end

    // Write-data byte routing
    logic [7:0] wd0, wd1, wd2, wd3;
    always_comb begin
        wd0 = fb_wdata_i[ 7: 0];
        wd1 = fb_wdata_i[15: 8];
        wd2 = fb_wdata_i[23:16];
        wd3 = fb_wdata_i[31:24];
        case (fb_funct3_i[1:0])
            2'b00: begin   // SB — replicate byte to all lanes
                wd0 = fb_wdata_i[7:0]; wd1 = fb_wdata_i[7:0];
                wd2 = fb_wdata_i[7:0]; wd3 = fb_wdata_i[7:0];
            end
            2'b01: begin   // SH — replicate halfword
                wd0 = fb_wdata_i[7:0]; wd1 = fb_wdata_i[15:8];
                wd2 = fb_wdata_i[7:0]; wd3 = fb_wdata_i[15:8];
            end
            default: ;     // SW — use as-is
        endcase
    end

    // ── VGA timing counters ───────────────────────────
    logic [9:0] h_count, v_count;

    always_ff @(posedge clk) begin
        if (rst) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else begin
            if (h_count == H_TOT - 1) begin
                h_count <= 10'd0;
                v_count <= (v_count == V_TOT - 1) ? 10'd0 : v_count + 10'd1;
            end else
                h_count <= h_count + 10'd1;
        end
    end

    // ── Sync and blanking ─────────────────────────────
    wire active     = (h_count < H_VIS) && (v_count < V_VIS);
    wire hsync_next = ~(h_count >= H_VIS + H_FP &&
                        h_count <  H_VIS + H_FP + H_SYNC);
    wire vsync_next = ~(v_count >= V_VIS + V_FP &&
                        v_count <  V_VIS + V_FP + V_SYNC);

    assign blanking_o = (v_count >= V_VIS);

    // ── Port B: VGA scanout ───────────────────────────
    // Source pixel from 2× scaled coordinates
    wire [8:0] src_x = h_count[9:1];   // 0–319
    wire [7:0] src_y = v_count[9:1];   // 0–239

    // Framebuffer read address: src_y * 80 + src_x[8:2]
    //   src_y * 80 = (src_y << 6) + (src_y << 4)
    wire [14:0] line_base = {1'b0, src_y, 6'b0} + {3'b0, src_y, 4'b0};
    wire [14:0] vga_word_addr = line_base + {8'b0, src_x[8:2]};

    // ── Explicit dual-port byte RAM banks ─────────────
    logic [7:0] cpu_rd0, cpu_rd1, cpu_rd2, cpu_rd3;
    logic [7:0] vga_rd0, vga_rd1, vga_rd2, vga_rd3;

    bram #(.DEPTH(FB_WORDS), .DUAL_PORT(1)) u_bank0 (
        .clk    (clk),
        .addr_a (cpu_word_addr),
        .wdata_a(wd0),
        .we_a   (fb_we_i & be[0]),
        .rdata_a(cpu_rd0),
        .addr_b (vga_word_addr),
        .rdata_b(vga_rd0)
    );

    bram #(.DEPTH(FB_WORDS), .DUAL_PORT(1)) u_bank1 (
        .clk    (clk),
        .addr_a (cpu_word_addr),
        .wdata_a(wd1),
        .we_a   (fb_we_i & be[1]),
        .rdata_a(cpu_rd1),
        .addr_b (vga_word_addr),
        .rdata_b(vga_rd1)
    );

    bram #(.DEPTH(FB_WORDS), .DUAL_PORT(1)) u_bank2 (
        .clk    (clk),
        .addr_a (cpu_word_addr),
        .wdata_a(wd2),
        .we_a   (fb_we_i & be[2]),
        .rdata_a(cpu_rd2),
        .addr_b (vga_word_addr),
        .rdata_b(vga_rd2)
    );

    bram #(.DEPTH(FB_WORDS), .DUAL_PORT(1)) u_bank3 (
        .clk    (clk),
        .addr_a (cpu_word_addr),
        .wdata_a(wd3),
        .we_a   (fb_we_i & be[3]),
        .rdata_a(cpu_rd3),
        .addr_b (vga_word_addr),
        .rdata_b(vga_rd3)
    );

    assign fb_rdata_o = {cpu_rd3, cpu_rd2, cpu_rd1, cpu_rd0};
    logic [31:0] vga_word;
    assign vga_word = {vga_rd3, vga_rd2, vga_rd1, vga_rd0};

    // Delay byte select to match RAM read latency
    logic [1:0] byte_sel_q;
    logic       active_q;
    always_ff @(posedge clk) begin
        byte_sel_q <= src_x[1:0];
        active_q   <= active;
    end

    // Extract pixel byte from word
    logic [7:0] pixel;
    always_comb begin
        case (byte_sel_q)
            2'd0:    pixel = vga_word[ 7: 0];
            2'd1:    pixel = vga_word[15: 8];
            2'd2:    pixel = vga_word[23:16];
            default: pixel = vga_word[31:24];
        endcase
    end

    // ── Registered VGA outputs (RGB332 → RGB444) ─────
    always_ff @(posedge clk) begin
        if (rst) begin
            vga_r     <= 4'd0;
            vga_g     <= 4'd0;
            vga_b     <= 4'd0;
            vga_hsync <= 1'b1;
            vga_vsync <= 1'b1;
        end else begin
            vga_hsync <= hsync_next;
            vga_vsync <= vsync_next;
            if (active_q) begin
                vga_r <= {pixel[7:5], pixel[7]};
                vga_g <= {pixel[4:2], pixel[4]};
                vga_b <= {pixel[1:0], pixel[1:0]};
            end else begin
                vga_r <= 4'd0;
                vga_g <= 4'd0;
                vga_b <= 4'd0;
            end
        end
    end

endmodule : vga_fb
