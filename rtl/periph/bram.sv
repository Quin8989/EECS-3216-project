// Byte-wide synchronous RAM — Intel M9K inference template
//
// Supports single-port (default) or true dual-port mode.
// Uses Intel's recommended coding style for reliable M9K inference.
//
// Single-port: Port A is read/write, Port B signals are unused
// Dual-port:   Port A is read/write (CPU), Port B is read-only (scanout)

module bram #(
    parameter int  DEPTH     = 2048,
    parameter bit  DUAL_PORT = 0
)(
    input  logic                     clk,
    // Port A (read/write)
    input  logic [$clog2(DEPTH)-1:0] addr_a,
    input  logic [7:0]               wdata_a,
    input  logic                     we_a,
    output logic [7:0]               rdata_a,
    // Port B (read-only, active only when DUAL_PORT=1)
    input  logic [$clog2(DEPTH)-1:0] addr_b,
    output logic [7:0]               rdata_b
);

    (* ramstyle = "M9K, no_rw_check" *) reg [7:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (we_a)
            mem[addr_a] <= wdata_a;
        rdata_a <= mem[addr_a];
    end

    generate
        if (DUAL_PORT) begin : gen_port_b
            always_ff @(posedge clk)
                rdata_b <= mem[addr_b];
        end else begin : gen_no_port_b
            assign rdata_b = '0;
        end
    endgenerate

endmodule : bram
