module register_file #(
    parameter int DWIDTH = 32
)(
    input  logic              clk,
    input  logic              rst,
    input  logic [4:0]        rs1_i,
    input  logic [4:0]        rs2_i,
    input  logic [4:0]        rd_i,
    input  logic [DWIDTH-1:0] datawb_i,
    input  logic              regwren_i,
    output logic [DWIDTH-1:0] rs1data_o,
    output logic [DWIDTH-1:0] rs2data_o
);

    logic [DWIDTH-1:0] registers [0:31];

    assign rs1data_o = registers[rs1_i];
    assign rs2data_o = registers[rs2_i];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; i++)
                registers[i] <= '0;
        end else if (regwren_i && (rd_i != 5'd0)) begin
            registers[rd_i] <= datawb_i;
        end
    end

endmodule : register_file
