// VGA frame capture — writes PPM images using the VGA module's internal
// h_count / v_count counters for pixel-perfect alignment.
//
// Simulation-only.  Connect h_count_i / v_count_i via hierarchical
// references in the testbench (e.g. dut.u_vga.h_count).
//
// Because vga_fb registers its outputs, the pixel data on vga_r/g/b
// lags h_count by one clock.  We compensate: when h_count_i == 1,
// vga_r/g/b hold the pixel for x = 0, and so on.
//
// Parameters:
//   MAX_FRAMES — stop after this many frames (0 = unlimited)

`timescale 1ns/1ps

module vga_capture #(
    parameter int MAX_FRAMES = 2
)(
    input logic       clk,
    input logic [3:0] vga_r,
    input logic [3:0] vga_g,
    input logic [3:0] vga_b,
    input logic [9:0] h_count_i,
    input logic [9:0] v_count_i
);

    localparam int H_VISIBLE = 640;
    localparam int V_VISIBLE = 480;

    reg [7:0] fb_r [0:H_VISIBLE*V_VISIBLE-1];
    reg [7:0] fb_g [0:H_VISIBLE*V_VISIBLE-1];
    reg [7:0] fb_b [0:H_VISIBLE*V_VISIBLE-1];

    reg [9:0]  prev_v;
    integer    frame_count;

    initial begin
        prev_v      = 0;
        frame_count = 0;
    end

    always @(posedge clk) begin
        prev_v <= v_count_i;

        // Capture active pixels (shifted by 1 to compensate for registered output)
        if (h_count_i >= 1 && h_count_i <= H_VISIBLE && v_count_i < V_VISIBLE) begin
            fb_r[v_count_i * H_VISIBLE + (h_count_i - 1)] <= {vga_r, vga_r};
            fb_g[v_count_i * H_VISIBLE + (h_count_i - 1)] <= {vga_g, vga_g};
            fb_b[v_count_i * H_VISIBLE + (h_count_i - 1)] <= {vga_b, vga_b};
        end

        // Frame boundary: v_count just left the visible region
        if (prev_v == 10'd479 && v_count_i == 10'd480) begin
            if (MAX_FRAMES == 0 || frame_count < MAX_FRAMES) begin
                write_ppm(frame_count);
                frame_count <= frame_count + 1;
            end
        end
    end

    task automatic write_ppm(input integer fnum);
        integer f, i;
        reg [8*64-1:0] fname;
        begin
            $sformat(fname, "vga_frame%0d.ppm", fnum);
            f = $fopen(fname, "wb");
            if (f != 0) begin
                $fwrite(f, "P6\n640 480\n255\n");
                for (i = 0; i < H_VISIBLE * V_VISIBLE; i = i + 1)
                    $fwrite(f, "%c%c%c", fb_r[i], fb_g[i], fb_b[i]);
                $fclose(f);
                $display("VGA_CAPTURE: wrote %0s (frame %0d)", fname, fnum);
            end else begin
                $display("VGA_CAPTURE: ERROR opening %0s", fname);
            end
        end
    endtask

endmodule
