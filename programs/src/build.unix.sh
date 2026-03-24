#!/bin/bash
# Build a C program from programs/src into programs/<name>.x.
# Usage: ./build.sh test_framebuffer
#        ./build.sh test_framebuffer -S

set -e

SRCDIR="$(cd "$(dirname "$0")" && pwd)"
PROG="${1:-demo}"
KEEP_ASM=0

if [[ "${2:-}" == "-S" ]]; then
    KEEP_ASM=1
fi
CC=riscv64-unknown-elf-gcc
OBJCOPY=riscv64-unknown-elf-objcopy
OBJDUMP=riscv64-unknown-elf-objdump

CFLAGS="-march=rv32i -mabi=ilp32 -Os -Wall -ffreestanding -nostdlib -nostartfiles"
LDFLAGS="-T ${SRCDIR}/link.ld -Wl,--gc-sections"

OUTDIR="${SRCDIR}/.."

echo "=== Building ${PROG} ==="

if [[ ! -f "${SRCDIR}/${PROG}.c" ]]; then
    echo "ERROR: Missing source file ${SRCDIR}/${PROG}.c" >&2
    exit 1
fi

# Compile + link
${CC} ${CFLAGS} ${LDFLAGS} \
    ${SRCDIR}/crt0.s \
    ${SRCDIR}/${PROG}.c \
    -o ${OUTDIR}/${PROG}.elf

if [[ ${KEEP_ASM} -eq 1 ]]; then
    ${CC} ${CFLAGS} -S ${SRCDIR}/${PROG}.c -o ${OUTDIR}/${PROG}.s
fi

# Disassembly (for reference)
${OBJDUMP} -d ${OUTDIR}/${PROG}.elf > ${OUTDIR}/${PROG}.objdmp

# Extract raw binary of .text + .rodata sections
${OBJCOPY} -O binary --only-section=.text --only-section=.rodata \
    ${OUTDIR}/${PROG}.elf ${OUTDIR}/${PROG}.bin

# Convert binary to hex words (one 32-bit word per line, little-endian)
BIN_PATH="${OUTDIR}/${PROG}.bin"
HEX_PATH="${OUTDIR}/${PROG}.x"

if command -v cygpath >/dev/null 2>&1; then
    BIN_PATH="$(cygpath -w "${BIN_PATH}")"
    HEX_PATH="$(cygpath -w "${HEX_PATH}")"
fi

python3 - "${BIN_PATH}" "${HEX_PATH}" <<'PY'
import sys

bin_path = sys.argv[1]
hex_path = sys.argv[2]

with open(bin_path, 'rb') as f:
    data = f.read()

while len(data) % 4:
    data += b'\x00'

with open(hex_path, 'w') as f:
    for i in range(0, len(data), 4):
        word = int.from_bytes(data[i:i+4], 'little')
        f.write(f'{word:08x}\n')
PY

WORDS=$(wc -l < ${OUTDIR}/${PROG}.x)
echo "=== Done: ${OUTDIR}/${PROG}.x (${WORDS} words) ==="
