// demo_uart_timer_vga.c — EECS 3216 SoC feature demonstration
//
// Exercises all four available hardware features:
//
//   VGA framebuffer  — renders an animated plasma pattern (320x240 RGB332)
//   Timer            — drives the animation frame counter via compare-match
//   UART             — prints frame count + timing info at each frame
//   MUL instruction  — used in plasma colour calculations
//
// Each frame: fill the 320x240 framebuffer, wait for the timer to reach
// the next 25 MHz tick target, then print a one-line status over UART.
// Watch the VGA output for the animated pattern and the serial terminal
// for the frame log.
//
// Baud: 115200 8N1.  Connect a terminal to the UART TX pin.

#include "soc.h"

// ── Framebuffer helpers ───────────────────────────────────────────────────────

static inline unsigned char rgb332(unsigned int r, unsigned int g, unsigned int b) {
    return (unsigned char)(((r & 0x7) << 5) | ((g & 0x7) << 2) | (b & 0x3));
}

// Simple integer sine approximation using a 64-entry lookup table (Q8 fixed-point).
// Values span 0..255 (unsigned), representing sin mapped to [0,255].
static const unsigned char sin_lut[64] = {
    128,140,152,165,176,187,197,206,214,221,227,231,235,237,238,237,
    235,231,227,221,214,206,197,187,176,165,152,140,128,116,104, 91,
     80, 69, 59, 50, 42, 35, 29, 25, 21, 19, 18, 19, 21, 25, 29, 35,
     42, 50, 59, 69, 80, 91,104,116,128,140,152,165,176,187,197,206
};

// sin_u8(angle): angle is an arbitrary int, wrapped to 0..63.
static inline unsigned int sin_u8(int angle) {
    return sin_lut[(unsigned int)angle & 63];
}

// ── Plasma rendering ──────────────────────────────────────────────────────────
//
// Classic 2D plasma: blend several sine waves with different spatial frequencies
// and a time-varying phase offset.  Uses MUL for the combined wave sum scaling.

static void render_frame(unsigned int t) {
    // Phase offsets derived from the frame counter t (different speeds).
    int ph1 = (int)(t >> 1);          // slow
    int ph2 = (int)(t * 3 >> 2);      // medium (uses MUL via compiler)
    int ph3 = (int)(t);               // full speed

    for (int y = 0; y < FB_HEIGHT; y++) {
        int wave_y = (int)sin_u8(y + ph1);   // vertical slow wave

        for (int x = 0; x < FB_WIDTH; x += 4) {
            unsigned int word = 0;

            for (int i = 0; i < 4; i++) {
                int px = x + i;

                // Three sine waves summed (result 0..765)
                int wx = (int)sin_u8(px + ph2);
                int wd = (int)sin_u8((px + y) + ph3);
                int raw = wave_y + wx + wd;          // 0..765

                // Twist the colour using the live frame counter via MUL.
                // (t & 0xFF) is runtime-variable, so the MUL instruction is emitted.
                // This makes each frame's palette shift smoothly over time.
                unsigned int twist = (unsigned int)((t & 0xFF) * (unsigned int)raw) >> 8;
                unsigned int scaled = (twist + (unsigned int)raw) >> 1;  // blend, 0..511

                // Map to RGB332: upper bits → R, mid → G, lower → B
                unsigned int r = (scaled >> 6) & 0x7;
                unsigned int g = (scaled >> 3) & 0x7;
                unsigned int b = (scaled >> 0) & 0x3;

                word |= (unsigned int)rgb332(r, g, b) << (i * 8);
            }

            FB_BASE[(y * (FB_WIDTH / 4)) + (x / 4)] = word;
        }
    }
}

// ── Timer helpers ─────────────────────────────────────────────────────────────

// Wait until the timer reaches `target` (handles 32-bit wraparound).
static void timer_wait_until(unsigned int target) {
    // Set the compare register so TIMER_STATUS fires when we arrive.
    TIMER_CMP = target;
    // Clear any stale match flag.
    TIMER_STATUS = 1;
    // Spin until the W1C flag sets.
    while (!(TIMER_STATUS & 1))
        ;
    // Clear the flag.
    TIMER_STATUS = 1;
}

// ── UART frame log ────────────────────────────────────────────────────────────

static void print_frame_info(unsigned int frame, unsigned int elapsed_cycles) {
    uart_puts("Frame ");
    uart_put_dec(frame);
    uart_puts("  cycles=");
    uart_put_dec(elapsed_cycles);
    // Approximate ms: elapsed / 25000 ≈ elapsed >> 14 (close enough for display)
    unsigned int ms = elapsed_cycles >> 14;
    uart_puts("  (~");
    uart_put_dec(ms);
    uart_puts(" ms)\r\n");
}

// ── Main ──────────────────────────────────────────────────────────────────────

// Frame period: 25 MHz / 10 frames per second = 2,500,000 cycles.
#define CYCLES_PER_FRAME 2500000u
#define NUM_FRAMES       100

int main(void) {
    uart_puts("\r\n=== EECS 3216 SoC Demo: UART + Timer + VGA + MUL ===\r\n");
    uart_puts("Rendering ");
    uart_put_dec(NUM_FRAMES);
    uart_puts(" frames at 10 fps onto 320x240 VGA framebuffer.\r\n\r\n");

    unsigned int next_tick = TIMER_COUNT + CYCLES_PER_FRAME;

    for (unsigned int frame = 0; frame < NUM_FRAMES; frame++) {
        unsigned int t0 = TIMER_COUNT;

        render_frame(frame);

        unsigned int t1 = TIMER_COUNT;
        unsigned int render_cycles = t1 - t0;

        print_frame_info(frame, render_cycles);

        // Wait for the next frame boundary so timing is locked to the timer.
        timer_wait_until(next_tick);
        next_tick += CYCLES_PER_FRAME;
    }

    uart_puts("\r\nDone. Framebuffer holds last frame — check VGA output.\r\n");

    // Halt — spin forever.
    while (1)
        ;
    return 0;
}
