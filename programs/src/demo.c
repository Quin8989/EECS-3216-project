// demo.c — Interactive hardware test suite with program launcher
//
// Run on FPGA after programming. Outputs results via UART (115200 baud)
// and shows text results on VGA display.
//
// Controls:
//   W/S = Navigate menu
//   SPACE = Run selected test or launch program
//
// Usage:
//   1. Build: bash tools/build.sh demo
//   2. Update ROM banks and resynthesize
//   3. Program FPGA
//   4. Start keyboard server + keyboard_inject.py

#include "wolf3d.h"

// ═══════════════════════════════════════════════════════════════════════════
// PERIPHERAL ADDRESSES
// ═══════════════════════════════════════════════════════════════════════════

#define UART_TX      (*(volatile unsigned int *)0x10000000)
#define UART_STATUS  (*(volatile unsigned int *)0x10000004)
#define TIMER_COUNT  (*(volatile unsigned int *)0x20000000)
#define VGA_STATUS   (*(volatile unsigned int *)0x30000000)
#define KBD_DATA     (*(volatile unsigned int *)0x40000000)
#define KBD_STATUS   (*(volatile unsigned int *)0x40000004)
#define RAM_BASE     ((volatile unsigned char *)0x02000000)
#define FB_BASE      ((volatile unsigned char *)0x80000000)

#define FB_WIDTH   320
#define FB_HEIGHT  240

// RGB332 colors
#define COL_WHITE  0xFF
#define COL_GREEN  0x1C
#define COL_RED    0xE0
#define COL_BLUE   0x03
#define COL_YELLOW 0xFC
#define COL_CYAN   0x1F
#define COL_BLACK  0x00

// ═══════════════════════════════════════════════════════════════════════════
// 8x8 FONT BITMAP (ASCII 32-127)
// ═══════════════════════════════════════════════════════════════════════════

