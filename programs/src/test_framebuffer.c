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

static unsigned int expected_word_at(int x, int y) {
    unsigned int p0 = (unsigned int)test_pixel(x + 0, y);
    unsigned int p1 = (unsigned int)test_pixel(x + 1, y);
    unsigned int p2 = (unsigned int)test_pixel(x + 2, y);
    unsigned int p3 = (unsigned int)test_pixel(x + 3, y);
    return p0 | (p1 << 8) | (p2 << 16) | (p3 << 24);
}

static void wait_for_vblank_start(void) {
    while (VGA_STATUS_REG & 1)
        ;
    while (!(VGA_STATUS_REG & 1))
        ;
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

    // Wait long enough that scanout has displayed one complete frame using
    // the final framebuffer contents rather than an in-progress write sweep.
    wait_for_vblank_start();
    wait_for_vblank_start();

    return 0;
}

// Read back a few words and verify they match the expected pattern.
static int test_readback(void) {
    static const struct {
        int x;
        int y;
        const char *label;
    } samples[] = {
        {  0,   0, "fb[0,0]" },
        {  8,   8, "fb[8,8]" },
        {120, 120, "fb[120,120]" },
        {160,  40, "fb[160,40]" },
        { 40, 160, "fb[40,160]" },
        {316, 239, "fb[316,239]" }
    };

    for (unsigned int i = 0; i < sizeof(samples) / sizeof(samples[0]); i++) {
        unsigned int idx = (unsigned int)(samples[i].y * (FB_WIDTH / 4)) +
                           (unsigned int)(samples[i].x / 4);
        unsigned int actual = FB_BASE[idx];
        unsigned int expected = expected_word_at(samples[i].x, samples[i].y);
        if (actual != expected) {
            uart_puts("ASSERT: ");
            uart_puts(samples[i].label);
            uart_puts(" got=0x");
            uart_put_hex32(actual);
            uart_puts(" exp=0x");
            uart_put_hex32(expected);
            uart_puts(" ");
            return 1;
        }
    }

    return 0;
}

int main(void) {
    test_begin("FRAMEBUFFER TEST");
    test_run(test_fill_framebuffer);
    test_run(test_readback);
    return test_end();
}