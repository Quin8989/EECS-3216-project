# EECS 3216 Project — RISC-V Processor Platform on DE10-Lite

**Team:** Ahmed Abdessamad Tatech (219965904), Quinlan Missikowski (217330119), Carlos Santiago Perez Sabugal (219965888)

## Overview

A single-cycle RV32I processor platform targeting the DE10-Lite FPGA, with VGA output, UART, timer, and keyboard input.

- **Level 1:** Processor + memory map + peripherals, demonstrated with a simple interactive program.
- **Level 2 (stretch):** Run Doomgeneric on the same platform.

## Project Structure

```
rtl/
  cpu/            -- Processor core
    constants.svh     Shared defines (opcodes, ALU selects)
    fetch.sv          PC + instruction ROM
    control.sv        Main decoder
    execute.sv        ALU
    branch_control.sv Branch comparator
    igen.sv           Immediate generator
    register_file.sv  32×32 register file
    cpu.sv            Top CPU module (decode + writeback inlined)
  periph/         -- Peripherals
    ram.sv            Byte-addressable data RAM (64 KB)
    uart.sv           UART (sim stub — $write; FPGA: TX shift register)
    timer.sv          Timer (COUNT / CMP / STATUS)
    vga_timing.sv     VGA 640×480 @ 60 Hz sync generator
    vga_text.sv       80×30 text-mode VGA controller + font ROM
  soc/            -- System integration
    constants.svh     Shared defines
    mem_map.sv        Address decoder (RAM / UART / Timer / VGA)
    top.sv            SoC top-level
tb/               -- Testbenches
  clockgen.sv       Free-running clock
  test_top.sv       Top-level testbench (ECALL detect, PASS/FAIL)
data/             -- ROM / data files
  font8x8.hex       8×8 bitmap font (128 chars)
programs/         -- Test programs (.x hex files)
  isa-tests/        RISC-V ISA compliance tests (rv32ui-p-*.x)
constraints/      -- Quartus pin assignments / SDC
docs/             -- Reports, diagrams, notes
design.f          -- RTL file list
Makefile          -- Build system
```

## Getting Started

### 1. Clone
```
git clone <repo-url>
cd EECS-3216-project
```

### 2. Environment
```
source env.sh
```

### 3. Compile
```
make compile
```

### 4. Run
```
make run
make run TEST=test1
```

### 5. Synthesize (Quartus)
Open the project in Quartus, or use the Quartus CLI flow.

## Module Ownership

| Module | Owner |
|--------|-------|
| CPU core (fetch, decode, execute, memory, writeback) | TBD |
| Memory map / bus | TBD |
| VGA controller | TBD |
| UART | TBD |
| Timer | TBD |
| Keyboard input | TBD |
| Integration & top-level | All |
