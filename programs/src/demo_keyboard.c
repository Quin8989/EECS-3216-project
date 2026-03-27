// demo_keyboard.c — Pinball game for DE10-Lite FPGA
//
// A ball bounces around under gravity. Two flippers at the bottom
// launch it back up. Bumpers in the play field bounce the ball.
//
// Controls (ASCII bytes via JTAG keyboard injection):
//   A = left flipper
//   D = right flipper
//   W = launch / reset ball
//
// 320x240 RGB332 framebuffer, ~60 Hz vblank.

#include "soc.h"

#define RGB332(r3, g3, b2) ((unsigned char)((r3) << 5 | (g3) << 2 | (b2)))

// ASCII key codes (keyboard_inject.py sends ASCII bytes)
#define KEY_W     'w'
#define KEY_A     'a'
#define KEY_D     'd'

// ── Colors ──
#define COL_BG      RGB332(0,0,1)   // dark blue
#define COL_BALL    RGB332(7,7,3)   // white
#define COL_WALL    RGB332(3,3,1)   // grey
#define COL_BUMP1   RGB332(7,0,0)   // red
#define COL_BUMP2   RGB332(0,7,0)   // green
#define COL_BUMP3   RGB332(7,7,0)   // yellow
#define COL_FLIPL   RGB332(7,0,3)   // magenta
#define COL_FLIPR   RGB332(0,0,3)   // blue
#define COL_SCORE   RGB332(7,5,0)   // orange
#define COL_DRAIN   RGB332(2,0,0)   // dark red

// ── Q8.8 fixed-point ──
#define FP 8
#define TO_FP(v) ((v) << FP)
#define FROM_FP(v) ((v) >> FP)
#define GRAVITY    40    // ~0.16 px/frame²

// ── Play field ──
#define FIELD_L  40          // left wall x
#define FIELD_R  280         // right wall x
#define FIELD_T  10          // top wall y
#define BALL_R   4           // ball radius (drawn as square for speed)
#define FLIPPER_Y  215       // flipper vertical position
#define FLIPPER_W  40
#define FLIPPER_H  6
#define FLIPL_X    70        // left flipper x
#define FLIPR_X    210       // right flipper x
#define DRAIN_Y    235       // ball dies below here

// ── Bumpers (rectangular) ──
struct bumper { short x, y, w, h; unsigned char col; };
static const struct bumper bumpers[] = {
    { 100,  60, 14, 14, COL_BUMP1 },
    { 200,  60, 14, 14, COL_BUMP2 },
    { 150,  40, 14, 14, COL_BUMP3 },
    { 120, 110, 14, 14, COL_BUMP2 },
    { 180, 110, 14, 14, COL_BUMP1 },
    { 150, 160, 14, 14, COL_BUMP3 },
    {  80, 160, 14, 14, COL_BUMP1 },
    { 220, 160, 14, 14, COL_BUMP2 },
};
#define NUM_BUMPERS (sizeof(bumpers)/sizeof(bumpers[0]))

// ── Drawing helpers ──
static void put_pixel(int x, int y, unsigned char color) {
    if ((unsigned)x >= FB_WIDTH || (unsigned)y >= FB_HEIGHT) return;
    volatile unsigned int *row = FB_BASE + y * (FB_WIDTH / 4);
    int wi = x >> 2;
    int bp = (x & 3) * 8;
    unsigned int val = row[wi];
    val &= ~(0xFFu << bp);
    val |= (unsigned int)color << bp;
    row[wi] = val;
}

static void draw_rect(int rx, int ry, int w, int h, unsigned char color) {
    for (int y = ry; y < ry + h; y++)
        for (int x = rx; x < rx + w; x++)
            put_pixel(x, y, color);
}

static void fill_screen(unsigned char color) {
    unsigned int c4 = color | (color << 8) | (color << 16) | (color << 24);
    for (int y = 0; y < FB_HEIGHT; y++) {
        volatile unsigned int *row = FB_BASE + y * (FB_WIDTH / 4);
        for (int x = 0; x < FB_WIDTH / 4; x++)
            row[x] = c4;
    }
}

static void wait_vblank(void) {
    while (VGA_STATUS_REG & 1) ;
    while (!(VGA_STATUS_REG & 1));
}

// ── Score display: draw horizontal bar at top ──
static void draw_score(int score) {
    int bar_w = score;
    if (bar_w > FIELD_R - FIELD_L - 4) bar_w = FIELD_R - FIELD_L - 4;
    if (bar_w > 0)
        draw_rect(FIELD_L + 2, FIELD_T + 2, bar_w, 4, COL_SCORE);
}

