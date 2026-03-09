// PS/2 Keyboard peripheral
//
// Memory map (base 0x4000_0000):
//   +0x0  KBD_DATA    (read: 8-bit scancode, reading clears valid flag)
//   +0x4  KBD_STATUS  (read: bit 0 = key_valid — a scancode is available)
//
// Instantiates ps2_rx to deserialize the PS/2 protocol.
// A 1-deep register holds the latest scancode.

module keyboard (
    input  logic        clk,
    input  logic        rst,

    // CPU bus
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        wen_i,
    input  logic        ren_i,
    output logic [31:0] rdata_o,

    // PS/2 pins (directly from FPGA pads)
    input  logic        ps2_clk_i,
    input  logic        ps2_data_i
);

    localparam ADDR_DATA   = 3'h0;
    localparam ADDR_STATUS = 3'h4;

    logic [2:0] offset;
    assign offset = addr_i[2:0];

    // ── PS/2 receiver ─────────────────────────────
    logic [7:0] rx_code;
    logic       rx_valid;

    ps2_rx u_rx (
        .clk        (clk),
        .rst        (rst),
        .ps2_clk_i  (ps2_clk_i),
        .ps2_data_i (ps2_data_i),
        .code_o     (rx_code),
        .valid_o    (rx_valid)
    );

    // ── Scancode register + valid flag ────────────
    logic [7:0] scan_reg;
    logic       key_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            scan_reg  <= '0;
            key_valid <= 1'b0;
        end else begin
            // Latch new scancode
            if (rx_valid) begin
                scan_reg  <= rx_code;
                key_valid <= 1'b1;
            end
            // CPU reads DATA → clear valid
            if (ren_i && offset == ADDR_DATA) begin
                key_valid <= 1'b0;
            end
        end
    end

    // ── Read mux ──────────────────────────────────
    always_comb begin
        case (offset)
            ADDR_DATA:   rdata_o = {24'b0, scan_reg};
            ADDR_STATUS: rdata_o = {31'b0, key_valid};
            default:     rdata_o = 32'h0;
        endcase
    end

endmodule : keyboard
