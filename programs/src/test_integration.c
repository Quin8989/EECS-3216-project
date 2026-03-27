// Integration Test: Combined SoC exercise
//
// Exercises ALL major peripherals and CPU features in a single program:
//   1. Timer — measure elapsed cycles of a computation
//   2. Arithmetic — MUL + DIV in a real algorithm (iterative sqrt)
//   3. On-chip RAM — store computed results and read them back
//   4. VGA framebuffer — write a computed pattern derived from the results
//   5. UART — print progress (implicit via test framework)

#include "soc.h"

#define FB     FB_BASE
#define ROW_W  (FB_WIDTH / 4)

// Small scratch buffer in on-chip RAM (0x02 region)
#define SCRATCH ((volatile unsigned int *)(RAM_BASE + 4096))

// ── Integer square root via Newton's method (uses MUL + DIV) ─
static unsigned int isqrt(unsigned int n) {
    if (n == 0) return 0;
    unsigned int x = n;
    unsigned int y = (x + 1) / 2;
    while (y < x) {
        x = y;
        y = (x + n / x) / 2;
    }
    return x;
}

// ── 1. Timed computation ────────────────────────────────────
static int test_timed_sqrt(void) {
    TIMER_COUNT = 0;
    unsigned int sum = 0;
    for (unsigned int i = 0; i < 64; i++)
        sum += isqrt(i * 1000);
    unsigned int elapsed = TIMER_COUNT;

    test_assert(sum > 0, "sqrt sum is zero");
    test_assert(elapsed > 0, "timer did not advance");

    // Store elapsed for later use
    SCRATCH[0] = elapsed;
    SCRATCH[1] = sum;
    return 0;
}

// ── 2. RAM store + verify ───────────────────────────────────
static int test_ram_table(void) {
    for (unsigned int i = 0; i < 128; i++) {
        unsigned int val = (i * 7 + 13) * (i + 1);        // MUL-heavy
        unsigned int div_val = val / (i + 1);              // should be (i*7+13)
        SCRATCH[64 + i] = div_val;
    }
    for (unsigned int i = 0; i < 128; i++) {
        unsigned int exp = i * 7 + 13;
        test_assert_eq(SCRATCH[64 + i], exp, "ram-table");
    }
    return 0;
}

// ── 3. Framebuffer computed pattern ─────────────────────────
static int test_fb_circle(void) {
    for (int y = 0; y < 8; y++) {
        for (int x = 0; x < FB_WIDTH; x += 4) {
            unsigned int word = 0;
            for (int p = 0; p < 4; p++) {
                int dx = (x + p) - 40;
                int dy = y - 4;
                unsigned int d = isqrt((unsigned int)(dx * dx + dy * dy));
                unsigned int pixel = d & 0xFF;
                word |= pixel << (p * 8);
            }
            FB[y * ROW_W + (x / 4)] = word;
        }
    }

    // Read back and verify a few known positions
    unsigned int w = FB[4 * ROW_W + 10];
    unsigned int p0 = w & 0xFF;  // pixel at x=40, y=4
    test_assert_eq(p0, 0, "circle centre");

    unsigned int w0 = FB[0];
    unsigned int corner = w0 & 0xFF;
    test_assert_eq(corner, isqrt(40*40 + 4*4), "circle corner");
    return 0;
}

// ── 4. Timer + UART coherence ───────────────────────────────
static int test_timer_progression(void) {
    unsigned int now     = TIMER_COUNT;
    unsigned int earlier = SCRATCH[0];
    test_assert(now > earlier, "timer didn't advance past stored value");
    return 0;
}

// ── 5. Cross-peripheral: RAM→FB pipeline ────────────────────
static int test_cross_periph(void) {
    for (int i = 0; i < 80; i++)
        SCRATCH[256 + i] = ((unsigned int)i * 3) & 0xFF;

    for (int i = 0; i < 80; i += 4) {
        unsigned int p0 = SCRATCH[256 + i + 0];
        unsigned int p1 = SCRATCH[256 + i + 1];
        unsigned int p2 = SCRATCH[256 + i + 2];
        unsigned int p3 = SCRATCH[256 + i + 3];
        unsigned int word = p0 | (p1 << 8) | (p2 << 16) | (p3 << 24);
        FB[10 * ROW_W + (i / 4)] = word;
    }

    unsigned int fb0 = FB[10 * ROW_W];
    unsigned int exp = 0 | (3 << 8) | (6 << 16) | (9 << 24);
    test_assert_eq(fb0, exp, "cross-periph fb[0]");
    return 0;
}

int main(void) {
    test_begin("INTEGRATION TEST");
    test_run(test_timed_sqrt);
    test_run(test_ram_table);
    test_run(test_fb_circle);
    test_run(test_timer_progression);
    test_run(test_cross_periph);
    return test_end();
}
