// test_wolf3d_debug5.c — Test ROM size threshold.
//
// This is debug2 (which works) but with a dummy const array to push
// total ROM image past 1100 words (to match debug3/wolf3d size).
// If this breaks → ROM addressing issue on FPGA.
// If this works → code logic issue in debug3, not ROM size.

#include "soc.h"
#include "trig.h"

#define RGB332(r3, g3, b2) ((unsigned char)((r3) << 5 | (g3) << 2 | (b2)))

typedef int fx_t;
#define FX(i)       ((fx_t)((i) << 16))
#define FX_INT(f)   ((f) >> 16)

static inline fx_t fx_div(fx_t a, fx_t b) {
    if (b == 0) return a >= 0 ? (fx_t)0x7FFFFFFF : (fx_t)0x80000001;
    return (fx_t)(((long long)a << 16) / (long long)b);
}
static inline fx_t fx_abs(fx_t v) { return v < 0 ? -v : v; }

#define MAP_W 16
#define MAP_H 16
static const unsigned char world_map[MAP_H][MAP_W] = {
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,2,2,0,0,0,0,0,3,3,0,0,0,1},
    {1,0,0,2,0,0,0,0,0,0,0,3,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,3,3,3,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,3,0,3,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,3,0,3,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,2,0,0,0,0,0,0,0,2,0,0,0,1},
    {1,0,0,2,2,0,0,0,0,0,2,2,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
};
static const unsigned char wall_col_lit[] = {
    RGB332(0,0,0), RGB332(7,0,0), RGB332(0,7,0), RGB332(0,0,3),
};
static const unsigned char wall_col_dark[] = {
    RGB332(0,0,0), RGB332(4,0,0), RGB332(0,4,0), RGB332(0,0,2),
};
static const unsigned char ceil_col  = 0x24;
static const unsigned char floor_col = 0x49;

// Dummy padding to push ROM past 1100 words (matching debug3 size).
// 512 ints = 2048 bytes = 512 words of padding.
// debug2 is 647 words, so 647+512 = 1159 words (> 1111 of debug3).
static volatile const int rom_padding[512] = {
    [0] = 0xDEADBEEF, [1] = 0xCAFEBABE, [2] = 0x12345678,
    [255] = 0xABCD1234, [511] = 0x99887766,
};

struct col_desc {
    short draw_start;
    short draw_end;
    unsigned char col;
};
static struct col_desc col_buf[FB_WIDTH];

#define FOV_SCALE  43254

static void fill_rows(int y_start, int y_end, unsigned int color4) {
    for (int y = y_start; y < y_end; y++) {
        unsigned int *row = (unsigned int *)FB_BASE + y * (FB_WIDTH / 4);
        for (int x = 0; x < FB_WIDTH / 4; x++)
            row[x] = color4;
    }
}

