
# EECS 3216 Project — RISC-V SoC on DE10-Lite

**Team:** Ahmed Abdessamad Tatech (219965904), Quinlan Missikowski (217330119), Carlos Santiago Perez Sabugal (219965888)

## Overview

A small RISC-V SoC targeting the Intel DE10-Lite (MAX 10, 25 MHz).

- RV32I CPU with 2-cycle `MUL` (Zmmul — no DIV/REM)
- 4 KB instruction ROM
- 8 KB on-chip RAM
- 64 MB external SDRAM via nullobject controller
- JTAG-to-Avalon master for SDRAM load/read over USB
- 320x240 8bpp (RGB332) VGA framebuffer scaled to 640x480
- UART TX (115200 8N1) for debug output
- 32-bit free-running timer with compare + match flag
- PS/2 keyboard input via JTAG injection at `0x4000_0000`

## Current Status

- 41/41 simulation tests pass (38 `rv32ui-p-*` ISA + 1 `rv32um-p-mul` + 2 SoC tests)
- 3/3 C peripheral tests pass (`test_timer`, `test_uart`, `test_framebuffer`)
- Quartus build closes timing with current constraints
- JTAG SDRAM load path works at ~190 KB/s

## Setup

### Required tools

- Quartus Prime Lite (tested with 20.1 and 25.1std) with MAX 10 device support
- `system-console` from Quartus

> **JTAG IP version note:** The committed `ip/jtag_master/` was generated
> with Quartus 25.1. If you are on an older Quartus (e.g. 20.1 at York),
> regenerate it before synthesis:
>
> ```powershell
> cd ip
> qsys-script --script=create_jtag_master.tcl
> ```
- MSYS2 or another environment providing `bash`, `make`, and `python3`
- `iverilog` for simulation
- `riscv64-unknown-elf-gcc` **14.x or newer** — required for `-march=rv32i_zmmul` support (GCC 13 and earlier will reject this flag; change to `-march=rv32i` in `programs/src/build.sh` as a workaround, losing hardware MUL in C programs)

### Windows PATH

Run the auto-detection script from the repo root:

```powershell
. .\tools\setup_windows_env.ps1
```

MSYS2 tools (`bash`, RISC-V cross tools, `python3`) are expected in:

```text
C:\msys64\usr\bin
C:\msys64\mingw64\bin
C:\msys64\ucrt64\bin
```

### York University lab (Linux)

The lab machines have Quartus, ModelSim, and the RISC-V toolchain pre-installed. Source the environment script:

```bash
source env.sh
```

The Makefile supports ModelSim/Questa via the `SIM` variable:

```bash
make run-all SIM=questa           # run all tests with ModelSim/Questa
make run TEST=rv32ui-p-add SIM=questa
```

## Quick Start

### 1. Run simulation

```bash
make run TEST=rv32ui-p-add   # single ISA test
make run TEST=test_framebuffer  # single C test
make run-all                 # all 41 ISA + SoC tests
make run-ctests              # build + run C peripheral tests
```

### 2. Build a program image

C programs are built from `programs/src/` into `programs/<name>.x`:

```bash
bash programs/src/build.sh test_framebuffer
```

Assembly tests are built into `programs/isa-tests/` or `programs/soc-tests/`:

```bash
bash programs/src/build_asm.sh programs/src/rv32um-p-mul.S programs/isa-tests/rv32um-p-mul.x
```

### 3. Select the boot image for synthesis

```powershell
.\tools\select_boot_program.ps1 test_framebuffer
```

This updates `MEM_PATH` in `constraints/de10_lite.qsf` and regenerates ROM bank hex files.

### 4. Compile and program the FPGA

**Windows** (must run from `constraints/` — see note below):
```powershell
. .\tools\setup_windows_env.ps1
cd constraints
quartus_sh --flow compile de10_lite
quartus_pgm -m jtag -o "p;de10_lite.sof"
```

**York lab (Linux)**:
```bash
cd constraints
quartus_sh --flow compile de10_lite
quartus_pgm -m jtag -o "p;de10_lite.sof"
```

### 5. Load data into SDRAM over JTAG

```powershell
system-console --script=tools/jtag_loader.tcl myfile.bin
```

## Common Workflows

### Smoke test

```powershell
. .\tools\setup_windows_env.ps1
.\tools\smoke_test.ps1                     # full: build + Quartus + JTAG
.\tools\smoke_test.ps1 -SkipQuartus        # skip synthesis
.\tools\smoke_test.ps1 -SkipJtag           # skip JTAG test
```

### Framebuffer test on FPGA

```powershell
bash programs/src/build.sh test_framebuffer
.\tools\select_boot_program.ps1 test_framebuffer
cd constraints
quartus_sh --flow compile de10_lite
quartus_pgm -m jtag -o "p;de10_lite.sof"
```

Expected output: white border, gradient background, centered red rectangle.

### JTAG master smoke/performance test

```powershell
system-console --script=tools/test_intel_master.tcl
```

---

## Demo Programs

### Plasma animation (`demo_uart_timer_vga`)

Renders an animated colour-plasma pattern on the 320×240 VGA framebuffer. Loops forever — no keyboard or serial terminal needed.

**Windows:**
```powershell
. .\tools\setup_windows_env.ps1
.\tools\select_boot_program.ps1 demo_uart_timer_vga
Push-Location .\constraints
quartus_sh --flow compile de10_lite
quartus_pgm -m jtag -o "p;de10_lite.sof"
Pop-Location
```

