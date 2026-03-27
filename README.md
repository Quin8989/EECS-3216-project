
# EECS 3216 Project — RISC-V SoC on DE10-Lite

**Team:** Ahmed Abdessamad Tatech (219965904), Quinlan Missikowski (217330119), Carlos Santiago Perez Sabugal (219965888)

## Overview

A small RISC-V SoC targeting the Intel DE10-Lite (MAX 10, 25 MHz).

| Feature | Detail |
|---|---|
| ISA | RV32I + Zmmul (hardware MUL, no DIV/REM) |
| Instruction ROM | 64 KB on-chip block RAM (4 × byte-wide banks) |
| Data RAM | 8 KB on-chip |
| Display | 320×240 8 bpp (RGB332) on-chip framebuffer, 2× scaled to 640×480 |
| Input | PS/2 keyboard via JTAG injection at `0x4000_0000` |
| UART | TX-only, 115200 8N1 |
| Timer | 32-bit free-running counter with compare + match flag |
| JTAG | Intel JTAG-to-Avalon master for keyboard injection |

## Repository Structure

```
├── rtl/
│   ├── cpu/            Processor core (RV32I+Zmmul, 10 files)
│   ├── periph/         RAM, UART, timer, keyboard, VGA framebuffer
│   └── soc/            Address decoder + SoC integration, FPGA wrapper, constants
│
├── tb/                 Testbench, VGA frame capture
├── programs/
│   ├── *.x             Pre-built boot images (hex, one word per line)
│   ├── isa-tests/      RV32UI + RV32UM ISA test images
│   ├── soc-tests/      SoC peripheral test images
│   └── src/            C/asm sources, linker scripts, shared headers
│
├── tools/              Build scripts, JTAG loader, keyboard server
├── constraints/        Quartus project, pin assignments, timing constraints
├── data/               ROM bank hex files for Quartus synthesis
├── ip/                 Intel JTAG-to-Avalon master IP
│
├── rtl_sources.f       RTL file list for Verilator
└── Makefile            Simulation targets
```

## Setup

### Required Tools

