// Clock generator
`timescale 1ns/1ps

module clockgen #(
    parameter HALF_PERIOD = 5
)(
    output logic clk
);
    initial clk = 0;
    always #HALF_PERIOD clk = ~clk;
endmodule : clockgen
