// Pattern Test: Timer
//
// Exercises timer peripheral patterns:
//   - Monotonic counter advancement
//   - Elapsed cycle measurement (known delay loop)
//   - Multiple compare/match cycles in sequence
//   - Counter reset precision

#include "soc.h"

// ── Counter monotonicity ────────────────────────────────────
// Sample the counter many times; each read must be >= the previous.
static int test_monotonic(void) {
    unsigned int prev = TIMER_COUNT;
    for (int i = 0; i < 100; i++) {
        unsigned int cur = TIMER_COUNT;
        test_assert(cur >= prev, "counter went backward");
        prev = cur;
    }
    return 0;
}

// ── Elapsed measurement ─────────────────────────────────────
// Reset counter, spin for a known instruction count, verify elapsed
// is plausible (not zero, not absurdly large).
static int test_elapsed(void) {
    TIMER_COUNT = 0;
    for (volatile int i = 0; i < 500; i++)
        ;
    unsigned int elapsed = TIMER_COUNT;
    // 500 loop iterations × ~5-6 cycles each ≈ 2500-3000 cycles minimum.
    // With the iterative divider, each stall adds more, but this loop is
    // simple add/compare — should be well under 20000 cycles.
    test_assert(elapsed > 500,   "elapsed too low");
    test_assert(elapsed < 50000, "elapsed too high");
    return 0;
}

// ── Sequential compare matches ──────────────────────────────
// Fire the compare match 3 times in a row with increasing thresholds.
static int test_multi_compare(void) {
    unsigned int thresholds[] = { 100, 500, 2000 };
    for (int t = 0; t < 3; t++) {
        TIMER_STATUS = 1;               // clear any pending flag
        TIMER_COUNT  = 0;               // reset
        TIMER_CMP    = thresholds[t];

        int timeout = 100000;
        while (!(TIMER_STATUS & 1) && --timeout > 0)
            ;
        test_assert(timeout > 0, "match never fired");

        // Verify counter actually reached the threshold
        unsigned int cnt = TIMER_COUNT;
        test_assert(cnt >= thresholds[t], "counter < threshold at match");
    }
    return 0;
}

// ── Reset precision ─────────────────────────────────────────
// After reset, counter should be very close to 0 (within a few cycles).
static int test_reset_precision(void) {
    for (int i = 0; i < 5; i++) {
        TIMER_COUNT = 0;
        unsigned int v = TIMER_COUNT;
        test_assert(v < 20, "counter not near zero after reset");
    }
    return 0;
}

int main(void) {
    test_begin("PATTERN: TIMER");
    test_run(test_monotonic);
    test_run(test_elapsed);
    test_run(test_multi_compare);
    test_run(test_reset_precision);
    return test_end();
}
