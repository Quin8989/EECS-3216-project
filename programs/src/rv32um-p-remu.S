# rv32um-p-remu — REMU instruction test (unsigned remainder)
#
# Convention: x3 = 1 on pass, x3 = (test_num << 1) on fail.
# RISC-V spec: remu-by-zero → dividend.

.section .text
.globl _start
_start:

# Test 2: remu(20, 6) = 2
test_2:
  li x3, 4
  li x1, 20
  li x2, 6
  remu x14, x1, x2
  li x7, 2
  bne x14, x7, fail

# Test 3: remu(7, 2) = 1
test_3:
  li x3, 6
  li x1, 7
  li x2, 2
  remu x14, x1, x2
  li x7, 1
  bne x14, x7, fail

# Test 4: remu(1, 0) = 1  — rem-by-zero → dividend
test_4:
  li x3, 8
  li x1, 1
  li x2, 0
  remu x14, x1, x2
  li x7, 1
  bne x14, x7, fail

# Test 5: remu(0xffffffff, 0) = 0xffffffff  — rem-by-zero → dividend
test_5:
  li x3, 10
  li x1, 0xffffffff
  li x2, 0
  remu x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

# Test 6: remu(0xffffffff, 0xffffffff) = 0
test_6:
  li x3, 12
  li x1, 0xffffffff
  li x2, 0xffffffff
  remu x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 7: remu(0x80000000, 0x40000001) = 0x3fffffff
#   0x80000000 / 0x40000001 = 2147483648 / 1073741825 = 1 (since 1073741825×2 > 2147483648)
#   rem = 2147483648 - 1073741825 = 1073741823 = 0x3fffffff
test_7:
  li x3, 14
  li x1, 0x80000000
  li x2, 0x40000001
  remu x14, x1, x2
  li x7, 0x3fffffff
  bne x14, x7, fail

# Test 8: remu(0xfe, 0x11) = 16
#   254 / 17 = 14 (rem 254 - 14*17 = 254 - 238 = 16)
test_8:
  li x3, 16
  li x1, 0xfe
  li x2, 0x11
  remu x14, x1, x2
  li x7, 16
  bne x14, x7, fail

# Test 9: remu(100, 10) = 0
test_9:
  li x3, 18
  li x1, 100
  li x2, 10
  remu x14, x1, x2
  li x7, 0
  bne x14, x7, fail

# Test 10: remu(101, 10) = 1
test_10:
  li x3, 20
  li x1, 101
  li x2, 10
  remu x14, x1, x2
  li x7, 1
  bne x14, x7, fail

# Test 11: remu(0xffffffff, 0x80000000) = 0x7fffffff
#   0xffffffff / 0x80000000 = 4294967295 / 2147483648 = 1
#   rem = 4294967295 - 2147483648 = 2147483647 = 0x7fffffff
test_11:
  li x3, 22
  li x1, 0xffffffff
  li x2, 0x80000000
  remu x14, x1, x2
  li x7, 0x7fffffff
  bne x14, x7, fail

# Test 12: remu(0x80000000, 0x80000000) = 0
test_12:
  li x3, 24
  li x1, 0x80000000
  li x2, 0x80000000
  remu x14, x1, x2
  li x7, 0
  bne x14, x7, fail

#--- Register overlap tests ---

# Test 13: remu x1, x1, x2  (rd == rs1)  20 remu 6 = 2
test_13:
  li x3, 26
  li x1, 20
  li x2, 6
  remu x1, x1, x2
  li x7, 2
  bne x1, x7, fail

# Test 14: remu x2, x1, x2  (rd == rs2)  20 remu 6 = 2
test_14:
  li x3, 28
  li x1, 20
  li x2, 6
  remu x2, x1, x2
  li x7, 2
  bne x2, x7, fail

# Test 15: remu x1, x1, x1  (rd == rs1 == rs2)  7 remu 7 = 0
test_15:
  li x3, 30
  li x1, 7
  remu x1, x1, x1
  li x7, 0
  bne x1, x7, fail

#--- Write to x0 ---

# Test 16: remu x0, x1, x2 — x0 must remain 0
test_16:
  li x3, 32
  li x1, 20
  li x2, 7
  remu x0, x1, x2
  bne x0, x3, pass   # x0=0, x3=32 → always taken → pass

pass:
  li x3, 1
  ecall

fail:
  ecall
