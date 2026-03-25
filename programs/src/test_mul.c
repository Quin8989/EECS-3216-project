// RV32M MUL test — reports results via UART

#define UART_TX     (*(volatile unsigned int *)0x10000000)
#define UART_STATUS (*(volatile unsigned int *)0x10000004)

static void uart_putc(char c) {
    while (!(UART_STATUS & 1));
    UART_TX = (unsigned int)c;
}

static void uart_puts(const char *s) {
    while (*s) uart_putc(*s++);
}

static void uart_put_hex32(unsigned int value) {
    static const char hex[] = "0123456789ABCDEF";
    for (int shift = 28; shift >= 0; shift -= 4)
        uart_putc(hex[(value >> shift) & 0xF]);
}

static int run_mul(int a, int b) {
    int result;
    asm volatile(
        ".insn r 0x33, 0, 0x01, %0, %1, %2"
        : "=r"(result)
        : "r"(a), "r"(b));
    return result;
}

static int test_case(const char *name, int a, int b, int expected) {
    int got = run_mul(a, b);
    uart_puts(name);
    uart_puts(" got=");
    uart_put_hex32((unsigned int)got);
    uart_puts(" exp=");
    uart_put_hex32((unsigned int)expected);
    if (got != expected) {
        uart_puts(" FAIL\r\n");
        return 1;
    }
    uart_puts(" PASS\r\n");
    return 0;
}

int main(void) {
    int fails = 0;

    uart_puts("RV32M MUL TEST\r\n");

    fails += test_case("3 * 7       ", 3, 7, 21);
    fails += test_case("0 * X       ", 0, 0x13579BDF, 0);
    fails += test_case("-3 * 11     ", -3, 11, -33);
    fails += test_case("-9 * -9     ", -9, -9, 81);
    fails += test_case("12345678*16 ", 0x12345678, 16, 0x23456780);
    fails += test_case("7FFFFFFF*2  ", 0x7FFFFFFF, 2, -2);

    if (fails == 0)
        uart_puts("RESULT: PASS\r\n");
    else {
        uart_puts("RESULT: FAIL\r\n");
    }

    while (1);
    return 0;
}