# rv32um-p-divu — DIVU instruction test (unsigned integer division)
#
# Convention: x3 = 1 on pass, x3 = (test_num << 1) on fail.
# RISC-V spec: divu-by-zero → 0xffffffff (all-ones).

.section .text
.globl _start
_start:

# Test 2: divu(20, 6) = 3
test_2:
  li x3, 4
  li x1, 20
  li x2, 6
  divu x14, x1, x2
  li x7, 3
  bne x14, x7, fail

# Test 3: divu(1, 0) = 0xffffffff  — divide by zero
test_3:
  li x3, 6
  li x1, 1
  li x2, 0
  divu x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

# Test 4: divu(0, 0) = 0xffffffff  — divide by zero
test_4:
  li x3, 8
  li x1, 0
  li x2, 0
  divu x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

# Test 5: divu(0xffffffff, 1) = 0xffffffff
test_5:
  li x3, 10
  li x1, 0xffffffff
  li x2, 1
  divu x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

# Test 6: divu(0x80000000, 0x80000000) = 1
test_6:
  li x3, 12
  li x1, 0x80000000
  li x2, 0x80000000
  divu x14, x1, x2
  li x7, 1
  bne x14, x7, fail

# Test 7: divu(7, 2) = 3
test_7:
  li x3, 14
  li x1, 7
  li x2, 2
  divu x14, x1, x2
  li x7, 3
  bne x14, x7, fail

# Test 8: divu(0x80000000, 1) = 0x80000000  (NOT -2147483648 as in signed)
test_8:
  li x3, 16
  li x1, 0x80000000
  li x2, 1
  divu x14, x1, x2
  li x7, 0x80000000
  bne x14, x7, fail

# Test 9: divu(0xffffffff, 0xffffffff) = 1
test_9:
  li x3, 18
  li x1, 0xffffffff
  li x2, 0xffffffff
  divu x14, x1, x2
  li x7, 1
  bne x14, x7, fail

# Test 10: divu(0xffffffff, 0) = 0xffffffff  — divide by zero
test_10:
  li x3, 20
  li x1, 0xffffffff
  li x2, 0
  divu x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

# Test 11: divu(100, 10) = 10
test_11:
  li x3, 22
  li x1, 100
  li x2, 10
  divu x14, x1, x2
  li x7, 10
  bne x14, x7, fail

# Test 12: divu(0xffffffff, 0x80000000) = 1
#   0xffffffff / 0x80000000 = 4294967295 / 2147483648 = 1 (remainder 2147483647)
test_12:
  li x3, 24
  li x1, 0xffffffff
  li x2, 0x80000000
  divu x14, x1, x2
  li x7, 1
  bne x14, x7, fail

#--- Register overlap tests ---

# Test 13: divu x1, x1, x2  (rd == rs1)  20/6 = 3
test_13:
  li x3, 26
  li x1, 20
  li x2, 6
  divu x1, x1, x2
  li x7, 3
  bne x1, x7, fail

# Test 14: divu x2, x1, x2  (rd == rs2)  20/6 = 3
test_14:
  li x3, 28
  li x1, 20
  li x2, 6
  divu x2, x1, x2
  li x7, 3
  bne x2, x7, fail

# Test 15: divu x1, x1, x1  (rd == rs1 == rs2)  7/7 = 1
test_15:
  li x3, 30
  li x1, 7
  divu x1, x1, x1
  li x7, 1
  bne x1, x7, fail

#--- Write to x0 ---

# Test 16: divu x0, x1, x2 — x0 must remain 0
test_16:
  li x3, 32
  li x1, 20
  li x2, 3
  divu x0, x1, x2
  bne x0, x3, pass   # x0=0, x3=32 → always taken → pass

pass:
  li x3, 1
  ecall

fail:
  ecall
