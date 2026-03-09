// EECS 3216 - Top-level testbench
`timescale 1ns/1ps

module test_top;
    logic clk, reset;

    clockgen clkgen (.clk(clk));

    top dut (
        .clk(clk),
        .reset(reset)
    );

    initial begin
        reset = 1;
        #20;
        reset = 0;
    end

    // Stop on ECALL or timeout
    always @(posedge clk) begin
        if (!reset && dut.u_cpu.insn == 32'h00000073) begin
            if (dut.u_cpu.u_regfile.registers[3] == 32'd1)
                $display("PASS");
            else
                $display("FAIL (test %0d)", dut.u_cpu.u_regfile.registers[3] >> 1);
            $finish;
        end
    end

    initial begin
        #500000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
