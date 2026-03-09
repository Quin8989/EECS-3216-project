#!/bin/bash
# Build script for EECS 3216 demo program
# Usage: ./build.sh demo    → produces ../demo.x
#        ./build.sh demo -S → also keep .s (assembly listing)

set -e

SRCDIR="$(cd "$(dirname "$0")" && pwd)"
PROG="${1:-demo}"
CC=riscv64-unknown-elf-gcc
OBJCOPY=riscv64-unknown-elf-objcopy
OBJDUMP=riscv64-unknown-elf-objdump

CFLAGS="-march=rv32i -mabi=ilp32 -Os -Wall -ffreestanding -nostdlib -nostartfiles"
LDFLAGS="-T ${SRCDIR}/link.ld -Wl,--gc-sections"

OUTDIR="${SRCDIR}/.."

echo "=== Building ${PROG} ==="

# Compile + link
${CC} ${CFLAGS} ${LDFLAGS} \
    ${SRCDIR}/crt0.s \
    ${SRCDIR}/${PROG}.c \
    -o ${OUTDIR}/${PROG}.elf

# Disassembly (for reference)
${OBJDUMP} -d ${OUTDIR}/${PROG}.elf > ${OUTDIR}/${PROG}.objdmp

# Extract raw binary of .text + .rodata sections
${OBJCOPY} -O binary --only-section=.text --only-section=.rodata \
    ${OUTDIR}/${PROG}.elf ${OUTDIR}/${PROG}.bin

# Convert binary to hex words (one 32-bit word per line, little-endian)
python3 -c "
import sys
with open('${OUTDIR}/${PROG}.bin', 'rb') as f:
    data = f.read()
# Pad to word boundary
while len(data) % 4:
    data += b'\x00'
with open('${OUTDIR}/${PROG}.x', 'w') as f:
    for i in range(0, len(data), 4):
        word = int.from_bytes(data[i:i+4], 'little')
        f.write(f'{word:08x}\n')
"

WORDS=$(wc -l < ${OUTDIR}/${PROG}.x)
echo "=== Done: ${OUTDIR}/${PROG}.x (${WORDS} words) ==="
