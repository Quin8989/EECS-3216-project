// Clock generator
// Produces a free-running clock with configurable period.
module clockgen #(
    parameter HALF_PERIOD = 5
)(
    output logic clk
);
    initial clk = 0;
    always #HALF_PERIOD clk = ~clk;
endmodule : clockgen
