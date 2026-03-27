// FPGA diagnostic — visual test of CPU operations.
// Fills the screen green first, then overwrites specific rows
// based on test results (green=pass, red=fail, blue=reached).
// No UART or library calls — pure inline code.

#define FB_BASE    ((volatile unsigned int *)0x80000000)
#define FB_WIDTH   320
#define FB_HEIGHT  240
#define FB_WORDS_PER_ROW  (FB_WIDTH / 4)  // 80

// RGB332 colors packed 4 per word
#define GREEN4   0x1C1C1C1C   // rgb332(0,7,0) × 4
#define RED4     0xE0E0E0E0   // rgb332(7,0,0) × 4
#define BLUE4    0x03030303   // rgb332(0,0,3) × 4
#define WHITE4   0xFFFFFFFF
#define YELLOW4  0xFCFCFCFC   // rgb332(7,7,0) × 4
#define CYAN4    0x1F1F1F1F   // rgb332(0,7,3) × 4
#define MAGENTA4 0xE3E3E3E3   // rgb332(7,0,3) × 4

static void fill_rows(int y_start, int y_end, unsigned int color4) {
    for (int y = y_start; y < y_end; y++) {
        unsigned int *row = (unsigned int *)FB_BASE + y * FB_WORDS_PER_ROW;
        for (int x = 0; x < FB_WORDS_PER_ROW; x++)
            row[x] = color4;
    }
}

// Prevent compiler from optimizing away
static volatile unsigned int sink;

