// EECS 3216 - Top-level testbench
`timescale 1ns/1ps

module top;
    logic clk, reset;

    clockgen clkgen (.clk(clk));

    design_wrapper dut (
        .clk(clk),
        .reset(reset)
    );

    initial begin
        reset = 1;
        #20;
        reset = 0;

        #(`TIMEOUT * 10);
        $display("TIMEOUT reached");
        $finish;
    end
endmodule
