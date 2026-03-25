// Timer peripheral test
//
// Exercises the 32-bit free-running counter, compare register,
// and match-flag logic.

#include "soc.h"

// Timer counter increments every cycle.  Read it twice and verify progress.
static int test_counter_runs(void) {
    unsigned int a = TIMER_COUNT;
    // Small busy delay — compiler won't optimise out volatile reads.
    for (volatile int i = 0; i < 10; i++)
        ;
    unsigned int b = TIMER_COUNT;
    test_assert(b > a, "counter did not advance");
    return 0;
}

// Writing to COUNT should reset it to 0.
static int test_counter_reset(void) {
    TIMER_COUNT = 0;  // any write resets
    unsigned int v = TIMER_COUNT;
    // After reset + 1-2 cycles of read latency, value should be very small.
    test_assert(v < 100, "counter not near zero after reset");
    return 0;
}

// Set compare register, wait for match flag.
static int test_compare_match(void) {
    // Clear any existing match flag
    TIMER_STATUS = 1;
    // Reset counter
    TIMER_COUNT = 0;
    // Set compare to a small value
    TIMER_CMP = 50;

    // Spin until match flag appears (with timeout)
    for (int i = 0; i < 10000; i++) {
        if (TIMER_STATUS & 1)
            return 0;  // match flag set — pass
    }
    test_assert(0, "match flag never set");
    return 1;
}

// Match flag should latch until software clears it.
static int test_flag_latch(void) {
    // Trigger a match
    TIMER_STATUS = 1;  // clear first
    TIMER_COUNT = 0;
    TIMER_CMP = 10;
    for (volatile int i = 0; i < 1000; i++)
        ;
    test_assert(TIMER_STATUS & 1, "flag not latched");

    // Clear by writing 1
    TIMER_STATUS = 1;
    // After clearing, the counter has long passed CMP so flag should stay clear
    // unless counter wraps back to CMP (won't happen in 10 cycles).
    // Read immediately — should be clear.
    unsigned int s = TIMER_STATUS;
    test_assert(!(s & 1), "flag not cleared after write");
    return 0;
}

int main(void) {
    test_begin("TIMER TEST");
    test_run(test_counter_runs);
    test_run(test_counter_reset);
    test_run(test_compare_match);
    test_run(test_flag_latch);
    return test_end();
}
