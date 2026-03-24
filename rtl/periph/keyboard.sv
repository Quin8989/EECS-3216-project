module keyboard #(
    parameter bit AUTO_DEMO = 1'b0
) (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] addr_i,
    input  logic [31:0] wdata_i,
    input  logic        wen_i,
    input  logic        ren_i,
    output logic [31:0] rdata_o,
    input  logic        ps2_clk_i,
    input  logic        ps2_data_i,
    input  logic        jtag_inject_valid_i,
    input  logic [7:0]  jtag_inject_code_i
);

    localparam ADDR_DATA   = 3'h0;
    localparam ADDR_STATUS = 3'h4;

    logic [2:0] offset;
    assign offset = addr_i[2:0];

    logic [7:0] rx_code;
    logic       rx_valid;
    logic [7:0] event_code;
    logic       event_valid;

    ps2_rx u_rx (
        .clk        (clk),
        .rst        (rst),
        .ps2_clk_i  (ps2_clk_i),
        .ps2_data_i (ps2_data_i),
        .code_o     (rx_code),
        .valid_o    (rx_valid)
    );

    localparam int unsigned STEP_CYCLES = 8_000_000;

    logic [22:0] step_counter;
    logic [3:0]  action_index;
    logic [7:0]  synth_code;
    logic        synth_valid;

    always_comb begin
        case (action_index)
            4'd0: synth_code = 8'h1D; // W
            4'd1: synth_code = 8'h1D; // W
            4'd2: synth_code = 8'h23; // D
            4'd3: synth_code = 8'h23; // D
            4'd4: synth_code = 8'h15; // Q
            4'd5: synth_code = 8'h22; // X
            4'd6: synth_code = 8'h24; // E
            4'd7: synth_code = 8'h1B; // S
            4'd8: synth_code = 8'h1B; // S
            4'd9: synth_code = 8'h1C; // A
            4'd10: synth_code = 8'h1C; // A
            4'd11: synth_code = 8'h22; // X
            4'd12: synth_code = 8'h23; // D
            4'd13: synth_code = 8'h23; // D
            4'd14: synth_code = 8'h23; // D
            default: synth_code = 8'h21; // C
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            step_counter <= '0;
            action_index <= '0;
            synth_valid  <= 1'b0;
        end else begin
            synth_valid <= 1'b0;

            if (AUTO_DEMO && !key_valid) begin
                if (step_counter == STEP_CYCLES - 1) begin
                    step_counter <= '0;
                    synth_valid  <= 1'b1;
                    if (action_index == 4'd15)
                        action_index <= '0;
                    else
                        action_index <= action_index + 4'd1;
                end else begin
                    step_counter <= step_counter + 23'd1;
                end
            end
        end
    end

    assign event_code  = AUTO_DEMO ? synth_code : rx_code;
    assign event_valid = AUTO_DEMO ? synth_valid : rx_valid;

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
            end else if (event_valid) begin
                scan_reg  <= event_code;
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