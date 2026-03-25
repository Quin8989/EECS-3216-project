#!/bin/bash
# Build an assembly test (.S) into a .x hex file.
# Usage: ./build_asm.sh <source.S> <output.x>
# Example: ./build_asm.sh programs/src/rv32um-p-mul.S programs/isa-tests/rv32um-p-mul.x

set -e

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <source.S> <output.x>" >&2
    exit 1
fi

SRC="$1"
OUT="$2"

if [[ ! -f "$SRC" ]]; then
    echo "ERROR: source file not found: $SRC" >&2
    exit 1
fi

AS=riscv64-unknown-elf-gcc
OBJCOPY=riscv64-unknown-elf-objcopy

# Auto-detect arch: use Zmmul if source contains mul instructions
if grep -qiE '\bmul\b' "$SRC"; then
    ARCH=rv32i_zmmul
else
    ARCH=rv32i
fi

TMPDIR="$(mktemp -d)"
ELF="${TMPDIR}/test.elf"
BIN="${TMPDIR}/test.bin"

echo "=== Building $(basename "$SRC") (${ARCH}) ==="

# Assemble + link at ROM base address
${AS} -march=${ARCH} -mabi=ilp32 -nostdlib -nostartfiles \
    -Wl,-Ttext=0x01000000 \
    "$SRC" -o "$ELF"

# Extract binary
${OBJCOPY} -O binary "$ELF" "$BIN"

# Convert to hex
BIN_PATH="$BIN"
HEX_PATH="$OUT"

if command -v cygpath >/dev/null 2>&1; then
    BIN_PATH="$(cygpath -w "$BIN_PATH")"
    HEX_PATH="$(cygpath -w "$HEX_PATH")"
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

WORDS=$(wc -l < "$OUT")
echo "=== Done: ${OUT} (${WORDS} words) ==="

rm -rf "$TMPDIR"
