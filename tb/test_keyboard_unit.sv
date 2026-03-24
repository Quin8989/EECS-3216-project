`timescale 1ns/1ps

module test_keyboard_unit;
    logic clk;
    logic rst;
    logic [31:0] addr_i;
    logic [31:0] wdata_i;
    logic        wen_i;
    logic        ren_i;
    logic [31:0] rdata_o;
    logic        ps2_clk;
    logic        ps2_data;

    keyboard dut (
        .clk        (clk),
        .rst        (rst),
        .addr_i     (addr_i),
        .wdata_i    (wdata_i),
        .wen_i      (wen_i),
        .ren_i      (ren_i),
        .rdata_o    (rdata_o),
        .ps2_clk_i  (ps2_clk),
        .ps2_data_i (ps2_data)
    );

    initial clk = 1'b0;
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

    task automatic read_reg(input logic [31:0] addr, output logic [31:0] data);
        begin
            addr_i = addr;
            ren_i  = 1'b1;
            @(posedge clk);
            #1;
            data = rdata_o;
            ren_i  = 1'b0;
            addr_i = 32'h0;
            @(posedge clk);
        end
    endtask

    task automatic expect_equal(input logic [31:0] actual, input logic [31:0] expected, input [255:0] message);
        begin
            if (actual !== expected) begin
                $display("FAIL: %0s (expected %08h, got %08h)", message, expected, actual);
                $fatal;
            end
        end
    endtask

    task automatic wait_for_scan_code(input logic [7:0] expected_code, input [255:0] message);
        integer cycles;
        logic matched;
        begin
            matched = 1'b0;
            for (cycles = 0; cycles < 200000; cycles = cycles + 1) begin
                @(posedge clk);
                if (dut.key_valid && dut.scan_reg == expected_code[7:0]) begin
                    matched = 1'b1;
                    cycles = 200000;
                end
            end

            if (!matched) begin
                $display("FAIL: %0s", message);
                $fatal;
            end
        end
    endtask

    logic [31:0] status_value;
    logic [31:0] data_value;

    initial begin
        addr_i   = 32'h0;
        wdata_i  = 32'h0;
        wen_i    = 1'b0;
        ren_i    = 1'b0;
        ps2_clk  = 1'b1;
        ps2_data = 1'b1;
        rst      = 1'b1;

        repeat (5) @(posedge clk);
        rst = 1'b0;

        ps2_send_byte(8'h1C);
        wait_for_scan_code(8'h1C, "make code should be captured");

        read_reg(32'h4000_0004, status_value);
        expect_equal(status_value, 32'h0000_0001, "status set after make code");

        read_reg(32'h4000_0000, data_value);
        expect_equal(data_value, 32'h0000_001C, "data register returns received scan code");

        read_reg(32'h4000_0004, status_value);
        expect_equal(status_value, 32'h0000_0000, "status clears after data read");

        ps2_send_byte(8'hF0);
        ps2_send_byte(8'h1C);
        wait_for_scan_code(8'h1C, "second byte after break prefix should be captured");

        read_reg(32'h4000_0000, data_value);
        expect_equal(data_value, 32'h0000_001C, "last received byte is preserved across prefix handling in software layer");

        $display("PASS");
        $finish;
    end
endmodule