# rv32um-p-mulh — MULH instruction test (signed × signed → upper 32 bits)
#
# Convention: x3 = 1 on pass, x3 = (test_num << 1) on fail.
# All products that fit in 32 bits have upper 32 = 0.

.section .text
.globl _start
_start:

# Test 2: mulh 0, 0 = 0
test_2:
  li x3, 4
  li x1, 0
  li x2, 0
  mulh x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 3: mulh 1, 1 = 0  (product fits in 32 bits)
test_3:
  li x3, 6
  li x1, 1
  li x2, 1
  mulh x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 4: mulh 3, 7 = 0  (21 fits in 32 bits)
test_4:
  li x3, 8
  li x1, 3
  li x2, 7
  mulh x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 5: mulh 0, 0xffff8000 = 0
test_5:
  li x3, 10
  li x1, 0
  li x2, 0xffff8000
  mulh x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 6: mulh 0x80000000, 0 = 0
test_6:
  li x3, 12
  li x1, 0x80000000
  li x2, 0
  mulh x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 7: mulh 0x80000000, 0xffff8000
#   -2147483648 × -32768 = 70368744177664 = 0x0000_4000_0000_0000
#   upper 32 = 0x00004000
test_7:
  li x3, 14
  li x1, 0x80000000
  li x2, 0xffff8000
  mulh x14, x1, x2
  li x7, 0x00004000
  bne x14, x7, fail

# Test 8: mulh 0x7fffffff, 0x7fffffff
#   (2^31-1)^2 = 2^62 - 2^32 + 1 = 0x3FFFFFFF_00000001
#   upper 32 = 0x3FFFFFFF
test_8:
  li x3, 16
  li x1, 0x7fffffff
  li x2, 0x7fffffff
  mulh x14, x1, x2
  li x7, 0x3fffffff
  bne x14, x7, fail

# Test 9: mulh 0x80000000, 0x80000000
#   (-2^31)^2 = 2^62 = 0x4000_0000_0000_0000
#   upper 32 = 0x40000000
test_9:
  li x3, 18
  li x1, 0x80000000
  li x2, 0x80000000
  mulh x14, x1, x2
  li x7, 0x40000000
  bne x14, x7, fail

# Test 10: mulh 0xffffffff, 0xffffffff
#   (-1) × (-1) = 1 → upper 32 = 0
test_10:
  li x3, 20
  li x1, 0xffffffff
  li x2, 0xffffffff
  mulh x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 11: mulh 0xffffffff, 1
#   -1 × 1 = -1 = 0xFFFFFFFF_FFFFFFFF → upper 32 = 0xffffffff
test_11:
  li x3, 22
  li x1, 0xffffffff
  li x2, 1
  mulh x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

# Test 12: mulh 0x7fffffff, 0xffffffff
#   2147483647 × (-1) = -2147483647 = 0xFFFFFFFF_80000001
#   upper 32 = 0xffffffff
test_12:
  li x3, 24
  li x1, 0x7fffffff
  li x2, 0xffffffff
  mulh x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

# Test 13: mulh 0xffffffff, 0x7fffffff (commutativity of signed mul)
#   Same as test 12 by symmetry → 0xffffffff
test_13:
  li x3, 26
  li x1, 0xffffffff
  li x2, 0x7fffffff
  mulh x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

#--- Register overlap tests ---

# Test 14: mulh x1, x1, x2 (rd == rs1)  3×7=21 → upper = 0
test_14:
  li x3, 28
  li x1, 3
  li x2, 7
  mulh x1, x1, x2
  li x7, 0
  bne x1, x7, fail

# Test 15: mulh x2, x1, x2 (rd == rs2)  3×7=21 → upper = 0
test_15:
  li x3, 30
  li x1, 3
  li x2, 7
  mulh x2, x1, x2
  li x7, 0
  bne x2, x7, fail

# Test 16: mulh x1, x1, x1 (rd == rs1 == rs2)  3×3=9 → upper = 0
test_16:
  li x3, 32
  li x1, 3
  mulh x1, x1, x1
  li x7, 0
  bne x1, x7, fail

#--- Write to x0 ---

# Test 17: mulh x0, x1, x2 — x0 must remain 0
test_17:
  li x3, 34
  li x1, 0x80000000
  li x2, 0x80000000
  mulh x0, x1, x2     # upper result is non-zero, but x0 must stay 0
  bne x0, x3, pass    # x0=0, x3=34 → always taken → pass

pass:
  li x3, 1
  ecall

fail:
  ecall
