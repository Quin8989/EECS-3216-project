# EECS 3216 Project — RISC-V Processor Platform on DE10-Lite

**Team:** Ahmed Abdessamad Tatech (219965904), Quinlan Missikowski (217330119), Carlos Santiago Perez Sabugal (219965888)

## Overview

A single-cycle RV32I processor platform targeting the DE10-Lite FPGA, with VGA output, UART, timer, and keyboard input.

- **Level 1:** Processor + memory map + peripherals, demonstrated with a simple interactive program.
- **Level 2 (stretch):** Run Doomgeneric on the same platform.

## Project Structure

```
design/
  code/           -- RTL source files
  constraints/    -- Quartus pin assignments / SDC
verif/
  scripts/        -- Makefiles, design file list
  tests/          -- Testbenches
docs/             -- Reports, diagrams, notes
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

### 3. Compile (ModelSim)
```
make compile -C verif/scripts VSIM=1
```

### 4. Run
```
make run -C verif/scripts VSIM=1 TEST=test1
```

### 5. Synthesize (Quartus)
Open `design/constraints/de10lite.qsf` in Quartus, or use the Quartus CLI flow.

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