int main(void) {
    // ────────────────────────────────────────────────────────
    // Phase 1: Fill entire screen GREEN
    //   If you see ALL GREEN → CPU runs, FB works, everything below passed
    //   If you see GREEN with some other-colored rows → see which rows
    // ────────────────────────────────────────────────────────
    fill_rows(0, 240, GREEN4);

    // ────────────────────────────────────────────────────────
    // Phase 2: Test SRL (logical right shift)
    //   Rows 30-39: green if pass, red if fail
    // ────────────────────────────────────────────────────────
    {
        volatile unsigned int a = 0x80000000;
        unsigned int r = a >> 3;   // SRL: should be 0x10000000
        if (r == 0x10000000)
            fill_rows(30, 40, GREEN4);  // already green, just confirms
        else
            fill_rows(30, 40, RED4);    // RED = SRL broken
    }

    // ────────────────────────────────────────────────────────
    // Phase 3: Test SRA (arithmetic right shift)
    //   Rows 40-49: green if pass, red if fail
    // ────────────────────────────────────────────────────────
    {
        volatile int a = -128;  // 0xFFFFFF80
        int r = a >> 3;    // SRA: should be -16 (0xFFFFFFF0)
        if (r == -16)
            fill_rows(40, 50, GREEN4);
        else
            fill_rows(40, 50, RED4);
    }

    // ────────────────────────────────────────────────────────
    // Phase 4: Test SLL (left shift)
    //   Rows 50-59: green if pass, red if fail
    // ────────────────────────────────────────────────────────
    {
        volatile unsigned int a = 0x00000001;
        unsigned int r = a << 17;   // SLL: should be 0x00020000
        if (r == 0x00020000)
            fill_rows(50, 60, GREEN4);
        else
            fill_rows(50, 60, RED4);
    }

    // ────────────────────────────────────────────────────────
    // Phase 5: Test MUL
    //   Rows 70-79: green if pass, red if fail
    // ────────────────────────────────────────────────────────
    {
        volatile int a = 123, b = 456;
        int r = a * b;   // MUL: should be 56088
        if (r == 56088)
            fill_rows(70, 80, GREEN4);
        else
            fill_rows(70, 80, RED4);
    }

    // ────────────────────────────────────────────────────────
    // Phase 6: Test MULH (signed high multiply)
    //   Rows 80-89: green if pass, red if fail
    // ────────────────────────────────────────────────────────
    {
        volatile int a = 0x7FFFFFFF, b = 0x7FFFFFFF;
        // (2^31-1)^2 = 0x3FFFFFFF_00000001
        // MULH should return 0x3FFFFFFF
        long long full = (long long)a * (long long)b;
        int hi = (int)(full >> 32);
        if (hi == 0x3FFFFFFF)
            fill_rows(80, 90, GREEN4);
        else
            fill_rows(80, 90, RED4);
    }

    // ────────────────────────────────────────────────────────
    // Phase 7: Test DIVU (unsigned division)
    //   Rows 100-109: green if pass, red if fail
    // ────────────────────────────────────────────────────────
    {
        volatile unsigned int a = 1000000, b = 7;
        unsigned int r = a / b;   // DIVU: should be 142857
        if (r == 142857)
            fill_rows(100, 110, GREEN4);
        else
            fill_rows(100, 110, RED4);
    }

    // ────────────────────────────────────────────────────────
    // Phase 8: Test DIV (signed division)
    //   Rows 110-119: green if pass, red if fail
    // ────────────────────────────────────────────────────────
    {
        volatile int a = -1000000, b = 7;
        int r = a / b;   // DIV: should be -142857
        if (r == -142857)
            fill_rows(110, 120, GREEN4);
        else
            fill_rows(110, 120, RED4);
    }

    // ────────────────────────────────────────────────────────
    // Phase 9: Test REMU (unsigned remainder)
    //   Rows 120-129: green if pass, red if fail
    // ────────────────────────────────────────────────────────
    {
        volatile unsigned int a = 1000000, b = 7;
        unsigned int r = a % b;   // REMU: should be 1000000 - 142857*7 = 1
        if (r == 1)
            fill_rows(120, 130, GREEN4);
        else
            fill_rows(120, 130, RED4);
    }

    // ────────────────────────────────────────────────────────
    // Phase 10: Test UART (does uart_putc hang?)
    //   Rows 140-149: BLUE before UART, CYAN after UART
    //   If you see BLUE but not CYAN → UART hangs
    // ────────────────────────────────────────────────────────
    fill_rows(140, 150, BLUE4);  // mark: UART test starting
    {
        // Inline UART putc — send one byte
        volatile unsigned int *uart_tx     = (volatile unsigned int *)0x10000000;
        volatile unsigned int *uart_status = (volatile unsigned int *)0x10000004;
        while (!(*uart_status & 1)) ;  // wait for tx_ready
        *uart_tx = 'A';
        // Wait for it to finish
        while (!(*uart_status & 1)) ;
    }
    fill_rows(140, 150, CYAN4);  // mark: UART completed

    // ────────────────────────────────────────────────────────
    // Phase 11: Test 64-bit division (like fx_div uses)
    //   Rows 160-169: green if pass, red if fail
    //   This is: ((long long)15728640 << 16) / (long long)819200
    //   Expected: 1258291 (≈19.2 as Q16.16)
    // ────────────────────────────────────────────────────────
    {
        volatile int a = 15728640;   // FX(240) = 240 << 16
        volatile int b = 819200;     // 12.5 in Q16.16
        long long num = (long long)a << 16;
        int r = (int)(num / (long long)b);
        // Expected: 1258291 (0x133333)
        if (r == 1258291)
            fill_rows(160, 170, GREEN4);
        else
            fill_rows(160, 170, RED4);
    }

    // ────────────────────────────────────────────────────────
    // Phase 12: Test function call with return value
    //   Rows 180-189: green if pass, red if fail
    // ────────────────────────────────────────────────────────
    {
        volatile int a = 42;
        volatile int b = 58;
        int r = a + b;  // simple arithmetic via volatile loads
        if (r == 100)
            fill_rows(180, 190, GREEN4);
        else
            fill_rows(180, 190, RED4);
    }

    // ────────────────────────────────────────────────────────
    // Phase 13: Final marker — bottom rows YELLOW
    //   If you see yellow at the bottom → all tests completed
    // ────────────────────────────────────────────────────────
    fill_rows(230, 240, YELLOW4);

    while (1) ;
    return 0;
}
