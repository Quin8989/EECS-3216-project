// UART peripheral (sim stub)
//
// Register map:
//   +0x0  TX_DATA  (write: send byte, read: last RX byte)
//   +0x4  STATUS   (read: bit 0 = tx_ready, bit 1 = rx_valid)
//
// In simulation, writes to TX_DATA print the character via $write.
// For FPGA, replace the $write with a real TX shift register.

module uart (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        wen_i,
    input  logic        ren_i,
    output logic [31:0] rdata_o
);

    localparam ADDR_TX_DATA = 3'h0;  // offset +0
    localparam ADDR_STATUS  = 3'h4;  // offset +4

    logic [2:0] offset;
    assign offset = addr_i[2:0];

    // Status: always ready in sim
    logic tx_ready;
    assign tx_ready = 1'b1;

    // TX: print character in simulation
    always_ff @(posedge clk) begin
        if (!rst && wen_i && offset == ADDR_TX_DATA)
            $write("%c", wdata_i[7:0]);
    end

    // Read mux
    always_comb begin
        case (offset)
            ADDR_STATUS: rdata_o = {30'b0, 1'b0, tx_ready};  // bit0=tx_ready
            default:     rdata_o = 32'h0;
        endcase
    end

endmodule : uart
