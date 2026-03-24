# EECS 3216 Project — RISC-V SoC on DE10-Lite

**Team:** Ahmed Abdessamad Tatech (219965904), Quinlan Missikowski (217330119), Carlos Santiago Perez Sabugal (219965888)

## Overview

This project is a small RISC-V SoC for the Intel DE10-Lite board.

Current supported hardware path:

- RV32I CPU with 2-cycle `MUL`
- 4 KB instruction ROM
- 8 KB on-chip RAM
- 64 MB external SDRAM
- JTAG-to-Avalon master for SDRAM load/read over USB
- VGA output driven by a 320x240 8bpp framebuffer scaled to 640x480
- UART TX for debug output
- Timer peripheral
- PS/2 keyboard input at `0x4000_0000`

The current documented display path is the SDRAM framebuffer in `rtl/periph/vga_fb.sv`.

## Current Status

- ISA simulation passes all 38 `rv32ui-p-*` tests
- Quartus build is closing timing with the current constraints
- JTAG SDRAM load path is working at about 190 KB/s
- The framebuffer test is expected to show:
  - white border
  - smooth gradient background
  - centered orange/red rectangle

## Setup

### Required tools

- Quartus Prime Lite 25.1std with MAX 10 device support
- `system-console` from Quartus
- MSYS2 or another environment providing `bash`, `make`, and `python3`
- `iverilog` for simulation
- `riscv64-unknown-elf-gcc`, `riscv64-unknown-elf-objcopy`, and `riscv64-unknown-elf-objdump`

### Windows PATH

At minimum, these tools need to be on `PATH`:

```text
C:\altera_lite\25.1std\quartus\bin64
C:\altera_lite\25.1std\quartus\sopc_builder\bin
C:\msys64\usr\bin
C:\msys64\mingw64\bin
C:\msys64\ucrt64\bin
```

On this repo's current Windows flow, `bash` comes from `C:\msys64\usr\bin`, the RISC-V cross tools come from `C:\msys64\mingw64\bin`, and `python3` may come from `C:\msys64\ucrt64\bin`.

If `./programs/src/build.sh <program>` fails on Windows with `riscv64-unknown-elf-gcc: command not found` or a Python `FileNotFoundError` during `.bin` to `.x` conversion, check those three MSYS2 paths first.

For a prepared PowerShell session in this repo, dot-source:

```powershell
. .\tools\setup_windows_env.ps1
```

## Quick Start

### 1. Run simulation

From the repo root:

```bash
make run TEST=test1
make run-all
```

Useful simulation targets:

```bash
make run TEST=test_uart
make run TEST=test_timer
make run TEST=keyboard_paint TB=test_keyboard_demo
make run TB=test_keyboard_unit
```

### 2. Build a program image

Programs are built from `programs/src` into `programs/<name>.elf`, `.bin`, `.objdmp`, and `.x`.

Example:

```bash
bash programs/src/build.sh test_framebuffer
```

On Windows after dot-sourcing the setup script, you can also run the same command through MSYS2 `bash` automatically via the smoke-test helper described below.

### 3. Select the boot image used by synthesis

Building a `.x` file is not enough. The FPGA boots whatever image is referenced by `MEM_PATH` in `constraints/de10_lite.qsf` and compiled into the ROM banks.

