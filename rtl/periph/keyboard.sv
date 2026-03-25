module keyboard (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        wen_i,
    input  logic        ren_i,
    output logic [31:0] rdata_o,
    input  logic        jtag_inject_valid_i,
    input  logic [7:0]  jtag_inject_code_i
);

    localparam ADDR_DATA   = 3'h0;
    localparam ADDR_STATUS = 3'h4;

    logic [2:0] offset;
    assign offset = addr_i[2:0];

    logic [7:0] scan_reg;
    logic       key_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            scan_reg  <= '0;
            key_valid <= 1'b0;
        end else begin
            if (jtag_inject_valid_i) begin
                scan_reg  <= jtag_inject_code_i;
                key_valid <= 1'b1;
            end else if (ren_i && offset == ADDR_DATA) begin
                key_valid <= 1'b0;
            end
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