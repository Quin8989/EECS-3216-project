// Simulation-only stub for sdram_ctrl (replaces the VHDL wrapper + SDRAM controller).
// Implements a simple 32-bit memory array with req/ack/valid handshake.
// NOT cycle-accurate — returns data in ~3 cycles instead of ~8.
// Sufficient for functional verification of the CPU ↔ SDRAM bridge.

`ifdef SYNTHESIS
// Never used in synthesis — the real VHDL wrapper is used instead.
`else

module sdram_ctrl (
    input  logic        reset,
    input  logic        clk,
    input  logic [23:0] addr,
    input  logic [31:0] data,
    input  logic        we,
    input  logic        req,
    output logic        ack,
    output logic        valid,
    output logic [31:0] q,
    output logic [12:0] sdram_a,
    output logic [1:0]  sdram_ba,
    inout  wire  [15:0] sdram_dq,
    output logic        sdram_cke,
    output logic        sdram_cs_n,
    output logic        sdram_ras_n,
    output logic        sdram_cas_n,
    output logic        sdram_we_n,
    output logic        sdram_dqml,
    output logic        sdram_dqmh
);

    // 256K words = 1 MB of simulated SDRAM (enough for testing)
    logic [31:0] mem [0:262143];

    typedef enum logic [1:0] {IDLE, ACK, RESPOND} state_t;
    state_t state;

    logic [22:0] addr_r;
    logic [31:0] data_r;
    logic        we_r;

    // Tie off unused SDRAM physical pins in simulation
    assign sdram_a     = '0;
    assign sdram_ba    = '0;
    assign sdram_dq    = '0;  // stub drives 0; real controller drives z (tristate)
    assign sdram_cke   = 1'b1;
    assign sdram_cs_n  = 1'b1;
    assign sdram_ras_n = 1'b1;
    assign sdram_cas_n = 1'b1;
    assign sdram_we_n  = 1'b1;
    assign sdram_dqml  = 1'b0;
    assign sdram_dqmh  = 1'b0;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            ack   <= 1'b0;
            valid <= 1'b0;
            q     <= '0;
        end else begin
            ack   <= 1'b0;
            valid <= 1'b0;

            case (state)
                IDLE: begin
                    if (req) begin
                        addr_r <= addr;
                        data_r <= data;
                        we_r   <= we;
                        state  <= ACK;
                    end
                end

                ACK: begin
                    ack <= 1'b1;
                    if (we_r) begin
                        mem[addr_r[17:0]] <= data_r;
                        state <= IDLE;
                    end else begin
                        state <= RESPOND;
                    end
                end

                RESPOND: begin
                    q     <= mem[addr_r[17:0]];
                    valid <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

`endif
