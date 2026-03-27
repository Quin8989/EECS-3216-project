// EECS 3216 RISC-V SoC — Shared header for C programs
//
// MMIO register map, UART helpers, and a minimal test framework.
// Include this instead of redefining addresses in every file.

#ifndef SOC_H
#define SOC_H

// ── MMIO Peripheral Addresses ──────────────────────────────

// UART (TX-only, 115200 8N1)
#define UART_TX      (*(volatile unsigned int *)0x10000000)  // +0x0 write: send byte
#define UART_STATUS  (*(volatile unsigned int *)0x10000004)  // +0x4 read: bit 0 = tx_ready
#define UART_RX      (*(volatile unsigned int *)0x10000008)  // +0x8 read: (reserved)

// Timer (free-running 32-bit counter @ 25 MHz)
#define TIMER_COUNT  (*(volatile unsigned int *)0x20000000)  // +0x0 read/write: current count
#define TIMER_CMP    (*(volatile unsigned int *)0x20000004)  // +0x4 write: compare value
#define TIMER_STATUS (*(volatile unsigned int *)0x20000008)  // +0x8 read: bit 0 = match; write 1 to clear

// Keyboard (PS/2 scan codes via JTAG injection)
#define KBD_DATA     (*(volatile unsigned int *)0x40000000)  // +0x0 read: scan code
#define KBD_STATUS   (*(volatile unsigned int *)0x40000004)  // +0x4 read: bit 0 = data ready

// Framebuffer (320x240 RGB332, on-chip dual-port RAM, 4 pixels per word)
#define FB_BASE      ((volatile unsigned int *)0x80000000)
#define FB_WIDTH     320
#define FB_HEIGHT    240

// VGA status register (read-only):
//   bit 0 = blanking (1 while in blanking interval)
#define VGA_STATUS_REG  (*(volatile unsigned int *)0x30000000)

// On-chip RAM (8 KB)
#define RAM_BASE     ((volatile unsigned char *)0x02000000)
#define RAM_SIZE     8192

// ── UART Helpers ───────────────────────────────────────────

static inline void uart_putc(char c) {
    while (!(UART_STATUS & 1))
        ;
    UART_TX = (unsigned int)c;
}

static void uart_puts(const char *s) {
    while (*s) uart_putc(*s++);
}

static void uart_put_hex32(unsigned int v) {
    static const char hex[] = "0123456789ABCDEF";
    for (int shift = 28; shift >= 0; shift -= 4)
        uart_putc(hex[(v >> shift) & 0xF]);
}

static void uart_put_dec(unsigned int v) {
    if (v == 0) { uart_putc('0'); return; }
    // Subtraction-based digit extraction (no division — CPU lacks DIV).
    static const unsigned int pow10[] = {
        1000000000, 100000000, 10000000, 1000000, 100000,
        10000, 1000, 100, 10, 1
    };
    int started = 0;
    for (int d = 0; d < 10; d++) {
        char digit = '0';
        while (v >= pow10[d]) { v -= pow10[d]; digit++; }
        if (digit != '0' || started) { uart_putc(digit); started = 1; }
    }
}

// ── Minimal Test Framework ─────────────────────────────────
//
// Usage:
//   int main(void) {
//       test_begin("My Test Suite");
//       test_run(test_foo);
//       test_run(test_bar);
//       return test_end();   // prints summary, returns 1 (PASS) or 0 (FAIL)
//   }
//
// Each test function returns 0 on success, nonzero on failure.
// The test_assert() macro fails the current test with a message.

static int _test_total;
static int _test_pass;
static int _test_fail;

static void test_begin(const char *suite_name) {
    _test_total = 0;
    _test_pass  = 0;
    _test_fail  = 0;
    uart_puts(suite_name);
    uart_puts("\r\n");
}

// Run a single test function; name is printed, result tallied.
#define test_run(fn) do {                          \
    _test_total++;                                 \
    uart_puts("  " #fn ": ");                      \
    int _rc = (fn)();                              \
    if (_rc == 0) { uart_puts("PASS\r\n"); _test_pass++; } \
    else          { uart_puts("FAIL\r\n"); _test_fail++; } \
} while (0)

// Print summary and return value suitable for crt0 (1 = PASS for testbench).
// On hardware (no testbench), spins forever after printing.
static int test_end(void) {
    uart_puts("\r\n");
    uart_put_dec(_test_pass);
    uart_putc('/');
    uart_put_dec(_test_total);
    uart_puts(" passed\r\n");
    if (_test_fail == 0)
        uart_puts("RESULT: PASS\r\n");
    else
        uart_puts("RESULT: FAIL\r\n");
    // Return to crt0 which sets x3 and executes ECALL (terminates simulation).
    // On real hardware crt0 spins after ECALL.
    return _test_fail == 0 ? 1 : 0;
}

// Assertion helper — returns from the enclosing function with error code.
#define test_assert(cond, msg) do {                \
    if (!(cond)) {                                 \
        uart_puts("ASSERT: " msg " ");             \
        return 1;                                  \
    }                                              \
} while (0)

// Assert with hex dump of actual vs expected.
#define test_assert_eq(actual, expected, msg) do {  \
    unsigned int _a = (unsigned int)(actual);       \
    unsigned int _e = (unsigned int)(expected);     \
    if (_a != _e) {                                 \
        uart_puts("ASSERT: " msg " got=0x");        \
        uart_put_hex32(_a);                         \
        uart_puts(" exp=0x");                       \
        uart_put_hex32(_e);                         \
        uart_puts(" ");                             \
        return 1;                                   \
    }                                               \
} while (0)

#endif // SOC_H
