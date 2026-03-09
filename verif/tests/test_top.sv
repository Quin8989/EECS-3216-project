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
endmodule
