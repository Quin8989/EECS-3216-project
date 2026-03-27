# rv32um-p-mulhsu — MULHSU instruction test (rs1 signed × rs2 unsigned → upper 32)
#
# Convention: x3 = 1 on pass, x3 = (test_num << 1) on fail.

.section .text
.globl _start
_start:

# Test 2: mulhsu 0, 0 = 0
test_2:
  li x3, 4
  li x1, 0
  li x2, 0
  mulhsu x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 3: mulhsu 1, 1 = 0  (1 × 1 = 1, fits in 32 bits)
test_3:
  li x3, 6
  li x1, 1
  li x2, 1
  mulhsu x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 4: mulhsu 3, 7 = 0  (21 fits in 32 bits)
test_4:
  li x3, 8
  li x1, 3
  li x2, 7
  mulhsu x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 5: mulhsu 0, 0xffff8000 = 0  (0 × anything = 0)
test_5:
  li x3, 10
  li x1, 0
  li x2, 0xffff8000
  mulhsu x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 6: mulhsu 0x80000000, 0 = 0
test_6:
  li x3, 12
  li x1, 0x80000000
  li x2, 0
  mulhsu x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 7: mulhsu 0xffffffff, 1
#   rs1 = -1 (signed), rs2 = 1 (unsigned)
#   -1 × 1 = -1 = 0xFFFFFFFF_FFFFFFFF → upper 32 = 0xffffffff
test_7:
  li x3, 14
  li x1, 0xffffffff
  li x2, 1
  mulhsu x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

# Test 8: mulhsu 0x7fffffff, 0xffffffff
#   (2^31-1) × (2^32-1) = 0x7FFFFFFE_80000001
#   upper 32 = 0x7ffffffe
test_8:
  li x3, 16
  li x1, 0x7fffffff
  li x2, 0xffffffff
  mulhsu x14, x1, x2
  li x7, 0x7ffffffe
  bne x14, x7, fail

# Test 9: mulhsu 0x80000000, 0xffffffff
#   (-2^31) × (2^32-1) = -2^63 + 2^31
#   = 0x8000_0000_0000_0000 + 0x8000_0000 = 0x8000_0000_8000_0000
#   upper 32 = 0x80000000
test_9:
  li x3, 18
  li x1, 0x80000000
  li x2, 0xffffffff
  mulhsu x14, x1, x2
  li x7, 0x80000000
  bne x14, x7, fail

# Test 10: mulhsu 0x80000000, 0x80000000
#   (-2^31) × 2^31 = -2^62 = 0xC000_0000_0000_0000
#   upper 32 = 0xc0000000
test_10:
  li x3, 20
  li x1, 0x80000000
  li x2, 0x80000000
  mulhsu x14, x1, x2
  li x7, 0xc0000000
  bne x14, x7, fail

# Test 11: mulhsu 0xffffffff, 0xffffffff
#   rs1 = -1 (signed), rs2 = 0xffffffff (unsigned)
#   -1 × (2^32-1) = -(2^32-1) = -2^32+1 = 0xFFFFFFFF_00000001
#   upper 32 = 0xffffffff
test_11:
  li x3, 22
  li x1, 0xffffffff
  li x2, 0xffffffff
  mulhsu x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

# Test 12: mulhsu 1, 0xffffffff = 0  (product = 0xffffffff, fits unsigned in 32b but upper=0)
#   1 (signed) × 0xffffffff (unsigned) = 0x00000000_ffffffff → upper = 0
test_12:
  li x3, 24
  li x1, 1
  li x2, 0xffffffff
  mulhsu x14, x1, x2
  li x7, 0
  bne x14, x7, fail

#--- Register overlap tests ---

# Test 13: mulhsu x1, x1, x2 (rd == rs1)
#   x1=1, x2=1 → 0
test_13:
  li x3, 26
  li x1, 1
  li x2, 1
  mulhsu x1, x1, x2
  li x7, 0
  bne x1, x7, fail

# Test 14: mulhsu x2, x1, x2 (rd == rs2)
#   x1=3, x2=7 → upper(21) = 0
test_14:
  li x3, 28
  li x1, 3
  li x2, 7
  mulhsu x2, x1, x2
  li x7, 0
  bne x2, x7, fail

#--- Write to x0 ---

# Test 15: mulhsu x0, x1, x2 — x0 must remain 0
test_15:
  li x3, 30
  li x1, 0x80000000
  li x2, 0xffffffff       # non-zero upper result
  mulhsu x0, x1, x2
  bne x0, x3, pass        # x0=0, x3=30 → always taken → pass

pass:
  li x3, 1
  ecall

fail:
  ecall
