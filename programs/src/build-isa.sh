#!/bin/bash
# build-isa.sh — Assemble a standalone ISA test (.S) into an .x hex file.
#
# Usage:
#   ./build-isa.sh rv32um-p-mulh          # build one test
#   ./build-isa.sh                         # build all rv32um-p-* tests
#
# Output goes to programs/isa-tests/<name>.x

set -e

SRCDIR="$(cd "$(dirname "$0")" && pwd)"
ISADIR="${SRCDIR}/../isa-tests"
mkdir -p "${ISADIR}"

CC=riscv64-unknown-elf-gcc
OBJCOPY=riscv64-unknown-elf-objcopy
TMPDIR_BUILD="${SRCDIR}/../../work/isa-build"
mkdir -p "${TMPDIR_BUILD}"

CFLAGS="-march=rv32im -mabi=ilp32 -nostdlib -nostartfiles"
LDFLAGS="-T ${SRCDIR}/isa-link.ld"

build_one() {
    local NAME="$1"
    local SRC="${SRCDIR}/${NAME}.S"
    if [[ ! -f "${SRC}" ]]; then
        echo "ERROR: ${SRC} not found" >&2
        return 1
    fi

    local ELF="${TMPDIR_BUILD}/${NAME}.elf"
    local BIN="${TMPDIR_BUILD}/${NAME}.bin"
    local HEX="${ISADIR}/${NAME}.x"

    echo "=== Building ${NAME} ==="

    ${CC} ${CFLAGS} ${LDFLAGS} "${SRC}" -o "${ELF}"

    ${OBJCOPY} -O binary --only-section=.text "${ELF}" "${BIN}"

    # Convert platform paths for Python on Windows
    local BIN_P="${BIN}"
    local HEX_P="${HEX}"
    if command -v cygpath >/dev/null 2>&1; then
        BIN_P="$(cygpath -w "${BIN}")"
        HEX_P="$(cygpath -w "${HEX}")"
    fi

    python3 - "${BIN_P}" "${HEX_P}" <<'PY'
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

    local WORDS
    WORDS=$(wc -l < "${HEX}")
    echo "=== Done: ${HEX} (${WORDS} words) ==="
}

# If a name is given, build just that one; otherwise build all rv32um-p-* tests
if [[ -n "${1:-}" ]]; then
    build_one "$1"
else
    for src in "${SRCDIR}"/rv32um-p-*.S; do
        name="$(basename "${src}" .S)"
        build_one "${name}"
    done
fi
