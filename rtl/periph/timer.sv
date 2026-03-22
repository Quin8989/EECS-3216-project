// Timer peripheral
//
// Register map (base 0x2000_0000):
//   +0x0  COUNT   (read: current 32-bit counter value, write: reset to 0)
//   +0x4  CMP     (read/write: compare value)
//   +0x8  STATUS  (read: bit 0 = match flag; write 1 to bit 0 clears it)
//
// Counter increments every clock cycle.  When COUNT == CMP, the match
// flag latches high and stays high until software clears it.

module timer (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        wen_i,
    output logic [31:0] rdata_o
);

    localparam ADDR_COUNT  = 4'h0;
    localparam ADDR_CMP    = 4'h4;
    localparam ADDR_STATUS = 4'h8;

    logic [3:0] offset;
    assign offset = addr_i[3:0];

    logic [31:0] count_q;
    logic [31:0] cmp_q;
    logic        match_q;

    // Counter
    always_ff @(posedge clk) begin
        if (rst)
            count_q <= 32'h0;
        else if (wen_i && offset == ADDR_COUNT)
            count_q <= 32'h0;          // write to COUNT resets it
        else
            count_q <= count_q + 32'h1;
    end

    // Compare register
    always_ff @(posedge clk) begin
        if (rst)
            cmp_q <= 32'hFFFF_FFFF;    // default: never match
        else if (wen_i && offset == ADDR_CMP)
            cmp_q <= wdata_i;
    end

    // Match flag
    always_ff @(posedge clk) begin
        if (rst)
            match_q <= 1'b0;
        else if (wen_i && offset == ADDR_STATUS && wdata_i[0])
            match_q <= 1'b0;           // write 1 to clear
        else if (count_q == cmp_q)
            match_q <= 1'b1;
    end

    // Read mux
    always_comb begin
        case (offset)
            ADDR_COUNT:  rdata_o = count_q;
            ADDR_CMP:    rdata_o = cmp_q;
            ADDR_STATUS: rdata_o = {31'b0, match_q};
            default:     rdata_o = 32'h0;
        endcase
    end

endmodule : timer
