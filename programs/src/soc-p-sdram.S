# soc-p-sdram — SDRAM bridge write/readback test
#
# Writes words through the SDRAM bridge (0x80000000) and reads them back.
# Tests the req/ack/valid handshake, data integrity, and address routing.
# Also writes pixel data that the VGA scanout will display (visual check on FPGA).
# Convention: x3 = 1 on pass, x3 = (test_num << 1) on fail.

.equ SDRAM_BASE, 0x80000000

.section .text
.globl _start
_start:

#-------------------------------------------------------------
# Test 2: Single word write + readback
#-------------------------------------------------------------
test_2:
  li x3, 4
  li x10, SDRAM_BASE
  li x1, 0xDEADBEEF
  sw x1, 0(x10)
  lw x14, 0(x10)
  li x7, 0xDEADBEEF
  bne x14, x7, fail

#-------------------------------------------------------------
# Test 3: Second word at offset +4
#-------------------------------------------------------------
test_3:
  li x3, 6
  li x10, SDRAM_BASE
  li x1, 0xCAFEBABE
  sw x1, 4(x10)
  lw x14, 4(x10)
  li x7, 0xCAFEBABE
  bne x14, x7, fail

#-------------------------------------------------------------
# Test 4: Verify first word wasn't corrupted by second write
#-------------------------------------------------------------
test_4:
  li x3, 8
  li x10, SDRAM_BASE
  lw x14, 0(x10)
  li x7, 0xDEADBEEF
  bne x14, x7, fail

#-------------------------------------------------------------
# Test 5: Write a block of 16 words with known pattern
#         pattern[i] = 0x01010101 * i
#-------------------------------------------------------------
test_5:
  li x3, 10
  li x10, SDRAM_BASE+256    # start at word offset 64
  li x11, 16                # count
  li x1, 0x01010101         # multiplier
  li x12, 0                 # i = 0
  mv x13, x10               # pointer
block_write:
  mul x14, x1, x12          # pattern = 0x01010101 * i
  sw x14, 0(x13)
  addi x13, x13, 4
  addi x12, x12, 1
  bne x12, x11, block_write
  # Verify
  li x12, 0
  mv x13, x10
block_read:
  lw x14, 0(x13)
  mul x7, x1, x12
  bne x14, x7, fail
  addi x13, x13, 4
  addi x12, x12, 1
  bne x12, x11, block_read

#-------------------------------------------------------------
# Test 6: Write a recognisable VGA pattern (first 80 words = row 0)
#         All-white pixels (0xFF = RGB332 white) so row 0 is white on screen.
#-------------------------------------------------------------
test_6:
  li x3, 12
  li x10, SDRAM_BASE        # row 0 starts at word 0
  li x1, 0xFFFFFFFF         # 4 white pixels per word
  li x11, 80                # 320 pixels / 4 = 80 words
  mv x13, x10
vga_write:
  sw x1, 0(x13)
  addi x13, x13, 4
  addi x11, x11, -1
  bnez x11, vga_write
  # Verify a sample word
  lw x14, 0(x10)
  li x7, 0xFFFFFFFF
  bne x14, x7, fail
  lw x14, 76*4(x10)         # last word of row 0
  bne x14, x7, fail

#-------------------------------------------------------------
# Test 7: Address stride — write at large offset, verify
#-------------------------------------------------------------
test_7:
  li x3, 14
  li x10, SDRAM_BASE
  li x11, 4096
  add x10, x10, x11         # x10 = SDRAM_BASE + 4096
  li x1, 0x12345678
  sw x1, 0(x10)
  lw x14, 0(x10)
  li x7, 0x12345678
  bne x14, x7, fail

#-------------------------------------------------------------
# Pass
#-------------------------------------------------------------
pass:
  li x3, 1
  ecall

fail:
  ecall
