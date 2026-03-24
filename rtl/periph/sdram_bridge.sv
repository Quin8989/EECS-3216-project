// Simple SDRAM bridge: req/ack/valid protocol adapter.
// CPU is stalled (mem_stall) so addresses remain stable - no latching needed.
// Returns raw 32-bit words; byte extraction done in top.sv.

module sdram_bridge (
    input  logic        clk,
    input  logic        reset,

    // CPU side
    input  logic        access_i,   // SDRAM selected & (ren | wen)
    input  logic        write_i,    // 1=write, 0=read
    input  logic [23:0] addr_i,     // word address
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,    // raw 32-bit word
    output logic        stall_o,

    // SDRAM controller side
    output logic [23:0] ctrl_addr,
    output logic [31:0] ctrl_data,
    output logic        ctrl_we,
    output logic        ctrl_req,
    input  logic        ctrl_ack,
    input  logic        ctrl_valid,
    input  logic [31:0] ctrl_q
);

    typedef enum logic [1:0] {IDLE, WAIT_ACK, WAIT_DATA} state_t;
    state_t state;

    logic [31:0] rdata_r;
    logic        done;

    assign stall_o = (access_i && state == IDLE && !done) || (state != IDLE);
    assign rdata_o = rdata_r;

    // Pass-through to controller
    assign ctrl_addr = addr_i;
    assign ctrl_data = wdata_i;
    assign ctrl_we   = write_i;

    always_ff @(posedge clk) begin
        if (reset) begin
            state    <= IDLE;
            ctrl_req <= 1'b0;
            done     <= 1'b0;
            rdata_r  <= '0;
        end else begin
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (access_i && !done) begin
                        ctrl_req <= 1'b1;
                        state    <= WAIT_ACK;
                    end
                end

                WAIT_ACK: begin
                    if (ctrl_ack) begin
                        ctrl_req <= 1'b0;
                        if (write_i) begin
                            done  <= 1'b1;
                            state <= IDLE;
                        end else begin
                            state <= WAIT_DATA;
                        end
                    end
                end

                WAIT_DATA: begin
                    if (ctrl_valid) begin
                        rdata_r <= ctrl_q;
                        done    <= 1'b1;
                        state   <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
