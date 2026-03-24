module keyboard (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        wen_i,
    input  logic        ren_i,
    output logic [31:0] rdata_o,
    input  logic        ps2_clk_i,
    input  logic        ps2_data_i
);

    localparam ADDR_DATA   = 3'h0;
    localparam ADDR_STATUS = 3'h4;

    logic [2:0] offset;
    assign offset = addr_i[2:0];

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

    logic [7:0] scan_reg;
    logic       key_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            scan_reg  <= '0;
            key_valid <= 1'b0;
        end else begin
            if (rx_valid) begin
                scan_reg  <= rx_code;
                key_valid <= 1'b1;
            end

            if (ren_i && offset == ADDR_DATA)
                key_valid <= 1'b0;
        end
    end

    always_comb begin
        case (offset)
            ADDR_DATA:   rdata_o = {24'b0, scan_reg};
            ADDR_STATUS: rdata_o = {31'b0, key_valid};
            default:     rdata_o = 32'h0;
        endcase
    end

endmodule : keyboard