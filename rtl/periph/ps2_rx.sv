module ps2_rx (
    input  logic       clk,
    input  logic       rst,
    input  logic       ps2_clk_i,
    input  logic       ps2_data_i,
    output logic [7:0] code_o,
    output logic       valid_o
);

    logic [2:0] clk_sync;
    logic [1:0] data_sync;

    always_ff @(posedge clk) begin
        if (rst) begin
            clk_sync  <= 3'b111;
            data_sync <= 2'b11;
        end else begin
            clk_sync  <= {clk_sync[1:0], ps2_clk_i};
            data_sync <= {data_sync[0], ps2_data_i};
        end
    end

    logic ps2_clk_fall;
    logic ps2_data;
    assign ps2_clk_fall = clk_sync[2] & ~clk_sync[1];
    assign ps2_data = data_sync[1];

    logic [10:0] shift_reg;
    logic [10:0] shift_next;
    logic [3:0]  bit_cnt;
    logic [16:0] watchdog;

    assign shift_next = {ps2_data, shift_reg[10:1]};

    always_ff @(posedge clk) begin
        if (rst) begin
            shift_reg <= '0;
            bit_cnt   <= '0;
            valid_o   <= 1'b0;
            code_o    <= '0;
            watchdog  <= '0;
        end else begin
            valid_o <= 1'b0;

            if (ps2_clk_fall) begin
                watchdog  <= '0;
                shift_reg <= shift_next;

                if (bit_cnt == 4'd10) begin
                    if ((shift_next[10] == 1'b1) && (shift_next[0] == 1'b0)) begin
                        code_o  <= shift_next[8:1];
                        valid_o <= 1'b1;
                    end
                    bit_cnt <= '0;
                end else begin
                    bit_cnt <= bit_cnt + 4'd1;
                end
            end else if (bit_cnt != 0) begin
                watchdog <= watchdog + 17'd1;
                if (watchdog[16]) begin
                    bit_cnt <= '0;
                end
            end
        end
    end

endmodule : ps2_rx