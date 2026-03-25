# soc-p-ram — On-chip RAM peripheral test
#
# Tests byte/half/word store+load through the memory-mapped RAM at 0x02000000.
# Verifies bus routing, byte-lane enables, endianness, and cross-width access.
# Convention: x3 = 1 on pass, x3 = (test_num << 1) on fail.

.equ RAM_BASE, 0x02000100   # offset 0x100 to avoid clobbering stack/BSS

.section .text
.globl _start
_start:

#-------------------------------------------------------------
# Test 2: Store byte, load byte (SB/LB)
#-------------------------------------------------------------
test_2:
  li x3, 4
  li x10, RAM_BASE
  li x1, 0xDE
  sb x1, 0(x10)
  li x1, 0xAD
  sb x1, 1(x10)
  li x1, 0xBE
  sb x1, 2(x10)
  li x1, 0xEF
  sb x1, 3(x10)
  lbu x14, 0(x10)
  li x7, 0xDE
  bne x14, x7, fail
  lbu x14, 1(x10)
  li x7, 0xAD
  bne x14, x7, fail
  lbu x14, 2(x10)
  li x7, 0xBE
  bne x14, x7, fail
  lbu x14, 3(x10)
  li x7, 0xEF
  bne x14, x7, fail

#-------------------------------------------------------------
# Test 3: Store half, load half (SH/LH)
#-------------------------------------------------------------
test_3:
  li x3, 6
  li x10, RAM_BASE+16
  li x1, 0x1234
  sh x1, 0(x10)
  li x1, 0x5678
  sh x1, 2(x10)
  lhu x14, 0(x10)
  li x7, 0x1234
  bne x14, x7, fail
  lhu x14, 2(x10)
  li x7, 0x5678
  bne x14, x7, fail

#-------------------------------------------------------------
# Test 4: Store word, load word (SW/LW)
#-------------------------------------------------------------
test_4:
  li x3, 8
  li x10, RAM_BASE+32
  li x1, 0xCAFEBABE
  sw x1, 0(x10)
  lw x14, 0(x10)
  li x7, 0xCAFEBABE
  bne x14, x7, fail

#-------------------------------------------------------------
# Test 5: Store word, load individual bytes (endianness check)
#-------------------------------------------------------------
test_5:
  li x3, 10
  li x10, RAM_BASE+48
  li x1, 0x44332211
  sw x1, 0(x10)
  lbu x14, 0(x10)
  li x7, 0x11
  bne x14, x7, fail
  lbu x14, 1(x10)
  li x7, 0x22
  bne x14, x7, fail
  lbu x14, 2(x10)
  li x7, 0x33
  bne x14, x7, fail
  lbu x14, 3(x10)
  li x7, 0x44
  bne x14, x7, fail

#-------------------------------------------------------------
# Test 6: Store individual bytes, load as word
#-------------------------------------------------------------
test_6:
  li x3, 12
  li x10, RAM_BASE+64
  li x1, 0xAA
  sb x1, 0(x10)
  li x1, 0xBB
  sb x1, 1(x10)
  li x1, 0xCC
  sb x1, 2(x10)
  li x1, 0xDD
  sb x1, 3(x10)
  lw x14, 0(x10)
  li x7, 0xDDCCBBAA
  bne x14, x7, fail

#-------------------------------------------------------------
# Test 7: Store halves, load as word
#-------------------------------------------------------------
test_7:
  li x3, 14
  li x10, RAM_BASE+80
  li x1, 0xBEEF
  sh x1, 0(x10)
  li x1, 0xDEAD
  sh x1, 2(x10)
  lw x14, 0(x10)
  li x7, 0xDEADBEEF
  bne x14, x7, fail

#-------------------------------------------------------------
# Test 8: Signed byte load (LB sign-extends)
#-------------------------------------------------------------
test_8:
  li x3, 16
  li x10, RAM_BASE+96
  li x1, 0x80
  sb x1, 0(x10)
  lb x14, 0(x10)
  li x7, 0xFFFFFF80
  bne x14, x7, fail

#-------------------------------------------------------------
# Test 9: Signed half load (LH sign-extends)
#-------------------------------------------------------------
test_9:
  li x3, 18
  li x10, RAM_BASE+112
  li x1, 0x8000
  sh x1, 0(x10)
  lh x14, 0(x10)
  li x7, 0xFFFF8000
  bne x14, x7, fail

#-------------------------------------------------------------
# Test 10: Walking-ones word pattern
#-------------------------------------------------------------
test_10:
  li x3, 20
  li x10, RAM_BASE+128
  li x1, 1            # walking bit
  li x11, 32          # 32 iterations
  mv x12, x10         # write pointer
walk_write:
  sw x1, 0(x12)
  addi x12, x12, 4
  slli x1, x1, 1
  addi x11, x11, -1
  bnez x11, walk_write
  # Verify
  li x1, 1
  li x11, 32
  mv x12, x10
walk_read:
  lw x14, 0(x12)
  bne x14, x1, fail
  addi x12, x12, 4
  slli x1, x1, 1
  addi x11, x11, -1
  bnez x11, walk_read

#-------------------------------------------------------------
# Pass
#-------------------------------------------------------------
pass:
  li x3, 1
  ecall

fail:
  ecall