int main(void) {
    // Ball state (Q8.8)
    int bx = TO_FP(160);
    int by = TO_FP(200);
    int bvx = 0;
    int bvy = 0;
    int launched = 0;
    int score = 0;

    // Flipper state: 1 = up (active), 0 = down
    int flip_l = 0;
    int flip_r = 0;

    while (1) {
        // ── Input ──
        flip_l = 0;
        flip_r = 0;
        // Drain all pending keys
        while (KBD_STATUS & 1) {
            unsigned int code = KBD_DATA & 0xFF;
            if (code == KEY_A || code == 'A') flip_l = 1;
            if (code == KEY_D || code == 'D') flip_r = 1;
            if (code == KEY_W || code == 'W') {
                if (!launched) {
                    // Launch from starting position
                    bx = TO_FP(160);
                    by = TO_FP(200);
                    bvx = TO_FP(1);
                    bvy = -TO_FP(4);
                    launched = 1;
                } else {
                    // Reset
                    bx = TO_FP(160);
                    by = TO_FP(200);
                    bvx = 0;
                    bvy = 0;
                    launched = 0;
                    score = 0;
                }
            }
        }

        // ── Physics ──
        if (launched) {
            bvy += GRAVITY;
            bx += bvx;
            by += bvy;

            int px = FROM_FP(bx);
            int py = FROM_FP(by);

            // Wall bounces
            if (px - BALL_R < FIELD_L) {
                bx = TO_FP(FIELD_L + BALL_R);
                bvx = -bvx * 3 / 4;
            }
            if (px + BALL_R > FIELD_R) {
                bx = TO_FP(FIELD_R - BALL_R);
                bvx = -bvx * 3 / 4;
            }
            if (py - BALL_R < FIELD_T) {
                by = TO_FP(FIELD_T + BALL_R);
                bvy = -bvy * 3 / 4;
            }

            // Bumper collisions
            px = FROM_FP(bx);
            py = FROM_FP(by);
            for (int i = 0; i < (int)NUM_BUMPERS; i++) {
                const struct bumper *bp = &bumpers[i];
                if (px + BALL_R > bp->x && px - BALL_R < bp->x + bp->w &&
                    py + BALL_R > bp->y && py - BALL_R < bp->y + bp->h) {
                    int cx = bp->x + (bp->w >> 1);
                    int cy = bp->y + (bp->h >> 1);
                    int dx = px - cx;
                    int dy = py - cy;
                    if (dx < 0) dx = -dx;
                    if (dy < 0) dy = -dy;
                    if (dx > dy) {
                        bvx = -bvx;
                        if (px < cx) bx = TO_FP(bp->x - BALL_R);
                        else         bx = TO_FP(bp->x + bp->w + BALL_R);
                    } else {
                        bvy = -bvy;
                        if (py < cy) by = TO_FP(bp->y - BALL_R);
                        else         by = TO_FP(bp->y + bp->h + BALL_R);
                    }
                    score += 5;
                    break;
                }
            }

            // Flipper collision
            px = FROM_FP(bx);
            py = FROM_FP(by);

            if (flip_l && py + BALL_R >= FLIPPER_Y && py + BALL_R <= FLIPPER_Y + FLIPPER_H + 6
                && px + BALL_R > FLIPL_X && px - BALL_R < FLIPL_X + FLIPPER_W) {
                bvy = -TO_FP(4);
                bvx = -TO_FP(1) + (bvx >> 1);
                by = TO_FP(FLIPPER_Y - BALL_R - 1);
                score += 2;
            }
            if (flip_r && py + BALL_R >= FLIPPER_Y && py + BALL_R <= FLIPPER_Y + FLIPPER_H + 6
                && px + BALL_R > FLIPR_X && px - BALL_R < FLIPR_X + FLIPPER_W) {
                bvy = -TO_FP(4);
                bvx = TO_FP(1) + (bvx >> 1);
                by = TO_FP(FLIPPER_Y - BALL_R - 1);
                score += 2;
            }

            // Ball drained
            if (FROM_FP(by) > DRAIN_Y) {
                launched = 0;
                bx = TO_FP(160);
                by = TO_FP(200);
                bvx = 0;
                bvy = 0;
            }
        }

        // ── Draw ──
        wait_vblank();
        fill_screen(COL_BG);

        // Walls
        draw_rect(FIELD_L - 4, FIELD_T, 4, DRAIN_Y - FIELD_T, COL_WALL);
        draw_rect(FIELD_R, FIELD_T, 4, DRAIN_Y - FIELD_T, COL_WALL);
        draw_rect(FIELD_L - 4, FIELD_T - 4, FIELD_R - FIELD_L + 8, 4, COL_WALL);

        // Drain zone
        draw_rect(FIELD_L, DRAIN_Y, FIELD_R - FIELD_L, 2, COL_DRAIN);

        // Bumpers
        for (int i = 0; i < (int)NUM_BUMPERS; i++)
            draw_rect(bumpers[i].x, bumpers[i].y, bumpers[i].w, bumpers[i].h, bumpers[i].col);

        // Flippers (raised when active)
        int fl_y = flip_l ? FLIPPER_Y - 4 : FLIPPER_Y;
        int fr_y = flip_r ? FLIPPER_Y - 4 : FLIPPER_Y;
        draw_rect(FLIPL_X, fl_y, FLIPPER_W, FLIPPER_H, COL_FLIPL);
        draw_rect(FLIPR_X, fr_y, FLIPPER_W, FLIPPER_H, COL_FLIPR);

        // Ball
        if (launched) {
            int px = FROM_FP(bx) - BALL_R;
            int py = FROM_FP(by) - BALL_R;
            draw_rect(px, py, BALL_R * 2, BALL_R * 2, COL_BALL);
        } else {
            draw_rect(160 - BALL_R, 200 - BALL_R, BALL_R * 2, BALL_R * 2, COL_BALL);
        }

        // Score bar
        draw_score(score);
    }

    return 0;
}
