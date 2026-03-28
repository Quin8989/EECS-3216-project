// wolf3d.c — Fixed-point Wolfenstein 3D-style raycaster
//
// Ported from glouw/littlewolf (MIT licence) to the EECS 3216 bare-metal
// RISC-V SoC.  All floating-point replaced with Q16.16 fixed-point using
// the hardware MUL/MULH/DIV instructions (RV32IM).
//
// Platform:  320×240 RGB332 framebuffer at 0x80000000
//            PS/2 keyboard at 0x40000000
//            25 MHz RV32IM CPU, 64 KB ROM, 8 KB RAM

#include "soc.h"
#include "trig.h"

// ── RGB332 colour helpers ─────────────────────────────────

#define RGB332(r3, g3, b2) ((unsigned char)((r3) << 5 | (g3) << 2 | (b2)))

// ── Fixed-point helpers ───────────────────────────────────

typedef int fx_t;   // Q16.16

// Integer → fixed
#define FX(i)       ((fx_t)((i) << 16))

// Fixed → integer (floor)
#define FX_INT(f)   ((f) >> 16)

// Fixed-point division: a / b  (both Q16.16, result Q16.16).
// Uses a scaled 32-bit divide path to avoid heavy 64-bit soft division
// in the per-column render hot loop on RV32I+Zmmul.
static inline fx_t fx_div(fx_t a, fx_t b) {
    if (b == 0) return a >= 0 ? (fx_t)0x7FFFFFFF : (fx_t)0x80000001;

    int neg = ((a ^ b) < 0);
    unsigned int ua = (a < 0) ? (unsigned int)(-a) : (unsigned int)a;
    unsigned int ub = (b < 0) ? (unsigned int)(-b) : (unsigned int)b;

    // Keep the numerator shift in-range for 32-bit arithmetic.
    while (ua > 0x00FFFFFFu) {
        ua >>= 1;
        ub >>= 1;
        if (ub == 0) ub = 1;
    }

    // Q16.16 scale: (ua << 16) / ub  ≈  (ua << 8) / (ub >> 8)
    unsigned int den = ub >> 8;
    if (den == 0) den = 1;

    unsigned int q = (ua << 8) / den;
    if (q > 0x7FFFFFFFu) q = 0x7FFFFFFFu;

    return neg ? -(fx_t)q : (fx_t)q;
}

// Absolute value
static inline fx_t fx_abs(fx_t v) { return v < 0 ? -v : v; }

// ── Map ───────────────────────────────────────────────────
// 1 = wall, 2 = wall (colour 2), 3 = wall (colour 3), 0 = empty.
// Stored in ROM (.rodata).

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

// Wall colours (indexed by map value):
//   1 = red, 2 = green, 3 = blue.  Dark variants for Y-side hits.
static const unsigned char wall_col_lit[] = {
    RGB332(0,0,0),   // 0 — never drawn
    RGB332(7,0,0),   // 1 — red
    RGB332(0,7,0),   // 2 — green
    RGB332(0,0,3),   // 3 — blue
};
static const unsigned char wall_col_dark[] = {
    RGB332(0,0,0),
    RGB332(4,0,0),   // dark red
    RGB332(0,4,0),   // dark green
    RGB332(0,0,2),   // dark blue
};

static const unsigned char ceil_col  = 0x24;  // dark teal  (RGB332: 001_001_00)
static const unsigned char floor_col = 0x49;  // grey-brown (RGB332: 010_010_01)

// ── Player state ──────────────────────────────────────────

static fx_t pos_x, pos_y;     // Q16.16 map coordinates
static int  angle;            // 0..255 (256 = full revolution)

// ── Framebuffer write ─────────────────────────────────────

// Column descriptor: per-column raycasting result stored in RAM,
// then flushed to the framebuffer in a row-major sweep (no RMW).
struct col_desc {
    short draw_start;
    short draw_end;
    unsigned char col;       // wall colour
};
static struct col_desc col_buf[FB_WIDTH];  // 320 × 5 = 1600 bytes

