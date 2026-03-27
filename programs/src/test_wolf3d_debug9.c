// test_wolf3d_debug9.c — Minimal test of noinline function + static variables.
//
// Tests whether calling a noinline function that reads static variables
// produces correct results. Uses fill_rows to visualize results.
//
// Expected: GREEN rows 0-9, then WHITE rows 10-19, then YELLOW rows 230-239.
// If statics are broken: likely all RED or different colors.

#include "soc.h"

static int  test_val_a;
static int  test_val_b;
static int  test_result;

static void fill_rows(int y_start, int y_end, unsigned int color4) {
    for (int y = y_start; y < y_end; y++) {
        unsigned int *row = (unsigned int *)FB_BASE + y * (FB_WIDTH / 4);
        for (int x = 0; x < FB_WIDTH / 4; x++)
            row[x] = color4;
    }
}

__attribute__((noinline))
static int compute_sum(void) {
    return test_val_a + test_val_b;
}

int main(void) {
    // Fill screen RED
    fill_rows(0, 240, 0xE0E0E0E0);

    test_val_a = 42;
    test_val_b = 58;

    int result = compute_sum();
    test_result = result;

    if (result == 100) {
        fill_rows(0, 10, 0x1C1C1C1C);   // GREEN = statics work
    } else {
        fill_rows(0, 10, 0x03030303);    // BLUE = statics WRONG
    }

    // Also test calling a function multiple times
    test_val_a = 10;
    test_val_b = 20;
    int r2 = compute_sum();
    test_val_a = 100;
    test_val_b = 200;
    int r3 = compute_sum();

    if (r2 == 30 && r3 == 300) {
        fill_rows(10, 20, 0xFFFFFFFF);   // WHITE = multi-call works
    } else {
        fill_rows(10, 20, 0xE003E003);   // MAGENTA = multi-call WRONG
    }

    // Mark done
    fill_rows(230, 240, 0xFCFCFCFC);     // YELLOW

    while (1) ;
    return 0;
}