**York lab (Linux):**
```bash
source env.sh
.\tools\select_boot_program.ps1 demo_uart_timer_vga   # or set MEM_PATH manually in QSF
cd constraints
quartus_sh --flow compile de10_lite
quartus_pgm -m jtag -o "p;de10_lite.sof"
```

Expected output: animated plasma colours fill the screen continuously.

---

### Keyboard VGA terminal (`demo_keyboard_vga`)

Renders a 40×30 text terminal on the VGA framebuffer. Characters are injected from your desktop keyboard over JTAG — no PS/2 hardware needed. Supports printable ASCII, Backspace, and Enter with scroll.

Requires **three terminals** running simultaneously.

#### Step 1 — Build, select, compile, and program the FPGA

**Windows:**
```powershell
. .\tools\setup_windows_env.ps1
bash programs/src/build.sh demo_keyboard_vga       # only needed if you changed the C source
.\tools\select_boot_program.ps1 demo_keyboard_vga
Push-Location .\constraints
quartus_sh --flow compile de10_lite
quartus_pgm -m jtag -o "p;de10_lite.sof"
Pop-Location
```

**York lab (Linux):**
```bash
source env.sh
bash programs/src/build.sh demo_keyboard_vga       # only if source changed
# edit constraints/de10_lite.qsf: set MEM_PATH to "../programs/demo_keyboard_vga.x"
# or use select_boot_program.ps1 under bash/pwsh
cd constraints
quartus_sh --flow compile de10_lite
quartus_pgm -m jtag -o "p;de10_lite.sof"
```

The VGA output will show the title screen once the FPGA is programmed.

#### Step 2 — Start the JTAG keyboard server (System Console)

Open a **new terminal** and run:

**Windows:**
```powershell
. .\tools\setup_windows_env.ps1
system-console --no-gui --script=tools/keyboard_server.tcl
```

**York lab (Linux):**
```bash
source env.sh
system-console --no-gui --script=tools/keyboard_server.tcl
```

Wait until you see:
```
Keyboard server listening on TCP port 2540.
Run  python3 tools/keyboard_inject.py  to connect.
```

#### Step 3 — Connect the keyboard injector

Open another **new terminal** and run:

**Windows:**
```powershell
python tools\keyboard_inject.py
```

**York lab (Linux):**
```bash
python3 tools/keyboard_inject.py
```

You will see:
```
Connected.  Type on your keyboard — chars appear on the FPGA VGA output.
```

Now type — characters appear on the screen in real time. Press **Ctrl+C** in the Python terminal to quit.

#### How it works

```
Your keyboard
    │  (raw keystroke)
    ▼
keyboard_inject.py  ──TCP:2540──►  keyboard_server.tcl (System Console)
                                            │  master_write_32 0x4FFFFF00
                                            ▼
                                    JTAG-to-Avalon master IP
                                            │  Avalon bus write
                                            ▼
                                    top_fpga.sv (intercepts address)
                                            │  jtag_kbd_valid + jtag_kbd_code
                                            ▼
                                    keyboard.sv peripheral @ 0x40000000
                                            │  KBD_DATA / KBD_STATUS
                                            ▼
                                    demo_keyboard_vga.c (polls KBD_STATUS)
                                            │  draws character on framebuffer
                                            ▼
                                    VGA output (320×240)
```

## Memory Map

| Address | Peripheral |
|---|---|
| `0x0100_0000` | Instruction ROM (4 KB) |
| `0x0200_0000` | On-chip data RAM (8 KB) |
| `0x1000_0000` | UART TX |
| `0x2000_0000` | Timer |
| `0x3000_0000` | VGA framebuffer (write-only) |
| `0x4000_0000` | Keyboard |
| `0x8000_0000` | SDRAM (64 MB) |

The same SDRAM is also visible at `0x0400_0000` from JTAG/System Console.

## Important Notes

### Always compile from `constraints/`

```powershell
cd constraints
quartus_sh --flow compile de10_lite
```

Running from the repo root will fail.

### Keyboard input (JTAG injection)

The keyboard peripheral at `0x4000_0000` is driven by JTAG writes to magic address `0x4FFF_FF00`. No PS/2 hardware needed.

### SDRAM write limitation

The CPU-to-SDRAM path only supports aligned 32-bit word stores (no byte-enable).

## Project Layout

```text
rtl/
  cpu/       CPU core and instruction fetch
  periph/    RAM, UART, timer, VGA framebuffer, SDRAM bridge/controller
  soc/       Top-level integration, FPGA wrapper, constants
  vendor/    Third-party SDRAM controller IP (submodule)
tb/          Simulation testbench, SDRAM stub, VGA capture
programs/
  src/       C and assembly source files, build scripts, shared headers
  isa-tests/ Pre-built ISA test hex files (39 tests)
  soc-tests/ Pre-built SoC test hex files (2 tests)
tools/       JTAG loader, boot-image helper, environment setup
constraints/ Quartus project, pin/timing constraints
data/        ROM bank initialization hex files
```

## Test Suite

| Category | Count | Runner |
|---|---|---|
| RV32UI ISA tests | 38 | `make run-all` |
| RV32UM MUL test | 1 | `make run-all` |
| SoC tests (RAM, SDRAM) | 2 | `make run-all` |
| C peripheral tests (timer, UART, framebuffer) | 3 | `make run-ctests` |