Use the helper from the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\select_boot_program.ps1 test_framebuffer
```

That script:

- updates `MEM_PATH` in `constraints/de10_lite.qsf`
- regenerates `data/rom_bank0.hex` through `data/rom_bank3.hex`

### 4. Compile and program the FPGA

From the repo root:

```powershell
$env:PATH = 'C:\altera_lite\25.1std\quartus\bin64;' + $env:PATH
cd constraints
quartus_sh --flow compile de10_lite
quartus_pgm -m jtag -o "p;de10_lite.sof"
```

### 5. Load extra data into SDRAM over JTAG

The JTAG master accesses SDRAM without rebuilding the FPGA image.

```powershell
& "C:\altera_lite\25.1std\quartus\sopc_builder\bin\system-console.exe" --script=tools/jtag_loader.tcl myfile.bin
```

Default JTAG SDRAM base address is `0x04000000`.

## Common Workflows

### Smoke test

From the repo root in PowerShell:

```powershell
. .\tools\setup_windows_env.ps1
.\tools\smoke_test.ps1
```

That helper runs:

- a software image build
- a Quartus compile
- the JTAG master smoke test

Optional flags:

```powershell
.\tools\smoke_test.ps1 -Program test_mul
.\tools\smoke_test.ps1 -SkipQuartus
.\tools\smoke_test.ps1 -SkipJtag
```

### Framebuffer test

This is the main video bring-up test.

```powershell
bash programs/src/build.sh test_framebuffer
powershell -ExecutionPolicy Bypass -File .\tools\select_boot_program.ps1 test_framebuffer
cd constraints
quartus_sh --flow compile de10_lite
quartus_pgm -m jtag -o "p;de10_lite.sof"
```

Expected monitor output:

- white border
- full-screen gradient
- centered orange/red rectangle

If the display looks wrong, sample framebuffer contents over JTAG:

```powershell
& "C:\altera_lite\25.1std\quartus\sopc_builder\bin\system-console.exe" --script=tools/dump_framebuffer_samples.tcl
```

### Keyboard validation without hardware

You can validate most of the keyboard path in simulation before plugging in a PS/2 keyboard:

```bash
make run TB=test_keyboard_unit
make run TEST=keyboard_paint TB=test_keyboard_demo
```

What these cover:

- `test_keyboard_unit` sends real PS/2 frames into `keyboard.sv` and checks receive and read-to-clear behavior.
- `test_keyboard_demo` boots `keyboard_paint.x`, injects keyboard frames through the SoC, captures UART output, and checks framebuffer words that should change after movement and burst commands.

### Keyboard level 1 demo

The main keyboard-driven demo program is `keyboard_paint`.

To build, select, compile, and program it onto the FPGA from the repo root:

```powershell
. .\tools\setup_windows_env.ps1
bash programs/src/build.sh keyboard_paint
powershell -ExecutionPolicy Bypass -File .\tools\select_boot_program.ps1 keyboard_paint
cd constraints
quartus_sh --flow compile de10_lite
quartus_pgm -m jtag -o "p;de10_lite.sof"
```

What the demo should do when it boots:

- clear the framebuffer to black
- draw a highlighted cursor tile near the center of the screen
- print `Keyboard!` and `WASD QE XC` on the UART debug output

Controls:

- `W`, `A`, `S`, `D`: move the cursor one tile and paint that tile with the active brush color
- `Q`, `E`: cycle backward or forward through the brush palette
- `C`: clear the full screen and keep the cursor at its current position
- `X`: paint a burst pattern on the neighboring tiles around the cursor

Visual behavior:

- the screen is a 40x30 grid of 8x8 tiles backed by the SDRAM framebuffer
- the current cursor tile is outlined brightly so it remains visible
- moving leaves a painted trail behind the cursor
- burst mode colors several neighboring tiles using the current brush and timer-derived variation

If you only want to validate the full demo without hardware, run:

```bash
make run TEST=keyboard_paint TB=test_keyboard_demo
```

That bench verifies UART banner output, injected keyboard movement, and framebuffer updates.

### MUL self-test

```powershell
bash programs/src/build.sh test_mul
powershell -ExecutionPolicy Bypass -File .\tools\select_boot_program.ps1 test_mul
cd constraints
quartus_sh --flow compile de10_lite
quartus_pgm -m jtag -o "p;de10_lite.sof"
```

### JTAG master smoke/performance test

```powershell
& "C:\altera_lite\25.1std\quartus\sopc_builder\bin\system-console.exe" --script=tools/test_intel_master.tcl
```

## Memory Map

### CPU-visible address map

| Address | Peripheral |
|---|---|
| `0x0100_0000` | Instruction ROM |
| `0x0200_0000` | On-chip data RAM |
| `0x1000_0000` | UART |
| `0x2000_0000` | Timer |
| `0x8000_0000` | SDRAM |

### SDRAM address windows

The same SDRAM is exposed through two address views:

- CPU software uses `0x8000_0000`
- JTAG/System Console scripts use `0x0400_0000`

## Important Notes

### Boot image selection

If the board still runs an old program after you built a new `.x`, one of these steps was missed:

- `select_boot_program.ps1` was not run
- Quartus was not recompiled
- the newly built `.sof` was not programmed

### SDRAM write limitation

The current CPU-to-SDRAM path does not yet implement byte-enable writes.
Software should use aligned 32-bit word stores for SDRAM writes.

### Legacy modules

Older text-VGA code still exists in the repository, but the active display path is the SDRAM framebuffer in `rtl/periph/vga_fb.sv`.

## Project Layout

```text
rtl/
  cpu/       CPU and instruction fetch
  periph/    RAM, UART, timer, framebuffer VGA, SDRAM bridge
  soc/       Top-level integration and FPGA wrapper
tb/          Simulation testbench
programs/    Boot images, ISA tests, and source files
tools/       JTAG loader, boot-image helper, SDRAM/framebuffer debug scripts
constraints/ Quartus project and timing constraints
data/        ROM initialization files
```

## Key Files

- `programs/src/build.sh` builds C programs into `.x` boot images
- `tools/select_boot_program.ps1` updates `MEM_PATH` and ROM bank hex files
- `tools/jtag_loader.tcl` loads binary data into SDRAM over JTAG
- `tools/test_intel_master.tcl` validates JTAG master access and speed
- `tools/dump_framebuffer_samples.tcl` samples live framebuffer words from SDRAM
- `rtl/periph/vga_fb.sv` implements the current VGA output path
- `programs/src/keyboard_paint.c` is the framebuffer-based keyboard demo program

## Notes for Further Work

The current platform is in a reasonable state for continued Doom-related bring-up, but the main missing pieces are still outside this README:

- stronger software/runtime support
- input path integration
- SDRAM layout for framebuffer plus asset/data loading
- any further CPU feature work beyond current RV32I + `MUL`
