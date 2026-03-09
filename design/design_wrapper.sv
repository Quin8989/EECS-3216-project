`include "probes.svh"

// Top-level wrapper exposing only clock and reset
module design_wrapper (
    input logic clk,
    input logic reset
);
    `TOP_MODULE core (
        .clk(clk),
        .reset(reset)
    );
endmodule : design_wrapper
