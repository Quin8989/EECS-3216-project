# rv32um-p-div — DIV instruction test (signed integer division, truncates toward zero)
#
# Convention: x3 = 1 on pass, x3 = (test_num << 1) on fail.
# RISC-V spec: div-by-zero → -1; signed overflow (0x80000000 / -1) → 0x80000000.

.section .text
.globl _start
_start:

# Test 2: div(20, 6) = 3
test_2:
  li x3, 4
  li x1, 20
  li x2, 6
  div x14, x1, x2
  li x7, 3
  bne x14, x7, fail

# Test 3: div(-20, 6) = -3  (truncate toward zero)
test_3:
  li x3, 6
  li x1, -20
  li x2, 6
  div x14, x1, x2
  li x7, -3
  bne x14, x7, fail

# Test 4: div(20, -6) = -3
test_4:
  li x3, 8
  li x1, 20
  li x2, -6
  div x14, x1, x2
  li x7, -3
  bne x14, x7, fail

# Test 5: div(-20, -6) = 3
test_5:
  li x3, 10
  li x1, -20
  li x2, -6
  div x14, x1, x2
  li x7, 3
  bne x14, x7, fail

# Test 6: div(-1, 0) = -1 (0xffffffff)  — divide by zero → all-ones
test_6:
  li x3, 12
  li x1, 0xffffffff
  li x2, 0
  div x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

# Test 7: div(1, 0) = -1  — divide by zero
test_7:
  li x3, 14
  li x1, 1
  li x2, 0
  div x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

# Test 8: div(0, 0) = -1  — divide by zero
test_8:
  li x3, 16
  li x1, 0
  li x2, 0
  div x14, x1, x2
  li x7, 0xffffffff
  bne x14, x7, fail

# Test 9: div(0x80000000, -1) = 0x80000000  — signed overflow → dividend
test_9:
  li x3, 18
  li x1, 0x80000000
  li x2, -1
  div x14, x1, x2
  li x7, 0x80000000
  bne x14, x7, fail

# Test 10: div(0x80000000, 1) = 0x80000000
test_10:
  li x3, 20
  li x1, 0x80000000
  li x2, 1
  div x14, x1, x2
  li x7, 0x80000000
  bne x14, x7, fail

# Test 11: div(0x7fffffff, 1) = 0x7fffffff
test_11:
  li x3, 22
  li x1, 0x7fffffff
  li x2, 1
  div x14, x1, x2
  li x7, 0x7fffffff
  bne x14, x7, fail

# Test 12: div(-14, 4) = -3  (not -4: truncates toward zero)
test_12:
  li x3, 24
  li x1, -14
  li x2, 4
  div x14, x1, x2
  li x7, -3
  bne x14, x7, fail

# Test 13: div(13, 3) = 4
test_13:
  li x3, 26
  li x1, 13
  li x2, 3
  div x14, x1, x2
  li x7, 4
  bne x14, x7, fail

# Test 14: div(-7, 2) = -3  (truncate: -3.5 → -3)
test_14:
  li x3, 28
  li x1, -7
  li x2, 2
  div x14, x1, x2
  li x7, -3
  bne x14, x7, fail

#--- Register overlap tests ---

# Test 15: div x1, x1, x2  (rd == rs1)  20/6 = 3
test_15:
  li x3, 30
  li x1, 20
  li x2, 6
  div x1, x1, x2
  li x7, 3
  bne x1, x7, fail

# Test 16: div x2, x1, x2  (rd == rs2)  20/6 = 3
test_16:
  li x3, 32
  li x1, 20
  li x2, 6
  div x2, x1, x2
  li x7, 3
  bne x2, x7, fail

# Test 17: div x1, x1, x1  (rd == rs1 == rs2)  7/7 = 1
test_17:
  li x3, 34
  li x1, 7
  div x1, x1, x1
  li x7, 1
  bne x1, x7, fail

#--- Write to x0 ---

# Test 18: div x0, x1, x2 — x0 must remain 0
test_18:
  li x3, 36
  li x1, 20
  li x2, 3
  div x0, x1, x2
  bne x0, x3, pass   # x0=0, x3=36 → always taken → pass

pass:
  li x3, 1
  ecall

fail:
  ecall
