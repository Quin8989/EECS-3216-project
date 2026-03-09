// VGA timing generator — 640×480 @ 60 Hz
//
// Active: 640 × 480 pixels
// Total:  800 × 525 pixels (including blanking)
// Pixel clock: 25.175 MHz (25 MHz is close enough)
//
// Horizontal: 640 vis + 16 front + 96 sync + 48 back = 800
// Vertical:   480 vis + 10 front +  2 sync + 33 back = 525

module vga_timing (
    input  logic       clk_pixel,
    input  logic       rst,
    output logic [9:0] h_count,     // 0–799
    output logic [9:0] v_count,     // 0–524
    output logic       hsync,
    output logic       vsync,
    output logic       active       // high when in visible area
);

    // Horizontal parameters
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK; // 800

    // Vertical parameters
    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK; // 525

    // Counters
    always_ff @(posedge clk_pixel) begin
        if (rst) begin
            h_count <= '0;
            v_count <= '0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                h_count <= '0;
                if (v_count == V_TOTAL - 1)
                    v_count <= '0;
                else
                    v_count <= v_count + 1'b1;
            end else begin
                h_count <= h_count + 1'b1;
            end
        end
    end

    // Sync signals (active low)
    assign hsync  = ~(h_count >= H_VISIBLE + H_FRONT &&
                      h_count <  H_VISIBLE + H_FRONT + H_SYNC);
    assign vsync  = ~(v_count >= V_VISIBLE + V_FRONT &&
                      v_count <  V_VISIBLE + V_FRONT + V_SYNC);

    // Active video region
    assign active = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

endmodule : vga_timing
