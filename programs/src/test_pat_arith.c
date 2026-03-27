// Pattern Test: Arithmetic (MUL / DIV / REM)
//
// Exercises the CPU's multiply and iterative divider with:
//   - Known MUL identity / boundary values
//   - DIV/REM spec-mandated edge cases (div-by-zero, signed overflow)
//   - A sweep of signed/unsigned division cases
//   - Combined MUL+DIV expression (compiler must emit both)

#include "soc.h"

// Force the compiler to actually execute the operation at runtime,
// not constant-fold it away.  Use volatile to defeat optimisation.
static unsigned int vol(unsigned int x) {
    volatile unsigned int v = x;
    return v;
}


// ── MUL patterns ────────────────────────────────────────────

static int test_mul_basics(void) {
    test_assert_eq(vol(7) * vol(6),  42,  "7*6");
    test_assert_eq(vol(0) * vol(99), 0,   "0*99");
    test_assert_eq(vol(1) * vol(0xFFFFFFFF), 0xFFFFFFFF, "1*-1");
    // 0x10000 * 0x10000 = 0x100000000 → lower 32 = 0
    test_assert_eq(vol(0x10000) * vol(0x10000), 0, "64K*64K wrap");
    return 0;
}

static int test_mul_signed(void) {
    int a = (int)vol(0xFFFFFFFF);  // -1
    int b = (int)vol(0xFFFFFFFF);  // -1
    test_assert_eq((unsigned int)(a * b), 1, "-1*-1");

    a = (int)vol(0xFFFFFFFE);  // -2
    b = (int)vol(3);
    test_assert_eq((unsigned int)(a * b), (unsigned int)-6, "-2*3");
    return 0;
}


// ── DIV: spec edge cases (RISC-V §7.2) ─────────────────────

static int test_div_by_zero(void) {
    // DIV by zero → all-ones (-1 unsigned)
    unsigned int q = vol(17) / vol(0);
    test_assert_eq(q, 0xFFFFFFFF, "17/0 unsigned");

    // Signed div by zero → -1
    int sq = (int)vol(42) / (int)vol(0);
    test_assert_eq((unsigned int)sq, 0xFFFFFFFF, "42/0 signed");
    return 0;
}

static int test_rem_by_zero(void) {
    // REM by zero → dividend
    unsigned int r = vol(17) % vol(0);
    test_assert_eq(r, 17, "17%0 unsigned");

    int sr = (int)vol(42) % (int)vol(0);
    test_assert_eq((unsigned int)sr, 42, "42%0 signed");
    return 0;
}

static int test_signed_overflow(void) {
    // INT_MIN / -1 → INT_MIN (overflow, not undefined)
    int q = (int)vol(0x80000000) / (int)vol(0xFFFFFFFF);
    test_assert_eq((unsigned int)q, 0x80000000, "INT_MIN/-1 quo");

    // INT_MIN % -1 → 0
    int r = (int)vol(0x80000000) % (int)vol(0xFFFFFFFF);
    test_assert_eq((unsigned int)r, 0, "INT_MIN%-1 rem");
    return 0;
}


// ── DIV/REM: normal cases ───────────────────────────────────

static int test_div_unsigned(void) {
    test_assert_eq(vol(100) / vol(7),  14, "100/7");
    test_assert_eq(vol(100) % vol(7),  2,  "100%7");
    test_assert_eq(vol(0xFFFFFFFF) / vol(2), 0x7FFFFFFF, "UINT_MAX/2");
    test_assert_eq(vol(0xFFFFFFFF) % vol(2), 1,          "UINT_MAX%2");
    test_assert_eq(vol(1) / vol(1), 1, "1/1");
    test_assert_eq(vol(0) / vol(5), 0, "0/5");
    return 0;
}

static int test_div_signed(void) {
    int q, r;
    // Positive / positive
    q = (int)vol(100) / (int)vol(7);
    r = (int)vol(100) % (int)vol(7);
    test_assert_eq((unsigned int)q, 14, "100/7 signed");
    test_assert_eq((unsigned int)r, 2,  "100%7 signed");

    // Negative / positive → truncate toward zero
    q = (int)vol(0xFFFFFF9C) / (int)vol(7);   // -100 / 7
    r = (int)vol(0xFFFFFF9C) % (int)vol(7);   // -100 % 7
    test_assert_eq((unsigned int)q, (unsigned int)-14, "-100/7");
    test_assert_eq((unsigned int)r, (unsigned int)-2,  "-100%7");

    // Positive / negative
    q = (int)vol(100) / (int)vol(0xFFFFFFF9);   // 100 / -7
    r = (int)vol(100) % (int)vol(0xFFFFFFF9);   // 100 % -7
    test_assert_eq((unsigned int)q, (unsigned int)-14, "100/-7");
    test_assert_eq((unsigned int)r, (unsigned int)2,   "100%-7");

    // Negative / negative
    q = (int)vol(0xFFFFFF9C) / (int)vol(0xFFFFFFF9);  // -100 / -7
    r = (int)vol(0xFFFFFF9C) % (int)vol(0xFFFFFFF9);  // -100 % -7
    test_assert_eq((unsigned int)q, 14,               "-100/-7");
    test_assert_eq((unsigned int)r, (unsigned int)-2,  "-100%-7");
    return 0;
}


// ── Combined expression ─────────────────────────────────────

static int test_combined_mul_div(void) {
    // (a * b) / c  and  (a * b) % c
    unsigned int a = vol(123);
    unsigned int b = vol(456);
    unsigned int c = vol(100);
    unsigned int product = a * b;       // 56088
    test_assert_eq(product, 56088, "123*456");
    test_assert_eq(product / c, 560, "56088/100");
    test_assert_eq(product % c, 88,  "56088%100");
    return 0;
}

int main(void) {
    test_begin("PATTERN: ARITHMETIC");
    test_run(test_mul_basics);
    test_run(test_mul_signed);
    test_run(test_div_by_zero);
    test_run(test_rem_by_zero);
    test_run(test_signed_overflow);
    test_run(test_div_unsigned);
    test_run(test_div_signed);
    test_run(test_combined_mul_div);
    return test_end();
}