static const unsigned char font8x8[96][8] = {
  {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, // ' '
  {0x18,0x3C,0x3C,0x18,0x18,0x00,0x18,0x00}, // '!'
  {0x6C,0x6C,0x00,0x00,0x00,0x00,0x00,0x00}, // '"'
  {0x6C,0xFE,0x6C,0x6C,0xFE,0x6C,0x00,0x00}, // '#'
  {0x18,0x7E,0xC0,0x7C,0x06,0xFC,0x18,0x00}, // '$'
  {0xC6,0xCC,0x18,0x30,0x66,0xC6,0x00,0x00}, // '%'
  {0x38,0x6C,0x38,0x76,0xDC,0xCC,0x76,0x00}, // '&'
  {0x30,0x30,0x60,0x00,0x00,0x00,0x00,0x00}, // '''
  {0x0C,0x18,0x30,0x30,0x30,0x18,0x0C,0x00}, // '('
  {0x30,0x18,0x0C,0x0C,0x0C,0x18,0x30,0x00}, // ')'
  {0x00,0x66,0x3C,0xFF,0x3C,0x66,0x00,0x00}, // '*'
  {0x00,0x18,0x18,0x7E,0x18,0x18,0x00,0x00}, // '+'
  {0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x30}, // ','
  {0x00,0x00,0x00,0x7E,0x00,0x00,0x00,0x00}, // '-'
  {0x00,0x00,0x00,0x00,0x00,0x18,0x18,0x00}, // '.'
  {0x06,0x0C,0x18,0x30,0x60,0xC0,0x80,0x00}, // '/'
  {0x7C,0xC6,0xCE,0xDE,0xF6,0xE6,0x7C,0x00}, // '0'
  {0x18,0x38,0x18,0x18,0x18,0x18,0x7E,0x00}, // '1'
  {0x7C,0xC6,0x06,0x1C,0x70,0xC6,0xFE,0x00}, // '2'
  {0x7C,0xC6,0x06,0x3C,0x06,0xC6,0x7C,0x00}, // '3'
  {0x1C,0x3C,0x6C,0xCC,0xFE,0x0C,0x1E,0x00}, // '4'
  {0xFE,0xC0,0xFC,0x06,0x06,0xC6,0x7C,0x00}, // '5'
  {0x3C,0x60,0xC0,0xFC,0xC6,0xC6,0x7C,0x00}, // '6'
  {0xFE,0xC6,0x0C,0x18,0x30,0x30,0x30,0x00}, // '7'
  {0x7C,0xC6,0xC6,0x7C,0xC6,0xC6,0x7C,0x00}, // '8'
  {0x7C,0xC6,0xC6,0x7E,0x06,0x0C,0x78,0x00}, // '9'
  {0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x00}, // ':'
  {0x00,0x18,0x18,0x00,0x00,0x18,0x18,0x30}, // ';'
  {0x0C,0x18,0x30,0x60,0x30,0x18,0x0C,0x00}, // '<'
  {0x00,0x00,0x7E,0x00,0x00,0x7E,0x00,0x00}, // '='
  {0x60,0x30,0x18,0x0C,0x18,0x30,0x60,0x00}, // '>'
  {0x7C,0xC6,0x0C,0x18,0x18,0x00,0x18,0x00}, // '?'
  {0x7C,0xC6,0xDE,0xDE,0xDC,0xC0,0x7C,0x00}, // '@'
  {0x38,0x6C,0xC6,0xFE,0xC6,0xC6,0xC6,0x00}, // 'A'
  {0xFC,0x66,0x66,0x7C,0x66,0x66,0xFC,0x00}, // 'B'
  {0x3C,0x66,0xC0,0xC0,0xC0,0x66,0x3C,0x00}, // 'C'
  {0xF8,0x6C,0x66,0x66,0x66,0x6C,0xF8,0x00}, // 'D'
  {0xFE,0x62,0x68,0x78,0x68,0x62,0xFE,0x00}, // 'E'
  {0xFE,0x62,0x68,0x78,0x68,0x60,0xF0,0x00}, // 'F'
  {0x3C,0x66,0xC0,0xC0,0xCE,0x66,0x3A,0x00}, // 'G'
  {0xC6,0xC6,0xC6,0xFE,0xC6,0xC6,0xC6,0x00}, // 'H'
  {0x3C,0x18,0x18,0x18,0x18,0x18,0x3C,0x00}, // 'I'
  {0x1E,0x0C,0x0C,0x0C,0xCC,0xCC,0x78,0x00}, // 'J'
  {0xE6,0x66,0x6C,0x78,0x6C,0x66,0xE6,0x00}, // 'K'
  {0xF0,0x60,0x60,0x60,0x62,0x66,0xFE,0x00}, // 'L'
  {0xC6,0xEE,0xFE,0xFE,0xD6,0xC6,0xC6,0x00}, // 'M'
  {0xC6,0xE6,0xF6,0xDE,0xCE,0xC6,0xC6,0x00}, // 'N'
  {0x7C,0xC6,0xC6,0xC6,0xC6,0xC6,0x7C,0x00}, // 'O'
  {0xFC,0x66,0x66,0x7C,0x60,0x60,0xF0,0x00}, // 'P'
  {0x7C,0xC6,0xC6,0xC6,0xD6,0xDE,0x7C,0x06}, // 'Q'
  {0xFC,0x66,0x66,0x7C,0x6C,0x66,0xE6,0x00}, // 'R'
  {0x7C,0xC6,0x60,0x38,0x0C,0xC6,0x7C,0x00}, // 'S'
  {0x7E,0x7E,0x5A,0x18,0x18,0x18,0x3C,0x00}, // 'T'
  {0xC6,0xC6,0xC6,0xC6,0xC6,0xC6,0x7C,0x00}, // 'U'
  {0xC6,0xC6,0xC6,0xC6,0xC6,0x6C,0x38,0x00}, // 'V'
  {0xC6,0xC6,0xC6,0xD6,0xFE,0xEE,0xC6,0x00}, // 'W'
  {0xC6,0xC6,0x6C,0x38,0x6C,0xC6,0xC6,0x00}, // 'X'
  {0x66,0x66,0x66,0x3C,0x18,0x18,0x3C,0x00}, // 'Y'
  {0xFE,0xC6,0x8C,0x18,0x32,0x66,0xFE,0x00}, // 'Z'
  {0x3C,0x30,0x30,0x30,0x30,0x30,0x3C,0x00}, // '['
  {0xC0,0x60,0x30,0x18,0x0C,0x06,0x02,0x00}, // '\'
  {0x3C,0x0C,0x0C,0x0C,0x0C,0x0C,0x3C,0x00}, // ']'
  {0x10,0x38,0x6C,0xC6,0x00,0x00,0x00,0x00}, // '^'
  {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFF}, // '_'
  {0x30,0x30,0x18,0x00,0x00,0x00,0x00,0x00}, // '`'
  {0x00,0x00,0x78,0x0C,0x7C,0xCC,0x76,0x00}, // 'a'
  {0xE0,0x60,0x60,0x7C,0x66,0x66,0xDC,0x00}, // 'b'
  {0x00,0x00,0x78,0xCC,0xC0,0xCC,0x78,0x00}, // 'c'
  {0x1C,0x0C,0x0C,0x7C,0xCC,0xCC,0x76,0x00}, // 'd'
  {0x00,0x00,0x78,0xCC,0xFC,0xC0,0x78,0x00}, // 'e'
  {0x38,0x6C,0x64,0xF0,0x60,0x60,0xF0,0x00}, // 'f'
  {0x00,0x00,0x76,0xCC,0xCC,0x7C,0x0C,0xF8}, // 'g'
  {0xE0,0x60,0x6C,0x76,0x66,0x66,0xE6,0x00}, // 'h'
  {0x18,0x00,0x38,0x18,0x18,0x18,0x3C,0x00}, // 'i'
  {0x06,0x00,0x06,0x06,0x06,0x66,0x66,0x3C}, // 'j'
  {0xE0,0x60,0x66,0x6C,0x78,0x6C,0xE6,0x00}, // 'k'
  {0x38,0x18,0x18,0x18,0x18,0x18,0x3C,0x00}, // 'l'
  {0x00,0x00,0xEC,0xFE,0xD6,0xD6,0xC6,0x00}, // 'm'
  {0x00,0x00,0xDC,0x66,0x66,0x66,0x66,0x00}, // 'n'
  {0x00,0x00,0x78,0xCC,0xCC,0xCC,0x78,0x00}, // 'o'
  {0x00,0x00,0xDC,0x66,0x66,0x7C,0x60,0xF0}, // 'p'
  {0x00,0x00,0x76,0xCC,0xCC,0x7C,0x0C,0x1E}, // 'q'
  {0x00,0x00,0xDC,0x76,0x66,0x60,0xF0,0x00}, // 'r'
  {0x00,0x00,0x7C,0xC0,0x78,0x0C,0xF8,0x00}, // 's'
  {0x10,0x30,0x7C,0x30,0x30,0x34,0x18,0x00}, // 't'
  {0x00,0x00,0xCC,0xCC,0xCC,0xCC,0x76,0x00}, // 'u'
  {0x00,0x00,0xCC,0xCC,0xCC,0x78,0x30,0x00}, // 'v'
  {0x00,0x00,0xC6,0xD6,0xD6,0xFE,0x6C,0x00}, // 'w'
  {0x00,0x00,0xC6,0x6C,0x38,0x6C,0xC6,0x00}, // 'x'
  {0x00,0x00,0xCC,0xCC,0xCC,0x7C,0x0C,0xF8}, // 'y'
  {0x00,0x00,0xFC,0x98,0x30,0x64,0xFC,0x00}, // 'z'
  {0x1C,0x30,0x30,0xE0,0x30,0x30,0x1C,0x00}, // '{'
  {0x18,0x18,0x18,0x00,0x18,0x18,0x18,0x00}, // '|'
  {0xE0,0x30,0x30,0x1C,0x30,0x30,0xE0,0x00}, // '}'
  {0x76,0xDC,0x00,0x00,0x00,0x00,0x00,0x00}, // '~'
  {0x00,0x10,0x38,0x6C,0xC6,0xC6,0xFE,0x00}, // DEL (box)
};

// ═══════════════════════════════════════════════════════════════════════════
// VGA TEXT RENDERING
// ═══════════════════════════════════════════════════════════════════════════

static int cursor_x = 0;
static int cursor_y = 0;
static unsigned char text_fg = COL_WHITE;
static unsigned char text_bg = COL_BLACK;

static void vga_put_pixel(int x, int y, unsigned char color) {
    if (x >= 0 && x < FB_WIDTH && y >= 0 && y < FB_HEIGHT)
        FB_BASE[y * FB_WIDTH + x] = color;
}

static void vga_draw_char(int x, int y, char c, unsigned char fg, unsigned char bg) {
    int idx = c - 32;
    if (idx < 0 || idx >= 96) idx = 0;
    const unsigned char *glyph = font8x8[idx];
    for (int row = 0; row < 8; row++) {
        unsigned char bits = glyph[row];
        for (int col = 0; col < 8; col++) {
            unsigned char color = (bits & (0x80 >> col)) ? fg : bg;
            vga_put_pixel(x + col, y + row, color);
        }
    }
}

static void vga_print(const char *s) {
    while (*s) {
        char c = *s++;
        if (c == '\n') {
            cursor_x = 0;
            cursor_y += 8;
        } else if (c == '\r') {
            cursor_x = 0;
        } else {
            vga_draw_char(cursor_x, cursor_y, c, text_fg, text_bg);
            cursor_x += 8;
            if (cursor_x >= FB_WIDTH) {
                cursor_x = 0;
                cursor_y += 8;
            }
        }
    }
}

static void vga_set_color(unsigned char fg, unsigned char bg) {
    text_fg = fg;
    text_bg = bg;
}

static void vga_set_cursor(int x, int y) {
    cursor_x = x;
    cursor_y = y;
}

static void clear_screen(void) {
    for (int i = 0; i < FB_WIDTH * FB_HEIGHT; i++)
        FB_BASE[i] = COL_BLACK;
    cursor_x = 0;
    cursor_y = 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// UART OUTPUT
// ═══════════════════════════════════════════════════════════════════════════

static void uart_putc(char c) {
    while (!(UART_STATUS & 1)) ;
    UART_TX = (unsigned int)c;
}

static void uart_puts(const char *s) {
    while (*s) uart_putc(*s++);
}

// ═══════════════════════════════════════════════════════════════════════════
// KEYBOARD INPUT
// ═══════════════════════════════════════════════════════════════════════════

static unsigned char read_key(void) {
    // Poll until key available
    while (!(KBD_STATUS & 1)) ;
    return (unsigned char)KBD_DATA;
}

static int key_available(void) {
    return KBD_STATUS & 1;
}

static unsigned char read_key_nonblock(void) {
    if (KBD_STATUS & 1)
        return (unsigned char)KBD_DATA;
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// TEST FRAMEWORK
// ═══════════════════════════════════════════════════════════════════════════

#define NUM_TESTS 10

static int test_num = 0;
static int tests_passed = 0;
static int tests_failed = 0;

// Prevent compiler from optimizing away
static volatile unsigned int sink;
#define VOL(x) ({ volatile unsigned int _v = (x); _v; })

static void print_num(int n) {
    char buf[12];
    int i = 0;
    if (n < 0) {
        uart_putc('-');
        vga_print("-");
        n = -n;
    }
    do {
        buf[i++] = '0' + (n % 10);
        n /= 10;
    } while (n > 0);
    while (--i >= 0) {
        uart_putc(buf[i]);
        char s[2] = {buf[i], 0};
        vga_print(s);
    }
}

static void report_pass(const char *name) {
    uart_puts(" PASS\r\n");
    vga_set_color(COL_GREEN, COL_BLACK);
    vga_print(" PASS\n");
    tests_passed++;
}

static void report_fail(const char *name, int err) {
    uart_puts(" FAIL (err ");
    vga_set_color(COL_RED, COL_BLACK);
    vga_print(" FAIL err ");
    print_num(err);
    uart_puts(")\r\n");
    vga_print("\n");
    tests_failed++;
}

static void start_test(const char *name) {
    vga_set_color(COL_WHITE, COL_BLACK);
    
    // Print test number
    char num[4];
    num[0] = '0' + ((test_num + 1) / 10);
    num[1] = '0' + ((test_num + 1) % 10);
    num[2] = ' ';
    num[3] = 0;
    
    uart_puts("[");
    uart_putc(num[0]);
    uart_putc(num[1]);
    uart_puts("] ");
    uart_puts(name);
    
    vga_print(num);
    vga_print(name);
    
    // Pad with dots
    int len = 0;
    for (const char *p = name; *p; p++) len++;
    for (int i = len; i < 20; i++) {
        uart_putc('.');
        vga_print(".");
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// TEST 1: UART TX
// ═══════════════════════════════════════════════════════════════════════════

static int test_uart_tx(void) {
    // If we got here and you can read this, UART works
    // But let's verify the status register behavior
    
    // Wait for idle
    int timeout = 100000;
    while (!(UART_STATUS & 1) && --timeout > 0) ;
    if (timeout == 0) return -1;
    
    // Send a byte
    UART_TX = 'X';
    
    // Should be busy now (or very briefly)
    // Then become ready again
    timeout = 100000;
    while (!(UART_STATUS & 1) && --timeout > 0) ;
    if (timeout == 0) return -2;
    
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// TEST 2: TIMER
// ═══════════════════════════════════════════════════════════════════════════

static int test_timer(void) {
    // Test monotonicity
    unsigned int prev = TIMER_COUNT;
    for (int i = 0; i < 100; i++) {
        unsigned int cur = TIMER_COUNT;
        if (cur < prev) return -1;  // went backward
        prev = cur;
    }
    
    // Test reset and elapsed
    TIMER_COUNT = 0;
    for (volatile int i = 0; i < 500; i++) ;
    unsigned int elapsed = TIMER_COUNT;
    if (elapsed == 0) return -2;      // didn't advance
    if (elapsed > 100000) return -3;  // way too high
    
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// TEST 3: ROM COLD BOOT (sin_table from trig.h)
// ═══════════════════════════════════════════════════════════════════════════

// Import sin_table - it's in ROM (.rodata)
#include "trig.h"

static void uart_print_hex(unsigned int val) {
    static const char hex[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4) {
        uart_putc(hex[(val >> i) & 0xF]);
    }
}

static int test_rom_coldboot(void) {
    // Read known values from sin_table immediately
    // These must match the Q16.16 trig values
    
    volatile int v0 = sin_table[0];    // sin(0) = 0
    volatile int v64 = sin_table[64];  // sin(90°) = cos(0) = 1.0 = 0x10000
    volatile int v128 = sin_table[128]; // sin(180°) = 0
    volatile int v192 = sin_table[192]; // sin(270°) = -1.0 = 0xFFFF0000
    
    // Debug: print values on failure
    if (v0 != 0) {
        uart_puts("\r\n[DEBUG] sin_table[0] = ");
        uart_print_hex(v0);
        uart_puts(" @ addr ");
        uart_print_hex((unsigned int)&sin_table[0]);
        uart_puts("\r\n");
        return -1;
    }
    if (v64 != 0x00010000) return -2;
    if (v128 != 0) return -3;
    if (v192 != (int)0xFFFF0000) return -4;
    
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// TEST 4: RAM WORD ACCESS (LW/SW)
// ═══════════════════════════════════════════════════════════════════════════

static int test_ram_word(void) {
    // Use addresses at offset 0x1000 (4KB) to avoid clobbering initialized data
    // (.data section starts at RAM_BASE and may contain globals like sin_table)
    volatile unsigned int *ram = (volatile unsigned int *)(RAM_BASE + 0x1000);
    
    // Write pattern
    ram[0] = 0xDEADBEEF;
    ram[1] = 0x12345678;
    ram[2] = 0x00000000;
    ram[3] = 0xFFFFFFFF;
    
    // Read back
    if (ram[0] != 0xDEADBEEF) return -1;
    if (ram[1] != 0x12345678) return -2;
    if (ram[2] != 0x00000000) return -3;
    if (ram[3] != 0xFFFFFFFF) return -4;
    
    // Test different address
    ram[100] = 0xCAFEBABE;
    if (ram[100] != 0xCAFEBABE) return -5;
    
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// TEST 5: RAM BYTE/HALF ACCESS (LB/LH/SB/SH + sign extension)
// ═══════════════════════════════════════════════════════════════════════════

static int test_ram_byte_half(void) {
    // Use high addresses to avoid clobbering initialized data
    volatile unsigned char *rb = (volatile unsigned char *)(RAM_BASE + 0x1100);
    volatile unsigned short *rh = (volatile unsigned short *)(RAM_BASE + 0x1200);
    
    // Byte write/read
    rb[0] = 0x12;
    rb[1] = 0x34;
    rb[2] = 0x80;  // negative as signed
    rb[3] = 0xFF;
    
    if (rb[0] != 0x12) return -1;
    if (rb[1] != 0x34) return -2;
    if (rb[2] != 0x80) return -3;
    if (rb[3] != 0xFF) return -4;
    
    // Sign extension test (LB vs LBU)
    volatile signed char *rbs = (volatile signed char *)(RAM_BASE + 0x1100);
    if (rbs[2] != -128) return -5;  // 0x80 sign-extended = -128
    if (rb[2] != 128) return -6;    // 0x80 zero-extended = 128
    
    // Halfword write/read
    rh[0] = 0x1234;
    rh[1] = 0x8000;  // negative as signed
    rh[2] = 0xFFFF;
    
    if (rh[0] != 0x1234) return -7;
    if (rh[1] != 0x8000) return -8;
    if (rh[2] != 0xFFFF) return -9;
    
    // Sign extension (LH vs LHU)
    volatile signed short *rhs = (volatile signed short *)(RAM_BASE + 0x1200);
    if (rhs[1] != -32768) return -10;  // 0x8000 sign-extended
    
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// TEST 6: FRAMEBUFFER R/W
// ═══════════════════════════════════════════════════════════════════════════

static int test_framebuffer(void) {
    // Test a few pixel locations (using bottom rows to not disturb text)
    int test_y = FB_HEIGHT - 10;  // near bottom
    int idx0 = test_y * FB_WIDTH;
    int idx1 = test_y * FB_WIDTH + 100;
    int idx2 = test_y * FB_WIDTH + 200;  // safer than absolute last pixel
    
    // Save original
    unsigned char orig0 = FB_BASE[idx0];
    unsigned char orig1 = FB_BASE[idx1];
    unsigned char orig2 = FB_BASE[idx2];
    
    // Write test pattern
    FB_BASE[idx0] = 0xAA;
    FB_BASE[idx1] = 0x55;
    FB_BASE[idx2] = 0xDE;
    
    // Read back
    if (FB_BASE[idx0] != 0xAA) return -1;
    if (FB_BASE[idx1] != 0x55) return -2;
    if (FB_BASE[idx2] != 0xDE) return -3;
    
    // Restore
    FB_BASE[idx0] = orig0;
    FB_BASE[idx1] = orig1;
    FB_BASE[idx2] = orig2;
    
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// TEST 7: VGA VBLANK
// ═══════════════════════════════════════════════════════════════════════════

static int test_vga_vblank(void) {
    int timeout;
    
    // Wait for active video (vblank=0)
    timeout = 2000000;  // ~80ms at 25MHz
    while ((VGA_STATUS & 1) && --timeout > 0) ;
    if (timeout == 0) return -1;  // stuck in vblank
    
    // Wait for vblank to start (vblank=1)
    timeout = 2000000;
    while (!(VGA_STATUS & 1) && --timeout > 0) ;
    if (timeout == 0) return -2;  // vblank never came
    
    // One more transition to confirm it's cycling
    timeout = 2000000;
    while ((VGA_STATUS & 1) && --timeout > 0) ;
    if (timeout == 0) return -3;
    
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// TEST 8: CPU SHIFTS (SLL/SRL/SRA)
// ═══════════════════════════════════════════════════════════════════════════

static int test_cpu_shifts(void) {
    // SLL (shift left logical)
    if ((VOL(1) << VOL(0)) != 1) return -1;
    if ((VOL(1) << VOL(31)) != 0x80000000) return -2;
    if ((VOL(0xFFFFFFFF) << VOL(1)) != 0xFFFFFFFE) return -3;
    
    // SRL (shift right logical - zero fill)
    if ((VOL(0x80000000) >> VOL(1)) != 0x40000000) return -4;
    if ((VOL(0xFFFFFFFF) >> VOL(31)) != 1) return -5;
    if ((VOL(0x80000000) >> VOL(31)) != 1) return -6;
    
    // SRA (shift right arithmetic - sign extend)
    int neg = (int)VOL(0x80000000);
    if ((neg >> VOL(1)) != (int)0xC0000000) return -7;
    if ((neg >> VOL(31)) != -1) return -8;
    
    int pos = (int)VOL(0x7FFFFFFF);
    if ((pos >> VOL(1)) != 0x3FFFFFFF) return -9;
    
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// TEST 9: CPU BRANCHES (BEQ/BNE/BLT/BGE/BLTU/BGEU)
// ═══════════════════════════════════════════════════════════════════════════

static int test_cpu_branches(void) {
    // BEQ/BNE
    if (!(VOL(0) == VOL(0))) return -1;
    if (VOL(0) == VOL(1)) return -2;
    
    // BLT (signed)
    if (!((int)VOL(0xFFFFFFFF) < (int)VOL(0))) return -3;  // -1 < 0
    if ((int)VOL(0) < (int)VOL(0xFFFFFFFF)) return -4;
    
    // BLTU (unsigned)
    if (VOL(0xFFFFFFFF) < VOL(0)) return -5;  // 0xFFFFFFFF > 0 unsigned
    if (!(VOL(0) < VOL(0xFFFFFFFF))) return -6;
    
    // BGE (signed)
    if (!((int)VOL(0) >= (int)VOL(0))) return -7;
    if (!((int)VOL(0) >= (int)VOL(0xFFFFFFFF))) return -8;  // 0 >= -1
    
    // BGEU (unsigned)
    if (!(VOL(0xFFFFFFFF) >= VOL(0))) return -9;
    if (!(VOL(5) >= VOL(5))) return -10;
    
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// TEST 10: MUL/DIV/REM (M-extension)
// ═══════════════════════════════════════════════════════════════════════════

static int test_mul_div_rem(void) {
    // Basic MUL
    if (VOL(7) * VOL(6) != 42) return -1;
    if (VOL(0) * VOL(12345) != 0) return -2;
    if (VOL(0x10000) * VOL(0x10000) != 0) return -3;  // overflow wrap
    
    // Signed MUL
    int a = (int)VOL(0xFFFFFFFF);  // -1
    int b = (int)VOL(0xFFFFFFFF);  // -1
    if ((unsigned)(a * b) != 1) return -4;  // -1 * -1 = 1
    
    a = (int)VOL(0xFFFFFFFE);  // -2
    b = (int)VOL(3);
    if ((unsigned)(a * b) != (unsigned)-6) return -5;
    
    // DIV
    if (VOL(42) / VOL(6) != 7) return -6;
    if (VOL(7) / VOL(3) != 2) return -7;
    
    // Signed DIV (round toward zero)
    if ((int)VOL(0xFFFFFFF9) / (int)VOL(3) != -2) return -8;  // -7 / 3 = -2
    
    // DIV by zero (RISC-V spec: result = -1)
    if (VOL(5) / VOL(0) != 0xFFFFFFFF) return -9;
    
    // REM
    if (VOL(7) % VOL(3) != 1) return -10;
    if ((int)VOL(0xFFFFFFF9) % (int)VOL(3) != -1) return -11;  // -7 % 3 = -1
    
    // REM by zero (RISC-V spec: result = dividend)
    if (VOL(5) % VOL(0) != 5) return -12;
    
    return 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════

typedef int (*test_fn)(void);

static const struct {
    const char *name;
    test_fn fn;
} tests[] = {
    { "UART TX",           test_uart_tx },
    { "Timer",             test_timer },
    { "ROM cold boot",     test_rom_coldboot },
    { "RAM word access",   test_ram_word },
    { "RAM byte/half",     test_ram_byte_half },
    { "Framebuffer R/W",   test_framebuffer },
    { "VGA vblank",        test_vga_vblank },
    { "CPU shifts",        test_cpu_shifts },
    { "CPU branches",      test_cpu_branches },
    { "MUL/DIV/REM",       test_mul_div_rem },
};

// ═══════════════════════════════════════════════════════════════════════════
// MENU AND TEST RUNNER
// ═══════════════════════════════════════════════════════════════════════════

// Test result states: 0=not run, 1=pass, -1=fail
static int test_results[NUM_TESTS];

// Menu: 10 tests + Run ALL + Wolf3D
#define MENU_RUN_ALL  NUM_TESTS
#define MENU_WOLF3D   (NUM_TESTS + 1)
#define MENU_ITEMS    (NUM_TESTS + 2)

static int menu_selected = 0;

static void draw_menu(void) {
    clear_screen();
    
    vga_set_color(COL_YELLOW, COL_BLACK);
    vga_print("=== HARDWARE TEST SUITE ===\n\n");
    
    // Draw test list with inline results
    for (int i = 0; i < NUM_TESTS; i++) {
        if (i == menu_selected) {
            vga_set_color(COL_BLACK, COL_WHITE);
            vga_print("> ");
        } else {
            vga_set_color(COL_WHITE, COL_BLACK);
            vga_print("  ");
        }
        vga_print(tests[i].name);
        
        // Pad name to column 20
        int len = 0;
        for (const char *p = tests[i].name; *p; p++) len++;
        for (int j = len; j < 18; j++) vga_print(" ");
        
        // Show result
        if (test_results[i] == 1) {
            vga_set_color(COL_GREEN, COL_BLACK);
            vga_print("PASS");
        } else if (test_results[i] < 0) {
            vga_set_color(COL_RED, COL_BLACK);
            vga_print("FAIL ");
            // Print error code
            int err = -test_results[i];
            if (err >= 10) {
                char c = '0' + (err / 10);
                char s[2] = {c, 0};
                vga_print(s);
            }
            char c = '0' + (err % 10);
            char s[2] = {c, 0};
            vga_print(s);
        } else {
            vga_set_color(COL_WHITE, COL_BLACK);
            vga_print("    ");
        }
        
        if (i == menu_selected) {
            vga_print("  ");  // clear highlight tail
        }
        vga_set_color(COL_WHITE, COL_BLACK);
        vga_print("\n");
    }
    
    vga_print("\n");
    
    // "Run ALL" option
    if (menu_selected == MENU_RUN_ALL) {
        vga_set_color(COL_BLACK, COL_GREEN);
        vga_print("> Run ALL tests              ");
    } else {
        vga_set_color(COL_GREEN, COL_BLACK);
        vga_print("  Run ALL tests");
    }
    vga_set_color(COL_WHITE, COL_BLACK);
    vga_print("\n\n");
    
    // Programs section
    vga_set_color(COL_YELLOW, COL_BLACK);
    vga_print("=== SELECT PROGRAM ===\n\n");
    
    if (menu_selected == MENU_WOLF3D) {
        vga_set_color(COL_BLACK, COL_CYAN);
        vga_print("> Wolf3D                     ");
    } else {
        vga_set_color(COL_CYAN, COL_BLACK);
        vga_print("  Wolf3D");
    }
    vga_set_color(COL_WHITE, COL_BLACK);
    vga_print("\n\n");
    
    vga_set_color(COL_WHITE, COL_BLACK);
    vga_print("W/S: Navigate   SPACE: Select\n");
}

static void run_single_test(int idx) {
    uart_puts("Running: ");
    uart_puts(tests[idx].name);
    uart_puts("...");
    
    int result = tests[idx].fn();
    
    if (result == 0) {
        test_results[idx] = 1;
        tests_passed++;
        uart_puts(" PASS\r\n");
    } else {
        test_results[idx] = result;  // Store actual error code (negative)
        tests_failed++;
        uart_puts(" FAIL\r\n");
    }
}

static void run_all_tests(void) {
    tests_passed = 0;
    tests_failed = 0;
    
    uart_puts("\r\n=== RUNNING ALL TESTS ===\r\n");
    
    for (int i = 0; i < NUM_TESTS; i++) {
        run_single_test(i);
        draw_menu();  // Update display after each test
    }
    
    uart_puts("============================\r\n");
    if (tests_failed == 0) {
        uart_puts("ALL PASSED\r\n");
    } else {
        uart_puts("SOME FAILED\r\n");
    }
}

int main(void) {
    // Initialize test results
    for (int i = 0; i < NUM_TESTS; i++) {
        test_results[i] = 0;
    }
    
    while (1) {
        draw_menu();
        
        unsigned char key = read_key();
        
        if (key == 'w' || key == 'W') {
            if (menu_selected > 0) menu_selected--;
        } else if (key == 's' || key == 'S') {
            if (menu_selected < MENU_ITEMS - 1) menu_selected++;
        } else if (key == ' ' || key == '\r') {
            if (menu_selected < NUM_TESTS) {
                // Run single test
                run_single_test(menu_selected);
            } else if (menu_selected == MENU_RUN_ALL) {
                // Run all tests
                run_all_tests();
            } else if (menu_selected == MENU_WOLF3D) {
                // Launch Wolf3D
                uart_puts("Launching Wolf3D...\r\n");
                clear_screen();
                wolf3d_main();
                // If wolf3d returns, reset results and redraw
                for (int i = 0; i < NUM_TESTS; i++) {
                    test_results[i] = 0;
                }
            }
        }
    }
    
    return 0;
}
