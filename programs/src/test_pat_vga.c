// Pattern Test: VGA Framebuffer
//
// Writes known pixel patterns to the on-chip framebuffer and reads
// them back word-by-word.  Tests:
//   - Solid fill (all-white, all-black)
//   - Byte-lane isolation (each of 4 pixel bytes independent)
//   - Horizontal gradient (address progression across a row)
//   - Boundary rows (first, last, middle)

#include "soc.h"

#define FB  FB_BASE
#define ROW_WORDS  (FB_WIDTH / 4)   // 80 words per row

static unsigned int pattern_word(int word_x, int y) {
    unsigned int p0 = (unsigned int)((word_x * 13 + y * 3 + 0x11) & 0xFF);
    unsigned int p1 = (unsigned int)((word_x * 7  + y * 5 + 0x55) & 0xFF);
    unsigned int p2 = (unsigned int)((word_x * 5  + y * 9 + 0x99) & 0xFF);
    unsigned int p3 = (unsigned int)((word_x * 3  + y * 11 + 0xDD) & 0xFF);
    return p0 | (p1 << 8) | (p2 << 16) | (p3 << 24);
}

static void fb_fill_word(unsigned int word, int row) {
    for (int i = 0; i < ROW_WORDS; i++)
        FB[row * ROW_WORDS + i] = word;
}

// ── Solid white fill + readback on row 0 ────────────────────
static int test_solid_white(void) {
    fb_fill_word(0xFFFFFFFF, 0);
    for (int i = 0; i < ROW_WORDS; i++)
        test_assert_eq(FB[i], 0xFFFFFFFF, "white row0");
    return 0;
}

// ── Solid black fill + readback on row 1 ────────────────────
static int test_solid_black(void) {
    fb_fill_word(0x00000000, 1);
    for (int i = 0; i < ROW_WORDS; i++)
        test_assert_eq(FB[ROW_WORDS + i], 0x00000000, "black row1");
    return 0;
}

// ── Byte-lane isolation ─────────────────────────────────────
// Write 4 distinct pixel values per word, verify each byte survives.
// RGB332 encoding: 0xE0 = red, 0x1C = green, 0x03 = blue, 0xFF = white
static int test_byte_lanes(void) {
    unsigned int pat = 0xE0 | (0x1C << 8) | (0x03 << 16) | (0xFF << 24);
    for (int i = 0; i < ROW_WORDS; i++)
        FB[2 * ROW_WORDS + i] = pat;
    for (int i = 0; i < ROW_WORDS; i++)
        test_assert_eq(FB[2 * ROW_WORDS + i], pat, "byte-lane");
    return 0;
}

// ── Horizontal gradient ─────────────────────────────────────
// Each word in row 3 has a unique value derived from its column index.
static int test_gradient(void) {
    for (int i = 0; i < ROW_WORDS; i++) {
        unsigned int px = (unsigned int)(i * 4) & 0xFF;
        unsigned int word = px | (px << 8) | (px << 16) | (px << 24);
        FB[3 * ROW_WORDS + i] = word;
    }
    for (int i = 0; i < ROW_WORDS; i++) {
        unsigned int px = (unsigned int)(i * 4) & 0xFF;
        unsigned int exp = px | (px << 8) | (px << 16) | (px << 24);
        test_assert_eq(FB[3 * ROW_WORDS + i], exp, "gradient");
    }
    return 0;
}

// ── Boundary rows ───────────────────────────────────────────
// Write/read the very last row of the framebuffer to verify addressing
// reaches the full 320×240 = 76800 bytes region.
static int test_last_row(void) {
    int last = FB_HEIGHT - 1;  // row 239
    unsigned int pat = 0xA5A5A5A5;
    for (int i = 0; i < ROW_WORDS; i++)
        FB[last * ROW_WORDS + i] = pat;
    for (int i = 0; i < ROW_WORDS; i++)
        test_assert_eq(FB[last * ROW_WORDS + i], pat, "last-row");
    return 0;
}

// ── Address stride coverage across visible frame ───────────
// Write unique words to the first, middle, and last rows. This catches
// row-stride/address alias bugs that simple single-row tests can miss.
static int test_row_stride_samples(void) {
    static const int rows[] = {0, FB_HEIGHT / 2, FB_HEIGHT - 1};

    for (unsigned int r = 0; r < sizeof(rows) / sizeof(rows[0]); r++) {
        int y = rows[r];
        for (int x = 0; x < ROW_WORDS; x++)
            FB[y * ROW_WORDS + x] = pattern_word(x, y);
    }

    for (unsigned int r = 0; r < sizeof(rows) / sizeof(rows[0]); r++) {
        int y = rows[r];
        for (int x = 0; x < ROW_WORDS; x++)
            test_assert_eq(FB[y * ROW_WORDS + x], pattern_word(x, y), "row-stride");
    }

    return 0;
}

int main(void) {
    test_begin("PATTERN: VGA FB");
    test_run(test_solid_white);
    test_run(test_solid_black);
    test_run(test_byte_lanes);
    test_run(test_gradient);
    test_run(test_last_row);
    test_run(test_row_stride_samples);
    return test_end();
}
