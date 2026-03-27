// Single byte-wide synchronous RAM — matches Intel recommended template
module byte_ram #(
    parameter int DEPTH = 2048
)(
    input  logic                    clk,
    input  logic [$clog2(DEPTH)-1:0] addr,
    input  logic [7:0]             wdata,
    input  logic                   we,
    output logic [7:0]             rdata
);
    (* ramstyle = "M9K, no_rw_check" *) reg [7:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we) mem[addr] <= wdata;
        rdata <= mem[addr];
    end
endmodule
