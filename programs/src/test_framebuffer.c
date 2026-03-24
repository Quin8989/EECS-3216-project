#define UART_TX     (*(volatile unsigned int *)0x10000000)
#define UART_STATUS (*(volatile unsigned int *)0x10000004)

#define FB_BASE     ((volatile unsigned int *)0x80000000)
#define FB_WIDTH    320
#define FB_HEIGHT   240

static void uart_putc(char c) {
    while (!(UART_STATUS & 1)) {
    }
    UART_TX = (unsigned int)c;
}

static void uart_puts(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}

static unsigned char rgb332(unsigned int r, unsigned int g, unsigned int b) {
    return (unsigned char)(((r & 0x7) << 5) | ((g & 0x7) << 2) | (b & 0x3));
}

static unsigned char test_pixel(int x, int y) {
    unsigned int r = (unsigned int)x >> 5;
    unsigned int g = (unsigned int)y >> 5;
    unsigned int b = (unsigned int)(x ^ y) >> 7;

    if (x < 8 || x >= FB_WIDTH - 8 || y < 8 || y >= FB_HEIGHT - 8) {
        return rgb332(7, 7, 3);
    }
    if (x > 96 && x < 224 && y > 72 && y < 168) {
        return rgb332(7, 1, 0);
    }

    return rgb332(r, g, b);
}

int main(void) {
    int x;
    int y;

    uart_puts("Framebuffer test: filling 320x240 RGB332 pattern\r\n");

    for (y = 0; y < FB_HEIGHT; y++) {
        for (x = 0; x < FB_WIDTH; x += 4) {
            unsigned int p0 = (unsigned int)test_pixel(x + 0, y);
            unsigned int p1 = (unsigned int)test_pixel(x + 1, y);
            unsigned int p2 = (unsigned int)test_pixel(x + 2, y);
            unsigned int p3 = (unsigned int)test_pixel(x + 3, y);
            unsigned int word = p0 | (p1 << 8) | (p2 << 16) | (p3 << 24);

            FB_BASE[(y * (FB_WIDTH / 4)) + (x / 4)] = word;
        }
    }

    uart_puts("Framebuffer test complete\r\n");

    while (1) {
    }

    return 0;
}