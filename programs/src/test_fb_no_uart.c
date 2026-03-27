// test_framebuffer_no_uart.c — FB test without any UART calls.
// If this works on FPGA but test_framebuffer doesn't, UART is the problem.
// If this also fails, the issue is in the FB write/compute logic.

#define FB_BASE    ((volatile unsigned int *)0x80000000)
#define FB_WIDTH   320
#define FB_HEIGHT  240

static unsigned char rgb332(unsigned int r, unsigned int g, unsigned int b) {
    return (unsigned char)(((r & 0x7) << 5) | ((g & 0x7) << 2) | (b & 0x3));
}

static unsigned char test_pixel(int x, int y) {
    if (x < 8 || x >= FB_WIDTH - 8 || y < 8 || y >= FB_HEIGHT - 8)
        return rgb332(7, 7, 3);  // white border
    if (x > 96 && x < 224 && y > 72 && y < 168)
        return rgb332(7, 1, 0);  // red centre
    return rgb332((unsigned int)x >> 5, (unsigned int)y >> 5,
                  (unsigned int)(x ^ y) >> 7);
}

int main(void) {
    for (int y = 0; y < FB_HEIGHT; y++) {
        for (int x = 0; x < FB_WIDTH; x += 4) {
            unsigned int p0 = test_pixel(x, y);
            unsigned int p1 = test_pixel(x + 1, y);
            unsigned int p2 = test_pixel(x + 2, y);
            unsigned int p3 = test_pixel(x + 3, y);
            FB_BASE[(y * (FB_WIDTH / 4)) + (x / 4)] = p0 | (p1 << 8) | (p2 << 16) | (p3 << 24);
        }
    }
    while (1) ;
    return 0;
}
