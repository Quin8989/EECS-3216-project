// EECS 3216 - Top-level testbench
`timescale 1ns/1ps

module test_top;
    logic clk, reset;
    logic [3:0] vga_r, vga_g, vga_b;
    logic       vga_hsync, vga_vsync;
    logic uart_tx;
    logic uart_rx;
    // SDRAM bus wires (CPU)
    logic [23:0] sdram_addr;
    logic [31:0] sdram_wdata;
    logic        sdram_we, sdram_req, sdram_ack, sdram_valid;
    wire  [15:0] sdram_dq;
    logic [12:0] sdram_a;
    logic [1:0]  sdram_ba;
    logic        sdram_cke, sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n;
    logic        sdram_dqml, sdram_dqmh;

    // VGA SDRAM bus wires
    logic [23:0] vga_sdram_addr;
    logic        vga_sdram_req, vga_sdram_ack, vga_sdram_valid;

    // Separate read-data buses for CPU and VGA
    logic [31:0] cpu_sdram_q;     // from SDRAM stub → CPU bridge
    logic [31:0] vga_sdram_q;     // from VGA responder → VGA framebuffer

    // UART RX line idles high
    initial begin uart_rx = 1'b1; end

    // Clock generator — 25 MHz to match real FPGA (clk_25m)
    initial clk = 0;
    always #20 clk = ~clk;

    top dut (
        .clk(clk),
        .reset(reset),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .uart_tx_o(uart_tx),
        .uart_rx_i(uart_rx),
        .jtag_kbd_valid_i(1'b0),
        .jtag_kbd_code_i (8'h00),
        .sdram_addr_o (sdram_addr),
        .sdram_wdata_o(sdram_wdata),
        .sdram_we_o   (sdram_we),
        .sdram_req_o  (sdram_req),
        .sdram_ack_i  (sdram_ack),
        .sdram_valid_i(sdram_valid),
        .vga_sdram_addr_o (vga_sdram_addr),
        .vga_sdram_req_o  (vga_sdram_req),
        .vga_sdram_ack_i  (vga_sdram_ack),
        .vga_sdram_valid_i(vga_sdram_valid),
        .sdram_q_i     (cpu_sdram_q),
        .vga_sdram_q_i (vga_sdram_q)
    );

    // ── VGA SDRAM: simple fast responder ──────────────
    // Returns data from the same SDRAM stub memory so VGA sees CPU writes.
    always_ff @(posedge clk) begin
        if (reset) begin
            vga_sdram_ack   <= 1'b0;
            vga_sdram_valid <= 1'b0;
        end else begin
            vga_sdram_ack   <= vga_sdram_req & ~vga_sdram_ack;
            vga_sdram_valid <= vga_sdram_ack;
        end
    end
    always_ff @(posedge clk) begin
        if (vga_sdram_ack)
            vga_sdram_q <= u_sdram_stub.mem[vga_sdram_addr[17:0]];
    end

    sdram_ctrl u_sdram_stub (
        .reset      (reset),
        .clk        (clk),
        .addr       (sdram_addr),
        .data       (sdram_wdata),
        .we         (sdram_we),
        .req        (sdram_req),
        .ack        (sdram_ack),
        .valid      (sdram_valid),
        .q          (cpu_sdram_q),
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

    // ── VGA frame capture (simulation only) ────────────
    // Use hierarchical references to the VGA module's internal counters
    // for pixel-perfect alignment (compensates for registered outputs).
    wire [9:0] vga_h_count = dut.u_vga.h_count;
    wire [9:0] vga_v_count = dut.u_vga.v_count;

    vga_capture #(.MAX_FRAMES(2)) u_vga_cap (
        .clk       (clk),
        .vga_r     (vga_r),
        .vga_g     (vga_g),
        .vga_b     (vga_b),
        .h_count_i (vga_h_count),
        .v_count_i (vga_v_count)
    );

    initial begin
        reset = 1;
        #200;  // hold reset for 5 clock cycles (200ns @ 25MHz)
        reset = 0;
    end

    // Stop on ECALL or timeout
    always @(posedge clk) begin
        if (!reset && dut.u_cpu.insn == 32'h00000073) begin
            if (dut.u_cpu.u_rf.registers_o[3] == 32'd1)
                $display("PASS");
            else
                $display("FAIL (test %0d)", dut.u_cpu.u_rf.registers_o[3] >> 1);
            $finish;
        end
    end

    // Detect infinite loop (same PC for many cycles) and dump state
    reg [31:0] prev_pc;
    reg [31:0] same_pc_count;
    always @(posedge clk) begin
        if (reset) begin
            prev_pc <= 32'h0;
            same_pc_count <= 0;
        end else begin
            if (dut.u_cpu.dbg_pc_o == prev_pc)
                same_pc_count <= same_pc_count + 1;
            else begin
                same_pc_count <= 0;
                prev_pc <= dut.u_cpu.dbg_pc_o;
            end

            if (same_pc_count == 500000) begin
                // 500k cycles @ 25MHz = 20ms — enough for one VGA frame (16.8ms)
                $display("=== CPU halted at PC=%08h (infinite loop) ===", prev_pc);
                // Dump some SDRAM stub contents
                $display("=== SDRAM[0..15] ===");
                begin : sdram_dump
                    integer i;
                    for (i = 0; i < 16; i = i + 1)
                        $display("  SDRAM[%0d] = %08h", i, test_top.u_sdram_stub.mem[i]);
                end
                $display("=== SDRAM[100] = %08h ===", test_top.u_sdram_stub.mem[100]);
                // Dump key CPU registers
                $display("=== CPU Registers ===");
                begin : reg_dump
                    integer i;
                    for (i = 0; i < 32; i = i + 1)
                        if (dut.u_cpu.u_rf.registers_o[i] != 0)
                            $display("  x%0d = %08h", i, dut.u_cpu.u_rf.registers_o[i]);
                end
                $finish;
            end
        end
    end

    initial begin
        #200000000;  // 200 ms — enough for several VGA frames at 25 MHz
        $display("TIMEOUT");
        $finish;
    end
endmodule
