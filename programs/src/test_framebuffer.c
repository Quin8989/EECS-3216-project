// VGA framebuffer write test
//
// Fills the 320x240 RGB332 on-chip framebuffer with a recognisable
// colour pattern and border, then reads back a sample of words to verify
// the write path.  In simulation the VGA capture module will also
// dump a PPM image.

#include "soc.h"

static unsigned char rgb332(unsigned int r, unsigned int g, unsigned int b) {
    return (unsigned char)(((r & 0x7) << 5) | ((g & 0x7) << 2) | (b & 0x3));
}

static unsigned char test_pixel(int x, int y) {
    // White border
    if (x < 8 || x >= FB_WIDTH - 8 || y < 8 || y >= FB_HEIGHT - 8)
        return rgb332(7, 7, 3);
    // Red centre rectangle
    if (x > 96 && x < 224 && y > 72 && y < 168)
        return rgb332(7, 1, 0);
    // Colour gradient
    return rgb332((unsigned int)x >> 5, (unsigned int)y >> 5,
                  (unsigned int)(x ^ y) >> 7);
}

static int test_fill_framebuffer(void) {
    for (int y = 0; y < FB_HEIGHT; y++) {
        for (int x = 0; x < FB_WIDTH; x += 4) {
            unsigned int p0 = (unsigned int)test_pixel(x + 0, y);
            unsigned int p1 = (unsigned int)test_pixel(x + 1, y);
            unsigned int p2 = (unsigned int)test_pixel(x + 2, y);
            unsigned int p3 = (unsigned int)test_pixel(x + 3, y);
            unsigned int word = p0 | (p1 << 8) | (p2 << 16) | (p3 << 24);
            FB_BASE[(y * (FB_WIDTH / 4)) + (x / 4)] = word;
        }
    }
    return 0;
}

// Read back a few words and verify they match the expected pattern.
static int test_readback(void) {
    // Check first word (top-left corner — white border pixel)
    unsigned int w0 = FB_BASE[0];
    unsigned char exp0 = rgb332(7, 7, 3);
    unsigned int exp_word0 = exp0 | ((unsigned int)exp0 << 8) |
                             ((unsigned int)exp0 << 16) | ((unsigned int)exp0 << 24);
    test_assert_eq(w0, exp_word0, "fb[0,0]");

    // Check a word in the red rectangle area (y=120, x=120..123)
    unsigned int idx = (120 * (FB_WIDTH / 4)) + (120 / 4);
    unsigned int w1 = FB_BASE[idx];
    unsigned char exp_r = rgb332(7, 1, 0);
    unsigned int exp_word1 = exp_r | ((unsigned int)exp_r << 8) |
                              ((unsigned int)exp_r << 16) | ((unsigned int)exp_r << 24);
    test_assert_eq(w1, exp_word1, "fb[120,120]");
    return 0;
}

int main(void) {
    test_begin("FRAMEBUFFER TEST");
    test_run(test_fill_framebuffer);
    test_run(test_readback);
    return test_end();
}