int main(void) {
    // Anti-optimization: read from padding so it's not optimized away
    volatile int sink = rom_padding[0] + rom_padding[255] + rom_padding[511];
    (void)sink;

    // Phase 1: Fill entire screen RED
    fill_rows(0, 240, 0xE0E0E0E0);

    // Phase 2: Mark rows 0-9 GREEN = "fill done"
    fill_rows(0, 10, 0x1C1C1C1C);

    // Phase 3: Raycaster (one frame) — identical to debug2
    fx_t pos_x = FX(2) + (1 << 15);
    fx_t pos_y = FX(2) + (1 << 15);
    int angle = 0;

    fx_t dir_x   = fp_cos(angle);
    fx_t dir_y   = fp_sin(angle);
    fx_t plane_x = -FP_MUL(FOV_SCALE, dir_y);
    fx_t plane_y =  FP_MUL(FOV_SCALE, dir_x);

    for (int x = 0; x < FB_WIDTH; x++) {
        fx_t camera_x = ((2 * x) << 16) / FB_WIDTH - (1 << 16);
        fx_t ray_dx = dir_x + FP_MUL(plane_x, camera_x);
        fx_t ray_dy = dir_y + FP_MUL(plane_y, camera_x);

        int map_x = FX_INT(pos_x);
        int map_y = FX_INT(pos_y);

        fx_t abs_dx = fx_abs(ray_dx);
        fx_t abs_dy = fx_abs(ray_dy);
        fx_t delta_dist_x = (abs_dx < 16) ? (fx_t)0x7FFFFFFF : fx_div((1 << 16), abs_dx);
        fx_t delta_dist_y = (abs_dy < 16) ? (fx_t)0x7FFFFFFF : fx_div((1 << 16), abs_dy);

        int step_x, step_y;
        fx_t side_dist_x, side_dist_y;

        if (ray_dx < 0) {
            step_x = -1;
            side_dist_x = FP_MUL(pos_x - FX(map_x), delta_dist_x);
        } else {
            step_x = 1;
            side_dist_x = FP_MUL(FX(map_x + 1) - pos_x, delta_dist_x);
        }
        if (ray_dy < 0) {
            step_y = -1;
            side_dist_y = FP_MUL(pos_y - FX(map_y), delta_dist_y);
        } else {
            step_y = 1;
            side_dist_y = FP_MUL(FX(map_y + 1) - pos_y, delta_dist_y);
        }

        int hit = 0;
        int side = 0;
        while (!hit) {
            if (side_dist_x < side_dist_y) {
                side_dist_x += delta_dist_x;
                map_x += step_x;
                side = 0;
            } else {
                side_dist_y += delta_dist_y;
                map_y += step_y;
                side = 1;
            }
            if ((unsigned)map_x < MAP_W && (unsigned)map_y < MAP_H)
                hit = world_map[map_y][map_x];
            else
                hit = 1;
        }

        fx_t perp_dist;
        if (side == 0)
            perp_dist = side_dist_x - delta_dist_x;
        else
            perp_dist = side_dist_y - delta_dist_y;
        if (perp_dist < 256) perp_dist = 256;

        int line_height = FX_INT(fx_div(FX(FB_HEIGHT), perp_dist));
        int draw_start  = (FB_HEIGHT - line_height) / 2;
        int draw_end    = (FB_HEIGHT + line_height) / 2;
        if (draw_start < 0)          draw_start = 0;
        if (draw_end   > FB_HEIGHT)  draw_end   = FB_HEIGHT;

        col_buf[x].draw_start = (short)draw_start;
        col_buf[x].draw_end   = (short)draw_end;
        col_buf[x].col        = side ? wall_col_dark[hit] : wall_col_lit[hit];
    }

    // Phase 4: Mark rows 10-19 BLUE = "raycaster done"
    fill_rows(10, 20, 0x03030303);

    // Phase 5: Flush col_buf to framebuffer
    for (int y = 0; y < FB_HEIGHT; y++) {
        unsigned int *row = (unsigned int *)FB_BASE + y * (FB_WIDTH / 4);
        for (int wx = 0; wx < FB_WIDTH; wx += 4) {
            const struct col_desc *c0 = &col_buf[wx];
            const struct col_desc *c1 = &col_buf[wx + 1];
            const struct col_desc *c2 = &col_buf[wx + 2];
            const struct col_desc *c3 = &col_buf[wx + 3];

            unsigned char p0 = (y < c0->draw_start) ? ceil_col :
                               (y < c0->draw_end) ? c0->col : floor_col;
            unsigned char p1 = (y < c1->draw_start) ? ceil_col :
                               (y < c1->draw_end) ? c1->col : floor_col;
            unsigned char p2 = (y < c2->draw_start) ? ceil_col :
                               (y < c2->draw_end) ? c2->col : floor_col;
            unsigned char p3 = (y < c3->draw_start) ? ceil_col :
                               (y < c3->draw_end) ? c3->col : floor_col;

            row[wx >> 2] = p0 | (p1 << 8) | (p2 << 16) | (p3 << 24);
        }
    }

    // Phase 6: Mark rows 230-239 YELLOW = "all done"
    fill_rows(230, 240, 0xFCFCFCFC);

    while (1) ;
    return 0;
}
