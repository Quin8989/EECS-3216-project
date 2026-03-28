// True dual-port byte-wide synchronous RAM.
// Port A is CPU-facing read/write; port B is scanout read-only.
module byte_ram_tdp #(
    parameter int DEPTH = 2048
)(
    input  logic                     clk,
    input  logic [$clog2(DEPTH)-1:0] addr_a,
    input  logic [7:0]               wdata_a,
    input  logic                     we_a,
    output logic [7:0]               rdata_a,
    input  logic [$clog2(DEPTH)-1:0] addr_b,
    output logic [7:0]               rdata_b
);
    (* ramstyle = "M9K, no_rw_check" *) reg [7:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (we_a)
            mem[addr_a] <= wdata_a;
        rdata_a <= mem[addr_a];
        rdata_b <= mem[addr_b];
    end
endmodule
