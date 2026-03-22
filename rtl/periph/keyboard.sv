// PS/2 Keyboard peripheral
//
// Memory map (base 0x4000_0000):
//   +0x0  KBD_DATA    (read: next scancode from FIFO, advances read pointer)
//   +0x4  KBD_STATUS  (read: bit 0 = scancode available in FIFO)
//
// PS/2 receiver and 16-entry FIFO inlined below.

module keyboard (
    input  logic        clk,
    input  logic        rst,

    // CPU bus
    input  logic [31:0] addr_i,
    input  logic        ren_i,
    output logic [31:0] rdata_o,

    // PS/2 pins (directly from FPGA pads)
    input  logic        ps2_clk_i,
    input  logic        ps2_data_i
);

    localparam ADDR_DATA   = 3'h0;
    localparam ADDR_STATUS = 3'h4;
    localparam FIFO_DEPTH  = 16;
    localparam PTR_W       = $clog2(FIFO_DEPTH);  // 4

    logic [2:0] offset;
    assign offset = addr_i[2:0];

    // ── PS/2 receiver (inlined from ps2_rx.sv) ────

    // Synchronise PS/2 signals (2-FF)
    logic [2:0] ps2_clk_sync;
    logic [1:0] ps2_data_sync;

    always_ff @(posedge clk) begin
        if (rst) begin
            ps2_clk_sync  <= 3'b111;
            ps2_data_sync <= 2'b11;
        end else begin
            ps2_clk_sync  <= {ps2_clk_sync[1:0], ps2_clk_i};
            ps2_data_sync <= {ps2_data_sync[0], ps2_data_i};
        end
    end

    logic ps2_clk_fall;
    assign ps2_clk_fall = ps2_clk_sync[2] & ~ps2_clk_sync[1];

    logic ps2_data_s;
    assign ps2_data_s = ps2_data_sync[1];

    // Shift register
    logic [10:0] ps2_shift;
    logic [3:0]  ps2_bit_cnt;
    logic [16:0] ps2_watchdog;

    logic [7:0] rx_code;
    logic       rx_valid;

    always_ff @(posedge clk) begin
        if (rst) begin
            ps2_shift    <= '0;
            ps2_bit_cnt  <= '0;
            rx_valid     <= 1'b0;
            rx_code      <= '0;
            ps2_watchdog <= '0;
        end else begin
            rx_valid <= 1'b0;

            if (ps2_clk_fall) begin
                ps2_watchdog <= '0;
                ps2_shift    <= {ps2_data_s, ps2_shift[10:1]};
                ps2_bit_cnt  <= ps2_bit_cnt + 4'd1;

                if (ps2_bit_cnt == 4'd10) begin
                    rx_code     <= ps2_shift[8:1];
                    rx_valid    <= 1'b1;
                    ps2_bit_cnt <= '0;
                end
            end else begin
                if (ps2_bit_cnt != 0) begin
                    ps2_watchdog <= ps2_watchdog + 17'd1;
                    if (ps2_watchdog[16])
                        ps2_bit_cnt <= '0;
                end
            end
        end
    end

    // ── 16-entry scancode FIFO ────────────────────
    logic [7:0]     fifo [0:FIFO_DEPTH-1];
    logic [PTR_W:0] wr_ptr, rd_ptr;   // extra bit for full/empty
    logic           fifo_full, fifo_empty;

    assign fifo_full  = (wr_ptr[PTR_W] != rd_ptr[PTR_W]) &&
                        (wr_ptr[PTR_W-1:0] == rd_ptr[PTR_W-1:0]);
    assign fifo_empty = (wr_ptr == rd_ptr);

    // Write side: push new scancodes
    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr <= '0;
        end else if (rx_valid && !fifo_full) begin
            fifo[wr_ptr[PTR_W-1:0]] <= rx_code;
            wr_ptr <= wr_ptr + (PTR_W+1)'(1);
        end
    end

    // Read side: advance pointer when CPU reads DATA
    always_ff @(posedge clk) begin
        if (rst) begin
            rd_ptr <= '0;
        end else if (ren_i && offset == ADDR_DATA && !fifo_empty) begin
            rd_ptr <= rd_ptr + (PTR_W+1)'(1);
        end
    end

    // ── Read mux ──────────────────────────────────
    always_comb begin
        case (offset)
            ADDR_DATA:   rdata_o = fifo_empty ? 32'h0 : {24'b0, fifo[rd_ptr[PTR_W-1:0]]};
            ADDR_STATUS: rdata_o = {31'b0, ~fifo_empty};
            default:     rdata_o = 32'h0;
        endcase
    end

endmodule : keyboard