// Flush col_buf to the back framebuffer row by row.
// For each row, determine each pixel's colour from the column descriptors,
// pack 4 pixels per 32-bit word, and issue a single framebuffer write per word.
// This eliminates all read-modify-write traffic (76,800 reads → 0 reads,
// 76,800 writes → 19,200 writes).
// Optimized: pre-cache column descriptors to reduce memory loads per row.
static void flush_framebuffer(volatile unsigned int *fb) {
    for (int y = 0; y < FB_HEIGHT; y++) {
        unsigned int *row = (unsigned int *)fb + y * (FB_WIDTH / 4);
        for (int wx = 0; wx < FB_WIDTH; wx += 4) {
            // Cache column descriptors for 4 adjacent pixels
            const struct col_desc *c0 = &col_buf[wx];
            const struct col_desc *c1 = &col_buf[wx + 1];
            const struct col_desc *c2 = &col_buf[wx + 2];
            const struct col_desc *c3 = &col_buf[wx + 3];
            
            // Determine pixel colors with minimal branching
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
}

// ── DDA Raycaster ─────────────────────────────────────────
//
// Standard DDA grid traversal — one ray per screen column.
// The camera plane is perpendicular to the direction vector.
//
// Camera model (Q16.16):
//   dir_x = cos(angle),  dir_y = sin(angle)
//   plane_x = -0.66 * sin(angle),  plane_y = 0.66 * cos(angle)
//   (FOV ≈ 66 degrees — the classic Wolfenstein FOV)

#define FOV_SCALE  43254   // 0.66 in Q16.16

// Wait for vertical blanking to start — reduces tearing.
static inline void wait_for_vblank(void) {
#ifndef SIM_MODE
    // Wait for a clean 0->1 transition so each render starts on a
    // fresh vblank edge rather than mid-blanking.
    while (VGA_STATUS_REG & 1)
        ;
    while (!(VGA_STATUS_REG & 1))
        ;
#endif
}

static inline int map_is_empty(fx_t nx, fx_t ny) {
    int mx = FX_INT(nx);
    int my = FX_INT(ny);

    if ((unsigned)mx >= MAP_W || (unsigned)my >= MAP_H)
        return 0;
    return world_map[my][mx] == 0;
}

static void render_frame(void) {
    fx_t dir_x   = fp_cos(angle);
    fx_t dir_y   = fp_sin(angle);
    fx_t plane_x = -FP_MUL(FOV_SCALE, dir_y);
    fx_t plane_y =  FP_MUL(FOV_SCALE, dir_x);

    for (int x = 0; x < FB_WIDTH; x++) {
        // Camera x-coordinate in range [-1, 1]
        fx_t camera_x = ((2 * x) << 16) / FB_WIDTH - FP_ONE;
        // Ray direction
        fx_t ray_dx = dir_x + FP_MUL(plane_x, camera_x);
        fx_t ray_dy = dir_y + FP_MUL(plane_y, camera_x);

        // Current map cell
        int map_x = FX_INT(pos_x);
        int map_y = FX_INT(pos_y);

        // Delta distance: |1 / ray_component| in Q16.16
        // Clamped so we never divide by zero.
        fx_t abs_dx = fx_abs(ray_dx);
        fx_t abs_dy = fx_abs(ray_dy);
        fx_t delta_dist_x = (abs_dx < 16) ? (fx_t)0x7FFFFFFF : fx_div(FP_ONE, abs_dx);
        fx_t delta_dist_y = (abs_dy < 16) ? (fx_t)0x7FFFFFFF : fx_div(FP_ONE, abs_dy);

        // Step direction and initial side distance
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

        // DDA loop — step through grid until we hit a wall
        int hit = 0;
        int side = 0;  // 0 = X-side hit, 1 = Y-side hit
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
                hit = 1;  // out of bounds — treat as wall
        }

        // Perpendicular distance (avoids fisheye)
        fx_t perp_dist;
        if (side == 0)
            perp_dist = side_dist_x - delta_dist_x;
        else
            perp_dist = side_dist_y - delta_dist_y;
        if (perp_dist < 256) perp_dist = 256;  // clamp to avoid huge lines

        // Wall height on screen
        int line_height = FX_INT(fx_div(FX(FB_HEIGHT), perp_dist));
        int draw_start  = (FB_HEIGHT - line_height) / 2;
        int draw_end    = (FB_HEIGHT + line_height) / 2;
        if (draw_start < 0)          draw_start = 0;
        if (draw_end   > FB_HEIGHT)  draw_end   = FB_HEIGHT;

        // Store column descriptor (drawn later in row-major flush)
        col_buf[x].draw_start = (short)draw_start;
        col_buf[x].draw_end   = (short)draw_end;
        col_buf[x].col        = side ? wall_col_dark[hit] : wall_col_lit[hit];
    }

    // Wait for vblank to minimise visible tearing, then flush.
    wait_for_vblank();
    flush_framebuffer(FB_BASE);
}

// ── Keyboard handling ─────────────────────────────────────
// Input arrives as ASCII bytes via JTAG keyboard injection.
// Each byte is a one-shot action (no key-release tracking).

// Movement speed (Q16.16): ~0.08 per step
#define MOVE_SPEED  5243
// Rotation speed: 3 angle steps per keypress (≈4.2 degrees)
#define ROT_SPEED   3

// Drain all pending ASCII bytes and apply movement immediately.
static void poll_and_move(void) {
    fx_t dx = fp_cos(angle);
    fx_t dy = fp_sin(angle);

    while (KBD_STATUS & 1) {
        unsigned int c = KBD_DATA & 0xFF;
        fx_t nx, ny;
        switch (c) {
            case 'w': case 'W':  // forward
                nx = pos_x + FP_MUL(dx, MOVE_SPEED);
                ny = pos_y + FP_MUL(dy, MOVE_SPEED);
                if (map_is_empty(nx, ny)) { pos_x = nx; pos_y = ny; }
                break;
            case 's': case 'S':  // backward
                nx = pos_x - FP_MUL(dx, MOVE_SPEED);
                ny = pos_y - FP_MUL(dy, MOVE_SPEED);
                if (map_is_empty(nx, ny)) { pos_x = nx; pos_y = ny; }
                break;
            case 'a': case 'A':  // strafe left
                nx = pos_x + FP_MUL(dy, MOVE_SPEED);
                ny = pos_y - FP_MUL(dx, MOVE_SPEED);
                if (map_is_empty(nx, ny)) { pos_x = nx; pos_y = ny; }
                break;
            case 'd': case 'D':  // strafe right
                nx = pos_x - FP_MUL(dy, MOVE_SPEED);
                ny = pos_y + FP_MUL(dx, MOVE_SPEED);
                if (map_is_empty(nx, ny)) { pos_x = nx; pos_y = ny; }
                break;
            case ',': case '<':  // rotate left
                angle = (angle - ROT_SPEED) & 0xFF;
                dx = fp_cos(angle); dy = fp_sin(angle);
                break;
            case '.': case '>':  // rotate right
                angle = (angle + ROT_SPEED) & 0xFF;
                dx = fp_cos(angle); dy = fp_sin(angle);
                break;
        }
    }
}

// ── Main ──────────────────────────────────────────────────

int main(void) {
    uart_puts("WOLF3D raycaster\r\n");

    // Starting position: open area near top-left, facing right (angle 0)
    pos_x = FX(2) + FP_HALF;  // 2.5
    pos_y = FX(2) + FP_HALF;  // 2.5
    angle = 0;

    // In simulation: render one frame and exit.
    // On FPGA: loop forever.
#ifdef SIM_MODE
    render_frame();
    // Print diagnostics for center column
    uart_puts("col160: ds=");
    uart_put_hex32(col_buf[160].draw_start);
    uart_puts(" de=");
    uart_put_hex32(col_buf[160].draw_end);
    uart_puts(" col=");
    uart_put_hex32(col_buf[160].col);
    uart_puts("\r\n");
    uart_puts("Frame done\r\n");
    return 1;  // PASS — triggers ECALL in crt0
#else
    while (1) {
        poll_and_move();
        render_frame();
    }
    return 0;
#endif
}