- **Quartus Prime Lite** (tested with 25.1std) with MAX 10 device support
- **MSYS2** providing `bash`, `make`, `python3`, and [Verilator](https://verilator.org/)
- **riscv64-unknown-elf-gcc 14.x+** — required for `-march=rv32i_zmmul`

### Windows PATH

```powershell
. .\tools\setup_windows_env.ps1
```

---

## Simulation

The Verilator binary is compiled **once** and reused for every test. Programs are loaded at runtime via `+MEM_PATH` plusarg — no recompilation needed to switch programs.

```bash
make compile                    # build Verilator binary (once)
make run TEST=rv32ui-p-add      # run one ISA test
make run TEST=test_framebuffer  # run one C test
make run-all                    # run all ISA + SoC tests (sequential)
make run-all -j$(nproc)         # run all tests in parallel (all cores)
make run-ctests                 # build + run all C tests
```

### How It Works

1. `make compile` builds a single Verilator binary at `work/sim/Vtest_top`
2. `make run TEST=X` invokes that binary with `+MEM_PATH=programs/.../X.x`
3. The testbench's `$readmemh` loads the hex file into ROM at runtime
4. The CPU runs until `ecall` — the testbench reads register `x3` and prints `PASS` or `FAIL`

Changing programs is instant — no recompilation. The stamp file `work/sim/.built` tracks source changes so `make compile` is only re-run when RTL changes.

---

## FPGA Pipeline

> **Key constraint:** ROM contents are baked during synthesis (`$readmemh` in `quartus_map`).
> Changing the boot program requires a **full Quartus recompile**. `quartus_cdb --update_mif`
> does NOT re-read `$readmemh` files.

### Build and Program

```powershell
. .\tools\setup_windows_env.ps1

# 1. Compile C → hex image
bash tools/build.sh wolf3d

# 2. Split into ROM banks + update QSF
.\tools\select_boot_program.ps1 wolf3d

# 3. Synthesize (from constraints/ directory)
Push-Location constraints
quartus_sh --flow compile de10_lite
quartus_pgm -m jtag -o "p;de10_lite.sof"
Pop-Location
```

### Swap Programs

```powershell
bash tools/build.sh <program>               # if source changed
.\tools\select_boot_program.ps1 <program>
Push-Location constraints
quartus_sh --flow compile de10_lite          # full recompile required
quartus_pgm -m jtag -o "p;de10_lite.sof"
Pop-Location
```

---

## Wolf3D Raycaster Demo

Fixed-point (Q16.16) raycaster rendering coloured walls onto the VGA framebuffer. Requires **three terminals**.

### Terminal 1 — Build and Program

```powershell
. .\tools\setup_windows_env.ps1
bash tools/build.sh wolf3d
.\tools\select_boot_program.ps1 wolf3d
Push-Location constraints
quartus_sh --flow compile de10_lite
quartus_pgm -m jtag -o "p;de10_lite.sof"
Pop-Location
```

### Terminal 2 — JTAG Keyboard Server

```powershell
. .\tools\setup_windows_env.ps1
system-console --no-gui --script=tools/keyboard_server.tcl
```

### Terminal 3 — Keyboard Injector

```powershell
python tools\keyboard_inject.py
```

**Controls:** `W`/`S` forward/backward, `A`/`D` strafe, `,`/`.` rotate.

### Keyboard Input Path

```
keyboard_inject.py ──TCP:2540──► keyboard_server.tcl (System Console)
    ──JTAG write 0x4FFFFF00──► top_fpga.sv (intercepts)
    ──► keyboard.sv @ 0x40000000 ──► wolf3d.c polls KBD_STATUS/KBD_DATA
```

---

## Memory Map

| Address | Peripheral | Size |
|---|---|---|
| `0x0100_0000` | Instruction ROM | 64 KB |
| `0x0200_0000` | On-chip data RAM | 8 KB |
| `0x1000_0000` | UART TX | 3 registers |
| `0x2000_0000` | Timer | 3 registers |
| `0x3000_0000` | VGA status | 1 register (bit 0 = blanking) |
| `0x4000_0000` | Keyboard | 2 registers |
| `0x8000_0000` | On-chip framebuffer | 75 KB (320×240 RGB332, dual-port) |

---

## Writing a New C Program

### 1. Create Source

Create `programs/src/my_test.c`:

```c
#include "soc.h"

static int test_timer_runs(void) {
    unsigned int t0 = TIMER_COUNT;
    for (volatile int i = 0; i < 1000; i++);
    unsigned int t1 = TIMER_COUNT;
    test_assert(t1 > t0, "timer did not advance");
    return 0;
}

int main(void) {
    test_begin("My Timer Test");
    test_run(test_timer_runs);
    return test_end();   // returns 1=PASS, 0=FAIL → crt0.s → x3 → testbench
}
```

### 2. Build

```bash
bash tools/build.sh my_test    # → programs/my_test.x
```

### 3. Simulate

```bash
make run TEST=my_test
```

### 4. Run on FPGA

```powershell
.\tools\select_boot_program.ps1 my_test
Push-Location constraints
quartus_sh --flow compile de10_lite
quartus_pgm -m jtag -o "p;de10_lite.sof"
Pop-Location
```

---

## Test Suite

| Category | Count | Command |
|---|---|---|
| RV32UI ISA tests | 38 | `make run-all` |
| RV32UM tests (mul/div) | 8 | `make run-all` |
| SoC tests (RAM) | 1 | `make run-all` |
| C peripheral tests | 6 | `make run-ctests` |

---

## Troubleshooting

### FPGA still runs the old program

ROM is baked during `quartus_map`. Always run a **full recompile** after changing the boot image:

```powershell
.\tools\select_boot_program.ps1 <program>
Push-Location constraints; quartus_sh --flow compile de10_lite; Pop-Location
```

### Wolf3D shows only ceiling/floor (no walls)

The ROM wasn't updated. Follow the full recompile steps above.

### keyboard_inject.py connects but keys have no effect

1. Confirm `keyboard_server.tcl` is running and shows "Listening on TCP port 2540"
2. Stop the keyboard server before programming (`Get-Process system-console* | Stop-Process -Force`)
3. Restart the keyboard server after programming — JTAG state resets on FPGA reconfiguration

### JTAG bus contention

Only one process can hold the JTAG cable. Kill `system-console` before running `quartus_pgm`.
