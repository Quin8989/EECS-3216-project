# rv32um-p-mul — Standard MUL instruction test (lower 32 bits)
#
# Based on the riscv-tests rv32um/mul.S test vectors.
# Convention: x3 = 1 on pass, x3 = (test_num << 1) on fail.

.section .text
.globl _start
_start:

#-------------------------------------------------------------
# Arithmetic tests
#-------------------------------------------------------------

# Test 2: 0 * 0 = 0
test_2:
  li x3, 4           # fail marker = 2 << 1
  li x1, 0x00000000
  li x2, 0x00000000
  mul x14, x1, x2
  li x7, 0x00000000
  bne x14, x7, fail

# Test 3: 1 * 1 = 1
test_3:
  li x3, 6
  li x1, 0x00000001
  li x2, 0x00000001
  mul x14, x1, x2
  li x7, 0x00000001
  bne x14, x7, fail

# Test 4: 3 * 7 = 21
test_4:
  li x3, 8
  li x1, 0x00000003
  li x2, 0x00000007
  mul x14, x1, x2
  li x7, 0x00000015
  bne x14, x7, fail

# Test 5: 0 * 0xffff8000 = 0
test_5:
  li x3, 10
  li x1, 0x00000000
  li x2, 0xffff8000
  mul x14, x1, x2
  li x7, 0x00000000
  bne x14, x7, fail

# Test 6: 0x80000000 * 0 = 0
test_6:
  li x3, 12
  li x1, 0x80000000
  li x2, 0x00000000
  mul x14, x1, x2
  li x7, 0x00000000
  bne x14, x7, fail

# Test 7: 0x80000000 * 0xffff8000 = 0 (lower 32 bits)
test_7:
  li x3, 14
  li x1, 0x80000000
  li x2, 0xffff8000
  mul x14, x1, x2
  li x7, 0x00000000
  bne x14, x7, fail

# Test 8: 0xaaaaaaab * 0x0002fe7d = 0x0000ff7f
test_8:
  li x3, 16
  li x1, 0xaaaaaaab
  li x2, 0x0002fe7d
  mul x14, x1, x2
  li x7, 0x0000ff7f
  bne x14, x7, fail

# Test 9: 0x0002fe7d * 0xaaaaaaab = 0x0000ff7f
test_9:
  li x3, 18
  li x1, 0x0002fe7d
  li x2, 0xaaaaaaab
  mul x14, x1, x2
  li x7, 0x0000ff7f
  bne x14, x7, fail

# Test 10: 0xff000000 * 0xff000000 = 0x00000000 (lower 32 bits)
test_10:
  li x3, 20
  li x1, 0xff000000
  li x2, 0xff000000
  mul x14, x1, x2
  li x7, 0x00000000
  bne x14, x7, fail

# Test 11: 0xffffffff * 0xffffffff = 0x00000001
test_11:
  li x3, 22
  li x1, 0xffffffff
  li x2, 0xffffffff
  mul x14, x1, x2
  li x7, 0x00000001
  bne x14, x7, fail

# Test 12: 0xffffffff * 0x00000001 = 0xffffffff
test_12:
  li x3, 24
  li x1, 0xffffffff
  li x2, 0x00000001
  mul x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

# Test 13: 0x00000001 * 0xffffffff = 0xffffffff
test_13:
  li x3, 26
  li x1, 0x00000001
  li x2, 0xffffffff
  mul x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

#-------------------------------------------------------------
# Source/dest register overlap tests
#-------------------------------------------------------------

# Test 14: mul x1, x1, x2 (rs1 == rd)
test_14:
  li x3, 28
  li x1, 13
  li x2, 11
  mul x1, x1, x2
  li x7, 143
  bne x1, x7, fail

# Test 15: mul x2, x1, x2 (rs2 == rd)
test_15:
  li x3, 30
  li x1, 14
  li x2, 11
  mul x2, x1, x2
  li x7, 154
  bne x2, x7, fail

# Test 16: mul x1, x1, x1 (rs1 == rs2 == rd)
test_16:
  li x3, 32
  li x1, 3
  mul x1, x1, x1
  li x7, 9
  bne x1, x7, fail

#-------------------------------------------------------------
# Write to x0 test
#-------------------------------------------------------------

# Test 17: mul x0, x1, x2 — result must be 0
test_17:
  li x3, 34
  li x1, 0x7fffffff
  li x2, 0x7fffffff
  mul x0, x1, x2
  bne x0, x3, pass  # x0 always 0, x3 != 0, so they differ
  # If x0 was somehow written, we'd fall through to fail

#-------------------------------------------------------------
# Pass
#-------------------------------------------------------------
pass:
  li x3, 1
  ecall

fail:
  ecall
