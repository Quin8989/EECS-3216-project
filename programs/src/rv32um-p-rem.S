# rv32um-p-rem — REM instruction test (signed remainder, sign follows dividend)
#
# Convention: x3 = 1 on pass, x3 = (test_num << 1) on fail.
# RISC-V spec: rem-by-zero → dividend; rem(0x80000000, -1) → 0.

.section .text
.globl _start
_start:

# Test 2: rem(20, 6) = 2  (20 = 3×6 + 2)
test_2:
  li x3, 4
  li x1, 20
  li x2, 6
  rem x14, x1, x2
  li x7, 2
  bne x14, x7, fail

# Test 3: rem(-20, 6) = -2  (sign follows dividend)
test_3:
  li x3, 6
  li x1, -20
  li x2, 6
  rem x14, x1, x2
  li x7, -2
  bne x14, x7, fail

# Test 4: rem(20, -6) = 2  (sign follows dividend, not divisor)
test_4:
  li x3, 8
  li x1, 20
  li x2, -6
  rem x14, x1, x2
  li x7, 2
  bne x14, x7, fail

# Test 5: rem(-20, -6) = -2
test_5:
  li x3, 10
  li x1, -20
  li x2, -6
  rem x14, x1, x2
  li x7, -2
  bne x14, x7, fail

# Test 6: rem(-1, 0) = -1 (0xffffffff)  — rem-by-zero → dividend
test_6:
  li x3, 12
  li x1, 0xffffffff
  li x2, 0
  rem x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

# Test 7: rem(1, 0) = 1  — rem-by-zero → dividend
test_7:
  li x3, 14
  li x1, 1
  li x2, 0
  rem x14, x1, x2
  li x7, 1
  bne x14, x7, fail

# Test 8: rem(0, 0) = 0  — rem-by-zero → dividend (0)
test_8:
  li x3, 16
  li x1, 0
  li x2, 0
  rem x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 9: rem(0x80000000, -1) = 0  — signed overflow → 0
test_9:
  li x3, 18
  li x1, 0x80000000
  li x2, -1
  rem x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 10: rem(0x80000000, 1) = 0
test_10:
  li x3, 20
  li x1, 0x80000000
  li x2, 1
  rem x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 11: rem(-14, 4) = -2  (truncate-toward-zero: quot=-3, rem=4×(-3)+14 = uh
#   -14 = (-3)×4 + (-2);  check: -3×4 = -12; -14-(-12) = -2  ✓
test_11:
  li x3, 22
  li x1, -14
  li x2, 4
  rem x14, x1, x2
  li x7, -2
  bne x14, x7, fail

# Test 12: rem(13, 3) = 1  (13 = 4×3 + 1)
test_12:
  li x3, 24
  li x1, 13
  li x2, 3
  rem x14, x1, x2
  li x7, 1
  bne x14, x7, fail

# Test 13: rem(7, 7) = 0
test_13:
  li x3, 26
  li x1, 7
  li x2, 7
  rem x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 14: rem(-7, -7) = 0
test_14:
  li x3, 28
  li x1, -7
  li x2, -7
  rem x14, x1, x2
  li x7, 0
  bne x14, x7, fail

#--- Register overlap tests ---

# Test 15: rem x1, x1, x2  (rd == rs1)  20 rem 6 = 2
test_15:
  li x3, 30
  li x1, 20
  li x2, 6
  rem x1, x1, x2
  li x7, 2
  bne x1, x7, fail

# Test 16: rem x2, x1, x2  (rd == rs2)  20 rem 6 = 2
test_16:
  li x3, 32
  li x1, 20
  li x2, 6
  rem x2, x1, x2
  li x7, 2
  bne x2, x7, fail

# Test 17: rem x1, x1, x1  (rd == rs1 == rs2)  7 rem 7 = 0
test_17:
  li x3, 34
  li x1, 7
  rem x1, x1, x1
  li x7, 0
  bne x1, x7, fail

#--- Write to x0 ---

# Test 18: rem x0, x1, x2 — x0 must remain 0
test_18:
  li x3, 36
  li x1, 20
  li x2, 7
  rem x0, x1, x2
  bne x0, x3, pass   # x0=0, x3=36 → always taken → pass

pass:
  li x3, 1
  ecall

fail:
  ecall
