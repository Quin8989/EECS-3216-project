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

    integer vga_frames_written;
    logic   capture_frames;
    logic [31:0] capture_max_frames;

    vga_capture #(.MAX_FRAMES(30)) u_vga_cap (
        .clk              (clk),
        .capture_en_i     (capture_frames),
        .capture_max_frames_i(capture_max_frames),
        .vga_r            (vga_r),
        .vga_g            (vga_g),
        .vga_b            (vga_b),
        .h_count_i        (vga_h_count),
        .v_count_i        (vga_v_count),
        .frames_written_o (vga_frames_written)
    );

    // +CAPTURE_FRAMES=1 enables PPM frame dumps (used by gallery flow)
    integer capture_frames_i;
    integer capture_max_frames_i;
    initial begin
        if (!$value$plusargs("CAPTURE_FRAMES=%d", capture_frames_i))
            capture_frames = 1'b0;
        else
            capture_frames = (capture_frames_i != 0);

        if (!$value$plusargs("CAPTURE_MAX_FRAMES=%d", capture_max_frames_i))
            capture_max_frames = 32'd0;
        else if (capture_max_frames_i < 0)
            capture_max_frames = 32'd0;
        else
            capture_max_frames = capture_max_frames_i[31:0];
    end

    // +MIN_FRAMES=N delays ecall/loop termination until N frames captured
    integer min_frames;
    logic   stop_after_min_frames;
    initial begin
        if (!$value$plusargs("MIN_FRAMES=%d", min_frames))
            min_frames = 0;  // default: no minimum (normal test behaviour)

        // +STOP_AFTER_MIN_FRAMES=1 exits simulation as soon as MIN_FRAMES are captured.
        // Useful for fast frame-gallery generation without waiting for timeout/ecall.
        if ($test$plusargs("STOP_AFTER_MIN_FRAMES"))
            stop_after_min_frames = 1'b1;
        else
            stop_after_min_frames = 1'b0;
    end

    // Optional early exit once enough frames are captured.
    always @(posedge clk) begin
        if (!reset && stop_after_min_frames && (min_frames > 0)
            && (vga_frames_written >= min_frames)) begin
            $display("FRAME_CAPTURE_DONE (%0d frames)", vga_frames_written);
            $finish;
        end
    end

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

    // ── Stop on ECALL (delayed until MIN_FRAMES captured) ─
    always @(posedge clk) begin
        if (!reset && dut.u_cpu.insn == 32'h00000073
            && vga_frames_written >= min_frames) begin
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

            if (same_pc_count == 500000
                && vga_frames_written >= min_frames) begin
                $display("=== CPU halted at PC=%08h (infinite loop) ===", prev_pc);
                $finish;
            end
        end
    end

    // ── Global timeout (configurable via +TIMEOUT_MS=N) ─
    integer timeout_ms;
    initial begin
        if (!$value$plusargs("TIMEOUT_MS=%d", timeout_ms))
            timeout_ms = 200;
        #(timeout_ms * 1_000_000);
        $display("TIMEOUT");
        $finish;
    end
endmodule
