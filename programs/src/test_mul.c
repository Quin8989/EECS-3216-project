#define VRAM ((volatile unsigned int *)0x30000000)

static void vga_putc(int row, int col, char c) {
    VRAM[row * 80 + col] = (unsigned int)c;
}

static void vga_puts(int row, const char *s) {
    int col = 0;
    while (*s) {
        vga_putc(row, col++, *s++);
    }
}

static void vga_puts_at(int row, int col, const char *s) {
    while (*s) {
        vga_putc(row, col++, *s++);
    }
}

static void vga_put_hex32(int row, int col, unsigned int value) {
    static const char hex[] = "0123456789ABCDEF";
    int shift;

    for (shift = 28; shift >= 0; shift -= 4) {
        vga_putc(row, col++, hex[(value >> shift) & 0xF]);
    }
}

static int run_mul(int a, int b) {
    int result;

    asm volatile(
        ".insn r 0x33, 0, 0x01, %0, %1, %2"
        : "=r"(result)
        : "r"(a), "r"(b));

    return result;
}

static int test_case(int row, const char *name, int a, int b, int expected) {
    int got = run_mul(a, b);

    vga_puts(row, name);
    vga_puts_at(row, 12, " got=");
    vga_put_hex32(row, 17, (unsigned int)got);
    vga_puts_at(row, 26, " exp=");
    vga_put_hex32(row, 31, (unsigned int)expected);

    if (got != expected) {
        vga_puts_at(row, 41, " FAIL");
        return 1;
    }

    vga_puts_at(row, 41, " PASS");
    return 0;
}

int main(void) {
    int fails = 0;

    vga_puts(0, "RV32M MUL TEST");
    vga_puts(1, "Checks low 32-bit product only");

    fails += test_case(3, "3 * 7", 3, 7, 21);
    fails += test_case(4, "0 * X", 0, 0x13579BDF, 0);
    fails += test_case(5, "-3 * 11", -3, 11, -33);
    fails += test_case(6, "-9 * -9", -9, -9, 81);
    fails += test_case(7, "0x12345678*16", 0x12345678, 16, 0x23456780);
    fails += test_case(8, "0x7FFFFFFF*2", 0x7FFFFFFF, 2, -2);

    if (fails == 0) {
        vga_puts(10, "RESULT: PASS");
    } else {
        vga_puts(10, "RESULT: FAIL count=");
        vga_putc(10, 19, (char)('0' + fails));
    }

    while (1) {
    }

    return 0;
}