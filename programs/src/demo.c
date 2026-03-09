// EECS 3216 — Demo Program
//
// Interactive terminal: keyboard input → VGA display + UART echo.
// PS/2 scancodes are converted to ASCII and displayed on the 80×30 VGA
// text screen. Characters are also sent over UART for serial monitoring.

// ── MMIO addresses ─────────────────────────────────────────
#define UART_TX     (*(volatile unsigned int *)0x10000000)
#define UART_STATUS (*(volatile unsigned int *)0x10000004)

#define TIMER_COUNT (*(volatile unsigned int *)0x20000000)

#define VGA_BASE    ((volatile unsigned int *)0x30000000)

#define KBD_DATA    (*(volatile unsigned int *)0x40000000)
#define KBD_STATUS  (*(volatile unsigned int *)0x40000004)

// ── VGA parameters ─────────────────────────────────────────
#define VGA_COLS 80
#define VGA_ROWS 30

// ── Globals ────────────────────────────────────────────────
static int cursor_col = 0;
static int cursor_row = 0;

// ── Helper functions ───────────────────────────────────────

static void uart_putc(char c) {
    // Wait until TX ready
    while (!(UART_STATUS & 1))
        ;
    UART_TX = (unsigned int)c;
}

static void uart_puts(const char *s) {
    while (*s)
        uart_putc(*s++);
}

static void vga_putc_at(int col, int row, char c) {
    int idx = row * VGA_COLS + col;
    VGA_BASE[idx] = (unsigned int)c;
}

static void vga_scroll(void) {
    // Move rows 1..29 up to 0..28
    for (int r = 0; r < VGA_ROWS - 1; r++) {
        for (int c = 0; c < VGA_COLS; c++) {
            int dst = r * VGA_COLS + c;
            int src = (r + 1) * VGA_COLS + c;
            VGA_BASE[dst] = VGA_BASE[src];
        }
    }
    // Clear last row
    for (int c = 0; c < VGA_COLS; c++) {
        VGA_BASE[(VGA_ROWS - 1) * VGA_COLS + c] = ' ';
    }
}

static void vga_newline(void) {
    cursor_col = 0;
    cursor_row++;
    if (cursor_row >= VGA_ROWS) {
        vga_scroll();
        cursor_row = VGA_ROWS - 1;
    }
}

static void vga_putc(char c) {
    if (c == '\n') {
        vga_newline();
        return;
    }
    if (c == '\r') {
        cursor_col = 0;
        return;
    }
    if (c == '\b') {
        if (cursor_col > 0) {
            cursor_col--;
            vga_putc_at(cursor_col, cursor_row, ' ');
        }
        return;
    }
    vga_putc_at(cursor_col, cursor_row, c);
    cursor_col++;
    if (cursor_col >= VGA_COLS) {
        vga_newline();
    }
}

static void vga_puts(const char *s) {
    while (*s)
        vga_putc(*s++);
}

// Output to both VGA and UART
static void putc_both(char c) {
    vga_putc(c);
    uart_putc(c);
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
    // Print banner
    vga_puts("EECS 3216 RISC-V SoC Demo\n");
    vga_puts("Type on the PS/2 keyboard:\n\n");

    uart_puts("EECS 3216 RISC-V SoC Demo\r\n");
    uart_puts("Type on the PS/2 keyboard:\r\n\r\n");

    int release_next = 0;  // flag: next scancode is a break code

    // Main loop: poll keyboard forever
    while (1) {
        // Check if a scancode is available
        if (!(KBD_STATUS & 1))
            continue;

        // Read scancode (also clears valid flag)
        unsigned int code = KBD_DATA;

        // PS/2 break prefix: 0xF0 means next byte is a release code
        if (code == 0xF0) {
            release_next = 1;
            continue;
        }

        if (release_next) {
            release_next = 0;
            continue;  // ignore key release
        }

        // Convert to ASCII
        if (code < 128) {
            char ch = scancode_to_ascii[code];
            if (ch) {
                putc_both(ch);
                if (ch == '\n')
                    uart_putc('\r');  // UART needs CR+LF
            }
        }
    }

    return 1;  // x3 = 1 → PASS (never reached)
}
