/* isa-link.ld — Minimal linker script for standalone ISA assembly tests.
 *
 * Tests have their own _start and do not use crt0.s or any C runtime.
 * Code is placed at 0x01000000 (the SoC instruction-memory base).
 */

OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS {
    . = 0x01000000;
    .text : {
        *(.text)
        *(.text.*)
    }
}
