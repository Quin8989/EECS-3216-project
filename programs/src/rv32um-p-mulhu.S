# rv32um-p-mulhu — MULHU instruction test (unsigned × unsigned → upper 32 bits)
#
# Convention: x3 = 1 on pass, x3 = (test_num << 1) on fail.

.section .text
.globl _start
_start:

# Test 2: mulhu 0, 0 = 0
test_2:
  li x3, 4
  li x1, 0
  li x2, 0
  mulhu x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 3: mulhu 1, 1 = 0  (product = 1, fits in 32 bits)
test_3:
  li x3, 6
  li x1, 1
  li x2, 1
  mulhu x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 4: mulhu 3, 7 = 0  (21 fits in 32 bits)
test_4:
  li x3, 8
  li x1, 3
  li x2, 7
  mulhu x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 5: mulhu 0, 0xffff8000 = 0
test_5:
  li x3, 10
  li x1, 0
  li x2, 0xffff8000
  mulhu x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 6: mulhu 0xffffffff, 1 = 0  (product fits in 32 bits)
test_6:
  li x3, 12
  li x1, 0xffffffff
  li x2, 1
  mulhu x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 7: mulhu 0xffffffff, 0
test_7:
  li x3, 14
  li x1, 0xffffffff
  li x2, 0
  mulhu x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 8: mulhu 0xffffffff, 0xffffffff
#   (2^32-1)^2 = 2^64 - 2^33 + 1 → upper 32 = 2^32 - 2 = 0xFFFFFFFE
test_8:
  li x3, 16
  li x1, 0xffffffff
  li x2, 0xffffffff
  mulhu x14, x1, x2
  li x7, 0xfffffffe
  bne x14, x7, fail

# Test 9: mulhu 0x80000000, 0x80000000
#   2^31 × 2^31 = 2^62 = 0x4000_0000_0000_0000 → upper 32 = 0x40000000
test_9:
  li x3, 18
  li x1, 0x80000000
  li x2, 0x80000000
  mulhu x14, x1, x2
  li x7, 0x40000000
  bne x14, x7, fail

# Test 10: mulhu 0xffffffff, 0x80000000
#   (2^32-1) × 2^31 = 2^63 - 2^31 = 0x7FFFFFFF_80000000 → upper 32 = 0x7fffffff
test_10:
  li x3, 20
  li x1, 0xffffffff
  li x2, 0x80000000
  mulhu x14, x1, x2
  li x7, 0x7fffffff
  bne x14, x7, fail

# Test 11: mulhu 0x80000000, 0xffffffff  (same result by commutativity)
test_11:
  li x3, 22
  li x1, 0x80000000
  li x2, 0xffffffff
  mulhu x14, x1, x2
  li x7, 0x7fffffff
  bne x14, x7, fail

#--- Register overlap tests ---

# Test 12: mulhu x1, x1, x2  (rd == rs1)  3 × 7 = 21 → upper = 0
test_12:
  li x3, 24
  li x1, 3
  li x2, 7
  mulhu x1, x1, x2
  li x7, 0
  bne x1, x7, fail

# Test 13: mulhu x2, x1, x2  (rd == rs2)  3 × 7 = 21 → upper = 0
test_13:
  li x3, 26
  li x1, 3
  li x2, 7
  mulhu x2, x1, x2
  li x7, 0
  bne x2, x7, fail

# Test 14: mulhu x1, x1, x1  (rd == rs1 == rs2)  3 × 3 = 9 → upper = 0
test_14:
  li x3, 28
  li x1, 3
  mulhu x1, x1, x1
  li x7, 0
  bne x1, x7, fail

#--- Write to x0 ---

# Test 15: mulhu x0, x1, x2 — x0 must remain 0
test_15:
  li x3, 30
  li x1, 0xffffffff
  li x2, 0xffffffff    # non-zero upper result
  mulhu x0, x1, x2
  bne x0, x3, pass     # x0=0, x3=30 → always taken → pass

pass:
  li x3, 1
  ecall

fail:
  ecall
