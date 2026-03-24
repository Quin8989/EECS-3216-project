// 320x240 8bpp RGB332 framebuffer in SDRAM.
//
// The framebuffer lives at SDRAM word address 0 and is scanned out using two
// on-chip line buffers. Each source line is doubled vertically and each source
// pixel is doubled horizontally to produce a 640x480 VGA image.

module vga_fb (
    input  logic        clk_pixel,
    input  logic        rst,
    output logic [23:0] sdram_addr_o,
    output logic        sdram_req_o,
    input  logic        sdram_ack_i,
    input  logic        sdram_valid_i,
    input  logic [31:0] sdram_q_i,
    output logic [3:0]  vga_r,
    output logic [3:0]  vga_g,
    output logic [3:0]  vga_b,
    output logic        vga_hsync,
    output logic        vga_vsync
);

    localparam int FB_WIDTH       = 320;
    localparam int FB_HEIGHT      = 240;
    localparam int WORDS_PER_LINE = FB_WIDTH / 4;
    localparam int LAST_WORD      = WORDS_PER_LINE - 1;
    localparam int LAST_ROW       = FB_HEIGHT - 1;

    localparam int H_VISIBLE = 640;
    localparam int H_FRONT   = 16;
    localparam int H_SYNC    = 96;
    localparam int H_BACK    = 48;
    localparam int H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;
    localparam int V_VISIBLE = 480;
    localparam int V_FRONT   = 10;
    localparam int V_SYNC    = 2;
    localparam int V_BACK    = 33;
    localparam int V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;
    localparam int DEBUG_MODE_NORMAL      = 0;
    localparam int DEBUG_MODE_COLOR_BARS  = 1;
    localparam int DEBUG_MODE_REPEAT_ROW0 = 2;
    localparam int DEBUG_MODE = DEBUG_MODE_NORMAL;
    localparam logic [7:0] DEBUG_REPEAT_ROW = 8'd120;

    localparam logic [1:0] FETCH_IDLE      = 2'd0;
    localparam logic [1:0] FETCH_WAIT_ACK  = 2'd1;
    localparam logic [1:0] FETCH_WAIT_DATA = 2'd2;

    function automatic [7:0] next_row(input [7:0] row);
        begin
            if (row == LAST_ROW[7:0])
                next_row = 8'd0;
            else
                next_row = row + 8'd1;
        end
    endfunction

    function automatic [23:0] line_base_addr(input [7:0] row);
        reg [23:0] row_64;
        reg [23:0] row_16;
        begin
            row_64 = {row, 6'b0};
            row_16 = {row, 4'b0};
            line_base_addr = row_64 + row_16;
        end
    endfunction

    // Keep the scanline buffers in logic instead of inferred RAM blocks.
    // Quartus was adding pass-through logic for read-during-write behavior,
    // which lines up with the short 2-4 pixel artifacts seen on screen.
    (* ramstyle = "logic" *) logic [31:0] line_buf0 [0:WORDS_PER_LINE-1];
    (* ramstyle = "logic" *) logic [31:0] line_buf1 [0:WORDS_PER_LINE-1];

    logic        buf_valid0;
    logic        buf_valid1;
    logic [7:0]  buf_row0;
    logic [7:0]  buf_row1;

    logic        current_buf_sel;
    logic [7:0]  current_row;
    logic        current_ready;
    logic        next_ready;

    logic [9:0]  h_count;
    logic [9:0]  v_count;
    logic        active;
    logic [8:0]  src_x;
    logic [7:0]  src_y;
    logic [6:0]  src_word_idx;
    logic [1:0]  src_byte_idx;
    logic [31:0] current_word;
    logic [7:0]  pixel_r;
    logic [2:0]  red3;
    logic [2:0]  green3;
    logic [1:0]  blue2;
    logic [3:0]  vga_r_next;
    logic [3:0]  vga_g_next;
    logic [3:0]  vga_b_next;
    logic        vga_hsync_next;
    logic        vga_vsync_next;

    logic [1:0]  fetch_state;
    logic        fetch_buf_sel;
    logic [7:0]  fetch_row;
    logic [6:0]  fetch_word_idx;

    logic        swap_now;
    logic [7:0]  desired_row;
    logic        need_current_fetch;
    logic        need_next_fetch;
    logic        current_ready_sel0;
    logic        current_ready_sel1;
    logic        next_ready_sel0;
    logic        next_ready_sel1;

    assign active    = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
    assign src_x     = h_count[9:1];
    assign src_y     = v_count[8:1];
    assign desired_row = (DEBUG_MODE == DEBUG_MODE_REPEAT_ROW0) ? DEBUG_REPEAT_ROW : v_count[8:1];
    assign src_word_idx = src_x[8:2];
    assign src_byte_idx = src_x[1:0];

    assign current_ready_sel0 = (current_buf_sel == 1'b0) && buf_valid0 && (buf_row0 == current_row);
    assign current_ready_sel1 = (current_buf_sel == 1'b1) && buf_valid1 && (buf_row1 == current_row);
    assign next_ready_sel0    = (current_buf_sel == 1'b1) && buf_valid0 && (buf_row0 == next_row(current_row));
    assign next_ready_sel1    = (current_buf_sel == 1'b0) && buf_valid1 && (buf_row1 == next_row(current_row));

    assign current_ready = current_ready_sel0 || current_ready_sel1;
    assign next_ready    = next_ready_sel0 || next_ready_sel1;

    assign swap_now = (DEBUG_MODE == DEBUG_MODE_NORMAL) &&
                      (h_count == 10'd0) &&
                      (v_count < V_VISIBLE) &&
                      (desired_row != current_row);
    assign need_current_fetch = !current_ready;
    assign need_next_fetch    = (DEBUG_MODE == DEBUG_MODE_NORMAL) && !next_ready;

    always_ff @(posedge clk_pixel) begin
        if (rst) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= 10'd0;
                if (v_count == V_TOTAL - 1)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end else begin
                h_count <= h_count + 10'd1;
            end
        end
    end

    assign vga_hsync_next = ~(h_count >= H_VISIBLE + H_FRONT &&
                              h_count <  H_VISIBLE + H_FRONT + H_SYNC);
    assign vga_vsync_next = ~(v_count >= V_VISIBLE + V_FRONT &&
                              v_count <  V_VISIBLE + V_FRONT + V_SYNC);

    always_ff @(posedge clk_pixel) begin
        if (rst) begin
            buf_valid0      <= 1'b0;
            buf_valid1      <= 1'b0;
            buf_row0        <= 8'd0;
            buf_row1        <= 8'd0;
            current_buf_sel <= 1'b0;
            current_row     <= DEBUG_REPEAT_ROW;
            fetch_state     <= FETCH_IDLE;
            fetch_buf_sel   <= 1'b0;
            fetch_row       <= 8'd0;
            fetch_word_idx  <= 7'd0;
            sdram_req_o     <= 1'b0;
            sdram_addr_o    <= 24'd0;
        end else begin
            if (swap_now) begin
                if ((current_buf_sel == 1'b0) && buf_valid1 && (buf_row1 == desired_row)) begin
                    current_buf_sel <= 1'b1;
                    current_row     <= desired_row;
                    buf_valid0      <= 1'b0;
                end else if ((current_buf_sel == 1'b1) && buf_valid0 && (buf_row0 == desired_row)) begin
                    current_buf_sel <= 1'b0;
                    current_row     <= desired_row;
                    buf_valid1      <= 1'b0;
                end
            end

            case (fetch_state)
                FETCH_IDLE: begin
                    sdram_req_o <= 1'b0;

                    if (DEBUG_MODE == DEBUG_MODE_COLOR_BARS) begin
                        fetch_state <= FETCH_IDLE;
                    end else if (need_current_fetch) begin
                        fetch_buf_sel  <= current_buf_sel;
                        fetch_row      <= current_row;
                        fetch_word_idx <= 7'd0;
                        sdram_addr_o   <= line_base_addr(current_row);
                        sdram_req_o    <= 1'b1;
                        fetch_state    <= FETCH_WAIT_ACK;
                    end else if (need_next_fetch) begin
                        fetch_buf_sel  <= ~current_buf_sel;
                        fetch_row      <= next_row(current_row);
                        fetch_word_idx <= 7'd0;
                        sdram_addr_o   <= line_base_addr(next_row(current_row));
                        sdram_req_o    <= 1'b1;
                        fetch_state    <= FETCH_WAIT_ACK;
                    end
                end

                FETCH_WAIT_ACK: begin
                    if (sdram_ack_i) begin
                        sdram_req_o  <= 1'b0;
                        fetch_state  <= FETCH_WAIT_DATA;
                    end
                end

                FETCH_WAIT_DATA: begin
                    if (sdram_valid_i) begin
                        if (fetch_buf_sel == 1'b0)
                            line_buf0[fetch_word_idx] <= sdram_q_i;
                        else
                            line_buf1[fetch_word_idx] <= sdram_q_i;

                        if (fetch_word_idx == LAST_WORD[6:0]) begin
                            if (fetch_buf_sel == 1'b0) begin
                                buf_valid0 <= 1'b1;
                                buf_row0   <= fetch_row;
                            end else begin
                                buf_valid1 <= 1'b1;
                                buf_row1   <= fetch_row;
                            end
                            fetch_state <= FETCH_IDLE;
                        end else begin
                            fetch_word_idx <= fetch_word_idx + 7'd1;
                            sdram_addr_o   <= line_base_addr(fetch_row) + fetch_word_idx + 24'd1;
                            sdram_req_o    <= 1'b1;
                            fetch_state    <= FETCH_WAIT_ACK;
                        end
                    end
                end

                default: begin
                    fetch_state <= FETCH_IDLE;
                end
            endcase
        end
    end

    always_comb begin
        if (current_buf_sel == 1'b0)
            current_word = line_buf0[src_word_idx];
        else
            current_word = line_buf1[src_word_idx];

        case (src_byte_idx)
            2'd0: pixel_r = current_word[7:0];
            2'd1: pixel_r = current_word[15:8];
            2'd2: pixel_r = current_word[23:16];
            default: pixel_r = current_word[31:24];
        endcase

        red3   = pixel_r[7:5];
        green3 = pixel_r[4:2];
        blue2  = pixel_r[1:0];

        if (DEBUG_MODE == DEBUG_MODE_COLOR_BARS) begin
            if (active) begin
                case (src_x[8:6])
                    3'd0: begin vga_r_next = 4'hF; vga_g_next = 4'h0; vga_b_next = 4'h0; end
                    3'd1: begin vga_r_next = 4'hF; vga_g_next = 4'h8; vga_b_next = 4'h0; end
                    3'd2: begin vga_r_next = 4'hF; vga_g_next = 4'hF; vga_b_next = 4'h0; end
                    3'd3: begin vga_r_next = 4'h0; vga_g_next = 4'hF; vga_b_next = 4'h0; end
                    3'd4: begin vga_r_next = 4'h0; vga_g_next = 4'hF; vga_b_next = 4'hF; end
                    3'd5: begin vga_r_next = 4'h0; vga_g_next = 4'h0; vga_b_next = 4'hF; end
                    3'd6: begin vga_r_next = 4'h8; vga_g_next = 4'h0; vga_b_next = 4'hF; end
                    default: begin vga_r_next = 4'hF; vga_g_next = 4'hF; vga_b_next = 4'hF; end
                endcase

                if (src_y < 8 || src_y >= (FB_HEIGHT - 8) || src_x < 8 || src_x >= (FB_WIDTH - 8)) begin
                    vga_r_next = 4'hF;
                    vga_g_next = 4'hF;
                    vga_b_next = 4'hF;
                end
            end else begin
                vga_r_next = 4'h0;
                vga_g_next = 4'h0;
                vga_b_next = 4'h0;
            end
        end else if ((DEBUG_MODE == DEBUG_MODE_REPEAT_ROW0) && active && current_ready) begin
            vga_r_next = {red3, red3[2]};
            vga_g_next = {green3, green3[2]};
            vga_b_next = {blue2, blue2};
        end else if (active && current_ready) begin
            vga_r_next = {red3, red3[2]};
            vga_g_next = {green3, green3[2]};
            vga_b_next = {blue2, blue2};
        end else begin
            vga_r_next = 4'h0;
            vga_g_next = 4'h0;
            vga_b_next = 4'h0;
        end
    end

    always_ff @(posedge clk_pixel) begin
        if (rst) begin
            vga_r     <= 4'h0;
            vga_g     <= 4'h0;
            vga_b     <= 4'h0;
            vga_hsync <= 1'b1;
            vga_vsync <= 1'b1;
        end else begin
            vga_r     <= vga_r_next;
            vga_g     <= vga_g_next;
            vga_b     <= vga_b_next;
            vga_hsync <= vga_hsync_next;
            vga_vsync <= vga_vsync_next;
        end
    end

endmodule