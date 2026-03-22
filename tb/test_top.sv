// EECS 3216 - Top-level testbench
`timescale 1ns/1ps

module test_top;
    logic clk, reset;
    logic uart_tx;
    logic uart_rx;
    logic ps2_clk, ps2_data;

    // PS/2 and UART RX lines idle high
    initial begin ps2_clk = 1'b1; ps2_data = 1'b1; uart_rx = 1'b1; end

    // Clock generator (inlined from clockgen.sv)
    initial clk = 0;
    always #5 clk = ~clk;

    top dut (
        .clk(clk),
        .reset(reset),
        .uart_tx_o(uart_tx),
        .uart_rx_i(uart_rx),
        .ps2_clk_i(ps2_clk),
        .ps2_data_i(ps2_data)
    );

    initial begin
        reset = 1;
        #20;
        reset = 0;
    end

    // Stop on ECALL or timeout
    always @(posedge clk) begin
        if (!reset && dut.u_cpu.insn == 32'h00000073) begin
            if (dut.u_cpu.registers[3] == 32'd1)
                $display("PASS");
            else
                $display("FAIL (test %0d)", dut.u_cpu.registers[3] >> 1);
            $finish;
        end
    end

    initial begin
        #10000000;  // 10 ms
        $display("TIMEOUT");
        $finish;
    end
endmodule
