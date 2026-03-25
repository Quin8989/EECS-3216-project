// EECS 3216 — Demo Program
//
// Interactive terminal: keyboard input → UART echo.
// Scancodes from JTAG keyboard injection are converted to ASCII
// and sent over UART for serial monitoring.

// ── MMIO addresses ─────────────────────────────────────────
#define UART_TX     (*(volatile unsigned int *)0x10000000)
#define UART_STATUS (*(volatile unsigned int *)0x10000004)

#define TIMER_COUNT (*(volatile unsigned int *)0x20000000)

#define KBD_DATA    (*(volatile unsigned int *)0x40000000)
#define KBD_STATUS  (*(volatile unsigned int *)0x40000004)

// ── Helper functions ───────────────────────────────────────

static void uart_putc(char c) {
    while (!(UART_STATUS & 1))
        ;
    UART_TX = (unsigned int)c;
}

static void uart_puts(const char *s) {
    while (*s)
        uart_putc(*s++);
}

// ── PS/2 Set 2 scancode → ASCII (make codes, unshifted) ───
// Only printable keys + Enter/Backspace/Space.
// 0 = not mapped.
static const char scancode_to_ascii[128] = {
    //       0     1     2     3     4     5     6     7     8     9     A     B     C     D     E     F
    /* 0 */  0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,  '\t',  '`',   0,
    /* 1 */  0,    0,    0,    0,    0,   'q',  '1',   0,    0,    0,   'z',  's',  'a',  'w',  '2',   0,
    /* 2 */  0,   'c',  'x',  'd',  'e',  '4',  '3',   0,    0,   ' ',  'f',  't',  'r',  '5',   0,    0,
    /* 3 */  0,   'n',  'b',  'h',  'g',  'y',  '6',   0,    0,    0,   'm',  'j',  'u',  '7',  '8',   0,
    /* 4 */  0,   ',',  'k',  'i',  'o',  '0',  '9',   0,    0,   '.',  '/',  'l',  ';',  'p',  '-',   0,
    /* 5 */  0,    0,  '\'',   0,   '[',  '=',   0,    0,    0,    0,  '\n',  ']',   0,  '\\',   0,    0,
    /* 6 */  0,    0,    0,    0,    0,    0,  '\b',   0,    0,    0,    0,    0,    0,    0,    0,    0,
    /* 7 */  0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,    0,
};

// ── Main ───────────────────────────────────────────────────

int main(void) {
    uart_puts("EECS 3216 RISC-V SoC Demo\r\n");
    uart_puts("Type on the keyboard:\r\n\r\n");

    int release_next = 0;

    while (1) {
        if (!(KBD_STATUS & 1))
            continue;

        unsigned int code = KBD_DATA;

        if (code == 0xF0) {
            release_next = 1;
            continue;
        }

        if (release_next) {
            release_next = 0;
            continue;
        }

        if (code < 128) {
            char ch = scancode_to_ascii[code];
            if (ch) {
                uart_putc(ch);
                if (ch == '\n')
                    uart_putc('\r');
            }
        }
    }

    return 1;  // x3 = 1 → PASS (never reached)
}
