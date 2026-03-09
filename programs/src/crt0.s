# Minimal startup for EECS 3216 RISC-V SoC
# Sets stack pointer, copies .data, zeroes .bss, calls main, then ecall.

    .section .text.init, "ax"
    .globl _start

_start:
    # Set stack pointer to top of RAM
    la   sp, _stack_top

    # Copy .data from ROM to RAM
    la   a0, _data_load      # source (in ROM)
    la   a1, _data_start     # destination (in RAM)
    la   a2, _data_end
    bgeu a1, a2, .Ldata_done
.Ldata_loop:
    lw   t0, 0(a0)
    sw   t0, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    bltu a1, a2, .Ldata_loop
.Ldata_done:

    # Zero .bss
    la   a0, _bss_start
    la   a1, _bss_end
    bgeu a0, a1, .Lbss_done
.Lbss_loop:
    sw   zero, 0(a0)
    addi a0, a0, 4
    bltu a0, a1, .Lbss_loop
.Lbss_done:

    # Call main
    call main

    # Set x3 = return value of main (1 = PASS for testbench)
    mv   x3, a0

    # ECALL — stops simulation
    ecall
