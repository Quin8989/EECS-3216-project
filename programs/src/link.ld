/* Linker script for EECS 3216 RISC-V SoC
 *
 * Memory layout:
 *   ROM:  0x0100_0000  (instruction memory — loaded by $readmemh)
 *   RAM:  0x0200_0000  (8 KB data memory)
 */

ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x01000000, LENGTH = 4K
    RAM (rwx) : ORIGIN = 0x02000000, LENGTH = 8K
}

SECTIONS
{
    /* Code in ROM */
    .text : {
        *(.text.init)
        *(.text .text.*)
    } > ROM

    /* Read-only data also in ROM (constants, scancode table) */
    .rodata : {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        *(.sdata2 .sdata2.*)
    } > ROM

    /* Initialised data: loaded into ROM, copied to RAM at startup */
    .data : AT(LOADADDR(.rodata) + SIZEOF(.rodata)) {
        _data_start = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        _data_end = .;
    } > RAM

    _data_load = LOADADDR(.data);

    /* BSS (zero-initialised) in RAM */
    .bss : {
        _bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        _bss_end = .;
    } > RAM

    /* Stack at top of RAM */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
