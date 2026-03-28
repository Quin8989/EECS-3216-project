// EECS 3216 — Top-level testbench
`timescale 1ns/1ps

module test_top;
    logic clk, reset;
    logic [3:0] vga_r, vga_g, vga_b;
    logic       vga_hsync, vga_vsync, vga_blanking;
    logic       uart_tx;
    logic [31:0] dbg_pc;

    // Clock generator — 25 MHz (40 ns period)
    initial clk = 0;
    always #20 clk = ~clk;

    // UART RX idles high
    logic uart_rx = 1'b1;

    top dut (
        .clk              (clk),
        .reset            (reset),
        .vga_r            (vga_r),
        .vga_g            (vga_g),
        .vga_b            (vga_b),
        .vga_hsync        (vga_hsync),
        .vga_vsync        (vga_vsync),
        .vga_blanking_o   (vga_blanking),
        .uart_tx_o        (uart_tx),
        .uart_rx_i        (uart_rx),
        .jtag_kbd_valid_i (1'b0),
        .jtag_kbd_code_i  (8'h00),
        .dbg_pc_o         (dbg_pc)
    );

    // ── VGA frame capture ─────────────────────────────
    wire [9:0] vga_h_count = dut.u_vga.h_count;
    wire [9:0] vga_v_count = dut.u_vga.v_count;

    vga_capture #(.MAX_FRAMES(8)) u_vga_cap (
        .clk       (clk),
        .vga_r     (vga_r),
        .vga_g     (vga_g),
        .vga_b     (vga_b),
        .h_count_i (vga_h_count),
        .v_count_i (vga_v_count)
    );

    // ── VCD waveform dump (enabled by +TRACE plusarg) ──
    initial begin
        if ($test$plusargs("TRACE")) begin
            $dumpfile("trace.vcd");
            $dumpvars(0, test_top);
        end
    end

    // ── Reset ─────────────────────────────────────────
    initial begin
        reset = 1;
        #200;
        reset = 0;
    end

    // ── Stop on ECALL ─────────────────────────────────
    always @(posedge clk) begin
        if (!reset && dut.u_cpu.insn == 32'h00000073) begin
            if (dut.u_cpu.u_rf.registers_o[3] == 32'd1)
                $display("PASS");
            else
                $display("FAIL (test %0d)", dut.u_cpu.u_rf.registers_o[3] >> 1);
            $finish;
        end
    end

    // ── Infinite-loop detector ────────────────────────
    reg [31:0] prev_pc;
    reg [31:0] same_pc_count;
    always @(posedge clk) begin
        if (reset) begin
            prev_pc       <= 32'h0;
            same_pc_count <= 0;
        end else begin
            if (dbg_pc == prev_pc)
                same_pc_count <= same_pc_count + 1;
            else begin
                same_pc_count <= 0;
                prev_pc <= dbg_pc;
            end

            if (same_pc_count == 500000) begin
                $display("=== CPU halted at PC=%08h (infinite loop) ===", prev_pc);
                $finish;
            end
        end
    end

    // ── Global timeout ────────────────────────────────
    initial begin
        #200000000;  // 200 ms
        $display("TIMEOUT");
        $finish;
    end
endmodule
