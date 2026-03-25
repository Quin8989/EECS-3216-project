`timescale 1ns/1ps

module test_keyboard_demo;
    logic clk;
    logic reset;
    logic [3:0] vga_r;
    logic [3:0] vga_g;
    logic [3:0] vga_b;
    logic       vga_hsync;
    logic       vga_vsync;
    logic       uart_tx;
    logic       uart_rx;
    logic       ps2_clk;
    logic       ps2_data;
    logic [23:0] sdram_addr;
    logic [31:0] sdram_wdata;
    logic [31:0] sdram_q;
    logic        sdram_we;
    logic        sdram_req;
    logic        sdram_ack;
    logic        sdram_valid;
    wire  [15:0] sdram_dq;
    logic [12:0] sdram_a;
    logic [1:0]  sdram_ba;
    logic        sdram_cke;
    logic        sdram_cs_n;
    logic        sdram_ras_n;
    logic        sdram_cas_n;
    logic        sdram_we_n;
    logic        sdram_dqml;
    logic        sdram_dqmh;
    logic [31:0] dbg_pc;
    logic        dbg_vga_wr;
    integer      uart_count;
    reg [7:0]    uart_bytes [0:255];

    initial begin
        clk = 1'b0;
        ps2_clk = 1'b1;
        ps2_data = 1'b1;
        uart_rx = 1'b1;
        reset = 1'b1;
        uart_count = 0;
    end

    always #5 clk = ~clk;

    task automatic ps2_send_byte(input logic [7:0] data);
        integer bit_index;
        logic parity;
        begin
            parity = 1'b1;

            ps2_clk  = 1'b1;
            ps2_data = 1'b1;
            #30000;

            ps2_data = 1'b0;
            #10000;
            ps2_clk = 1'b0;
            #15000;
            ps2_clk = 1'b1;
            #15000;

            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                ps2_data = data[bit_index];
                parity = parity ^ data[bit_index];
                #10000;
                ps2_clk = 1'b0;
                #15000;
                ps2_clk = 1'b1;
                #15000;
            end

            ps2_data = parity;
            #10000;
            ps2_clk = 1'b0;
            #15000;
            ps2_clk = 1'b1;
            #15000;

            ps2_data = 1'b1;
            #10000;
            ps2_clk = 1'b0;
            #15000;
            ps2_clk = 1'b1;
            #40000;
        end
    endtask

    task automatic ps2_tap_key(input logic [7:0] make_code);
        begin
            ps2_send_byte(make_code);
            #100000;
            ps2_send_byte(8'hF0);
            ps2_send_byte(make_code);
            #150000;
        end
    endtask

    top dut (
        .clk             (clk),
        .reset           (reset),
        .vga_r           (vga_r),
        .vga_g           (vga_g),
        .vga_b           (vga_b),
        .vga_hsync       (vga_hsync),
        .vga_vsync       (vga_vsync),
        .uart_tx_o       (uart_tx),
        .uart_rx_i       (uart_rx),
        .ps2_clk_i       (ps2_clk),
        .ps2_data_i      (ps2_data),
        .jtag_kbd_valid_i(1'b0),
        .jtag_kbd_code_i (8'h00),
        .sdram_addr_o    (sdram_addr),
        .sdram_wdata_o   (sdram_wdata),
        .sdram_we_o      (sdram_we),
        .sdram_req_o     (sdram_req),
        .sdram_ack_i     (sdram_ack),
        .sdram_valid_i   (sdram_valid),
        .vga_sdram_addr_o(),
        .vga_sdram_req_o (),
        .vga_sdram_ack_i (1'b0),
        .vga_sdram_valid_i(1'b0),
        .sdram_q_i       (sdram_q),
        .dbg_pc_o        (dbg_pc),
        .dbg_vga_wr_o    (dbg_vga_wr)
    );

    sdram_ctrl u_sdram_stub (
        .reset      (reset),
        .clk        (clk),
        .addr       (sdram_addr),
        .data       (sdram_wdata),
        .we         (sdram_we),
        .req        (sdram_req),
        .ack        (sdram_ack),
        .valid      (sdram_valid),
        .q          (sdram_q),
        .sdram_a    (sdram_a),
        .sdram_ba   (sdram_ba),
        .sdram_dq   (sdram_dq),
        .sdram_cke  (sdram_cke),
        .sdram_cs_n (sdram_cs_n),
        .sdram_ras_n(sdram_ras_n),
        .sdram_cas_n(sdram_cas_n),
        .sdram_we_n (sdram_we_n),
        .sdram_dqml (sdram_dqml),
        .sdram_dqmh (sdram_dqmh)
    );

    function automatic integer tile_word_addr(input integer tile_x, input integer tile_y);
        integer pixel_x;
        integer pixel_y;
        begin
            pixel_x = tile_x * 8 + 4;
            pixel_y = tile_y * 8 + 4;
            tile_word_addr = pixel_y * 80 + (pixel_x >> 2);
        end
    endfunction

    function automatic logic burst_neighbor_painted;
        begin
            burst_neighbor_painted =
                (u_sdram_stub.mem[tile_word_addr(22, 16)] != 32'h0000_0000) ||
                (u_sdram_stub.mem[tile_word_addr(20, 16)] != 32'h0000_0000) ||
                (u_sdram_stub.mem[tile_word_addr(21, 17)] != 32'h0000_0000) ||
                (u_sdram_stub.mem[tile_word_addr(22, 17)] != 32'h0000_0000) ||
                (u_sdram_stub.mem[tile_word_addr(20, 17)] != 32'h0000_0000) ||
                (u_sdram_stub.mem[tile_word_addr(22, 15)] != 32'h0000_0000);
        end
    endfunction

    task automatic expect_true(input logic condition, input [255:0] message);
        begin
            if (!condition) begin
                $display("FAIL: %0s", message);
                $fatal;
            end
        end
    endtask

    always @(posedge clk) begin
        if (!reset && dut.u_uart.tx_valid && uart_count < 256) begin
            uart_bytes[uart_count] <= dut.u_uart.wdata_i[7:0];
            uart_count <= uart_count + 1;
        end
    end

    initial begin
        repeat (5) @(posedge clk);
        reset = 1'b0;

        wait (uart_count >= 10);
        repeat (5000) @(posedge clk);

        ps2_tap_key(8'h23);
        ps2_tap_key(8'h1B);
        ps2_tap_key(8'h22);

        repeat (20000) @(posedge clk);

        expect_true(uart_bytes[0] == "K", "UART banner should start with K");
        expect_true(uart_bytes[1] == "e", "UART banner should start with Ke");
        expect_true(uart_bytes[2] == "y", "UART banner should start with Key");
        expect_true(uart_bytes[uart_count - 3] == "D", "move right command should be echoed to UART");
        expect_true(uart_bytes[uart_count - 2] == "S", "move down command should be echoed to UART");
        expect_true(uart_bytes[uart_count - 1] == "X", "burst command should be echoed to UART");

        expect_true(u_sdram_stub.mem[tile_word_addr(20, 15)] != 32'h0000_0000,
                    "initial cursor tile should paint the framebuffer");
        expect_true(u_sdram_stub.mem[tile_word_addr(21, 15)] != 32'h0000_0000,
                    "moving right should paint the next tile");
        expect_true(u_sdram_stub.mem[tile_word_addr(21, 16)] != 32'h0000_0000,
                    "moving down should paint the lower tile");

        expect_true(burst_neighbor_painted(),
                "burst should paint at least one neighboring tile");

        $display("PASS");
        $finish;
    end

    initial begin
        #60000000;
        $display("TIMEOUT");
        $fatal;
    end
endmodule