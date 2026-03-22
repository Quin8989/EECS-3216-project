# EECS 3216 Project — RISC-V Processor Platform on DE10-Lite

**Team:** Ahmed Abdessamad Tatech (219965904), Quinlan Missikowski (217330119), Carlos Santiago Perez Sabugal (219965888)

---

## 1. Overview

This project implements a single-cycle **RV32I RISC-V** processor with peripherals on the **Intel MAX 10 FPGA** (10M50DAF484C7G) found on the DE10-Lite development board. The design is written in SystemVerilog and includes:

- A full RV32I integer CPU (all 37 base integer instructions)
- 4 KB instruction ROM + 8 KB data RAM (all in on-chip M9K block RAM)
- VGA 640×480 @ 60 Hz text-mode display (80×30 characters)
- UART transmitter/receiver (115 200 baud, 8N1)
- 32-bit hardware timer with compare-match interrupt flag
- PS/2 keyboard receiver with 16-entry FIFO

The system passes all **38 official RISC-V ISA compliance tests** (`rv32ui-p-*.x`) in simulation.

### Resource Utilization (Quartus Prime Lite 25.1std)

| Resource | Used | Available | % |
|---|---|---|---|
| Logic elements | 4,309 | 49,760 | 8.7% |
| Registers | 1,322 | — | — |
| Memory bits (M9K) | 125,824 | 1,677,312 | 7.5% |
| I/O pins | 30 | 360 | 8.3% |

Timing (worst-case slow 1200 mV, 85 °C model):

| Clock | Constraint | Achieved Fmax | Setup Slack |
|---|---|---|---|
| `clk_50m` (system) | 37 MHz (27 ns) | 41.75 MHz | +1.9 ns |
| `clk_pixel` (VGA) | 18.5 MHz (54 ns) | 52.27 MHz | +15.9 ns |

The SDC constrains the system clock to **37 MHz** rather than the board oscillator's native 50 MHz. The single-cycle CPU's critical path (register-file read → barrel-shift ALU → writeback) limits Fmax to ~42 MHz under worst-case conditions. With `derive_clock_uncertainty` adding ~3 ns of jitter/skew pessimism, a 27 ns period is needed to close timing cleanly. The board oscillator still runs at 50 MHz, and the logic is functionally correct at that frequency under typical operating conditions (room temperature, nominal voltage). Closing timing at a true 50 MHz constraint would require pipelining the CPU into at least two stages (IF → EX).

---

## 2. Architecture

### Clock Domains

- **50 MHz** system clock from the on-board oscillator (`MAX10_CLK1_50`)
- **25 MHz** pixel clock derived by a flip-flop toggle divider in `top_fpga.sv`

### Memory Map

| Address | Peripheral | Size |
|---|---|---|
| `0x0100_0000` | Instruction ROM | 4 KB (1024 × 32-bit) |
| `0x0200_0000` | Data RAM | 8 KB (2048 × 32-bit) |
| `0x1000_0000` | UART (TX/RX/Status) | 3 registers |
| `0x2000_0000` | Timer (COUNT/CMP/STATUS) | 3 registers |
| `0x3000_0000` | VGA text buffer | 2400 bytes (80×30) |
| `0x4000_0000` | Keyboard (data/status) | 2 registers |

Address decoding uses bits `[31:24]` of the data memory address to select a peripheral.

### CPU Microarchitecture

The CPU is a **single-cycle** design with one important modification: a **1-cycle load stall**. Because all memories are synchronous (required for M9K block RAM inference), load instructions take two cycles — one to present the address and one to read back the data. During the stall cycle the PC and pipeline registers hold their values, and write-enables to memory are suppressed.

Key submodules (all inlined into `cpu.sv`):
- **Register file** — 32 × 32-bit registers, `x0` hardwired to zero
- **Immediate generator** — Decodes I/S/B/U/J immediate formats
- **ALU** — ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
- **Branch comparator** — BEQ, BNE, BLT, BGE, BLTU, BGEU
- **Control decoder** — Generates ALU select, writeback select, branch, memory, and register-write enables

---

## 3. Project Structure

```
rtl/
  cpu/
    cpu.sv              CPU top-level (register file, ALU, decoder, branch,
                        immediate gen all inlined; load-stall logic)
    fetch.sv            Program counter + instruction ROM (4 byte-banks)
  periph/
    ram.sv              8 KB data RAM (4 byte-banks, synchronous read)
    uart.sv             UART TX + RX shift registers (115200 8N1)
    timer.sv            32-bit timer, compare-match flag
    vga_text.sv         80×30 text-mode VGA + font ROM (altsyncram for synthesis)
    keyboard.sv         PS/2 receiver + 16-entry FIFO
  soc/
    constants.svh       Opcode, funct3, ALU, and writeback defines
    top.sv              SoC interconnect (address decode inlined)
    top_fpga.sv         FPGA wrapper (pin mapping, reset synchronizer, heartbeat LED)

tb/
  test_top.sv           Testbench with clock generator, ECALL PASS/FAIL detection

data/
  font8x8.hex           8×8 bitmap font for simulation ($readmemh)
  font8x8.mif           Same font in Altera MIF format for synthesis (altsyncram)

programs/
  isa-tests/            38 RISC-V rv32ui compliance tests (.x hex files)
  demo.x                Interactive demo program
  test_uart.x           UART loopback test
  test_timer.x          Timer test
  test_vga.x            VGA text buffer test

constraints/
  de10_lite.qpf         Quartus project file
  de10_lite.qsf         Pin assignments, device settings, synthesis macros
  de10_lite.sdc         SDC timing constraints

design.f                RTL file list (10 entries)
Makefile                Build system (iverilog simulation + ISA test runner)
```

---

## 4. Environment Setup

### Required Tools

| Tool | Version | Purpose |
|---|---|---|
| **Quartus Prime Lite** | 25.1std | FPGA synthesis, place & route, programming |
| **Icarus Verilog** | 12.0 | RTL simulation (SystemVerilog subset) |
| **MSYS2** | Latest | Provides `make`, `cygpath`, and a Unix-like shell on Windows |

### Installation (Windows)

#### Quartus Prime Lite

1. Download **Quartus Prime Lite 25.1std** from the Intel FPGA download center. During installation, include the **MAX 10 device support** package.
2. Add the Quartus `bin64` directory to `PATH`:
   ```
   C:\altera_lite\25.1std\quartus\bin64
   ```

#### MSYS2 + Icarus Verilog

1. Install [MSYS2](https://www.msys2.org/) to `C:\msys64`.
2. Open an **MSYS2 MINGW64** shell and run:
   ```bash
   pacman -S mingw-w64-x86_64-iverilog make
   ```
3. Add these to your Windows `PATH`:
   ```
   C:\msys64\mingw64\bin
   C:\msys64\usr\bin
   ```
   The first provides `iverilog` and `vvp`; the second provides `make` and `cygpath`.

#### Why Not Questa/ModelSim?

Quartus Prime Lite ships with a bundled Questa Starter edition, but we found that the license file it generates can contain an `error 300` entry instead of valid FEATURE grants, making it non-functional. Icarus Verilog 12.0 supports enough of the SystemVerilog-2012 subset (including `always_ff`, `always_comb`, `logic`, `typedef enum`, and parameterized modules) to simulate this design without issues.

#### Windows Path Conversion

When running under MSYS2, `make` resolves paths using Unix-style notation (e.g., `/c/VSProjects/...`). Quartus and Icarus both need native Windows paths. The Makefile handles this automatically with:
```make
ROOT := $(shell cygpath -m "$(realpath $(dir $(lastword $(MAKEFILE_LIST))))")
```
This converts paths to the `C:/VSProjects/...` form, which both tools accept.

---

## 5. Simulation

### Running a Single Test

```bash
make run TEST=test1
```

This compiles all RTL from `design.f` plus `tb/test_top.sv`, then runs the simulation. The testbench loads the hex file into instruction ROM via `$readmemh` and monitors register `x3` (gp). A RISC-V ISA test writes **1** to `x3` on pass and a non-1 value on fail, then executes `ECALL`. The testbench detects the `ECALL` and prints `PASS` or `FAIL`.

### Running All 38 ISA Tests

```bash
make run-all
```

This iterates over every `rv32ui-p-*.x` file in `programs/isa-tests/` and reports a pass/fail summary:

```
PASS  rv32ui-p-add
PASS  rv32ui-p-addi
...
PASS  rv32ui-p-xori

=== 38 passed, 0 failed ===
```

### Running Peripheral Tests

```bash
make run TEST=test_uart
make run TEST=test_timer
make run TEST=test_vga
make run TEST=demo
```

---

## 6. FPGA Synthesis

### Running the Quartus Flow

From a terminal with Quartus on `PATH`:

```bash
cd constraints
quartus_sh --flow compile de10_lite
```

This runs the full Analysis & Synthesis → Fitter → Assembler → Timing Analyzer flow. The output `.sof` file is placed at `constraints/output_files/de10_lite.sof`.

Alternatively, open `constraints/de10_lite.qpf` in the Quartus GUI and run **Processing → Start Compilation**.

### Key QSF Settings

The `.qsf` file contains several non-obvious settings that are critical for a successful build:

```tcl
# Device
set_global_assignment -name FAMILY "MAX 10"
set_global_assignment -name DEVICE 10M50DAF484C7G

# Verilog macros passed to RTL
set_global_assignment -name VERILOG_MACRO "SYNTHESIS=1"
set_global_assignment -name VERILOG_MACRO "MEM_PATH=../programs/demo.x"
set_global_assignment -name VERILOG_MACRO "FONT_PATH=../data/font8x8.hex"

# Required for M9K memory initialization from MIF files on MAX 10
set_global_assignment -name INTERNAL_FLASH_UPDATE_MODE "SINGLE COMP IMAGE WITH ERAM"
```

The `SYNTHESIS` macro gates `ifdef` blocks in the RTL that switch between behavioral `$readmemh` (simulation) and `altsyncram` instantiation (synthesis) for the font ROM.

The `INTERNAL_FLASH_UPDATE_MODE` setting is **required** on MAX 10 devices for memories initialized from `.mif` files to retain their contents after programming. Without it, Quartus reports that "the current internal configuration mode does not support memory initialization."

### SDC Timing Constraints

```tcl
create_clock -name clk_50m -period 27.000 [get_ports {MAX10_CLK1_50}]
create_generated_clock -name clk_pixel -source [get_ports {MAX10_CLK1_50}] \
    -divide_by 2 [get_registers {top_fpga:top_inst|clk_pixel}]
derive_clock_uncertainty
```

The system clock is constrained to 37 MHz (27 ns) instead of the board's 50 MHz oscillator frequency. The single-cycle CPU's critical path (register read → ALU barrel shift → writeback) achieves ~42 MHz Fmax under worst-case conditions, and `derive_clock_uncertainty` adds ~3 ns of jitter/skew pessimism on top of that. The 27 ns period closes timing with ~1.9 ns of positive slack.

I/O delays are set to relaxed values because the external interfaces (VGA DAC, buttons, PS/2) are slow relative to the clock.

### Programming the Board

With the DE10-Lite connected via USB-Blaster:

```bash
quartus_pgm -m jtag -o "p;output_files/de10_lite.sof"
```

This loads the bitstream into SRAM (volatile). For non-volatile programming to internal flash, use the Quartus Programmer GUI and select `.pof` generation.

---

## 7. Challenges & Lessons Learned

### 7.1 Block RAM (M9K) Inference

This was the single most time-consuming issue in the project. The MAX 10 FPGA has 182 M9K blocks (1,677,312 memory bits total), and the design has ~126 Kbit of memory. In theory this fits easily. In practice, getting Quartus to actually *use* M9K blocks instead of fabric logic elements required multiple iterations.

**Problem 1 — Asynchronous reads prevent M9K inference.**
The initial RTL used standard combinational read patterns:
```systemverilog
assign rdata = mem[addr];  // combinational / async read
```
Quartus cannot map this to M9K because M9K blocks have **registered output ports only**. With every memory implemented in logic elements, the design needed over 127,000 flip-flops — far more than the 49,760 LEs available. The fitter stalled at ~86% routing utilization and could not complete.

**Solution:** Every memory array in the design (instruction ROM, data RAM, VGA text buffer, font ROM) was rewritten to use synchronous reads:
```systemverilog
always_ff @(posedge clk)
    rdata <= mem[addr];
```
This required adding a **1-cycle load stall** to the CPU, since the read data is now available one cycle after the address is presented. The stall logic holds the PC, suppresses register writes, and gates memory write-enables until the load completes.

**Problem 2 — Byte-lane part-select writes prevent M9K inference.**
The instruction ROM originally used a single 32-bit wide memory with byte-lane writes during initialization:
```systemverilog
mem[addr][7:0]   = data_byte;  // part-select write
```
Quartus does not support part-select writes to inferred M9K. The fix was to split every wide memory into **4 independent byte-bank arrays**, each 8 bits wide with its own write-enable.

**Problem 3 — `initial` blocks prevent M9K inference for synthesis.**
The VGA text buffer had an `initial` block to clear it to spaces. Quartus treated this as a ROM with initial contents and attempted to implement it in logic. Removing the `initial` block (and relying on a runtime clear routine or reset logic) allowed it to infer as a True Dual-Port M9K.

**Problem 4 — Font ROM required explicit `altsyncram` instantiation.**
Even after making the font ROM synchronous and removing `initial` blocks, Quartus still would not infer it as M9K from behavioral code with `$readmemh`. The `(* romstyle = "M9K" *)` synthesis attribute and `(* ram_init_file = "..." *)` were both ignored. The only reliable approach was to instantiate `altsyncram` explicitly under an `` `ifdef SYNTHESIS`` guard:
```systemverilog
`ifdef SYNTHESIS
    altsyncram #(
        .operation_mode("ROM"),
        .width_a(8),
        .widthad_a(10),
        .init_file("../data/font8x8.mif"),
        ...
    ) font_altsyncram ( ... );
`else
    logic [7:0] font_mem [0:1023];
    initial $readmemh(`FONT_PATH, font_mem);
    always_ff @(posedge clk_i) font_data <= font_mem[font_addr];
`endif
```
This also required converting the `.hex` font data to Altera `.mif` format.

**Problem 5 — MAX 10 internal flash configuration mode.**
After all the above, Quartus still reported that M9K memory initialization was unsupported. The fix was a single QSF assignment:
```tcl
set_global_assignment -name INTERNAL_FLASH_UPDATE_MODE "SINGLE COMP IMAGE WITH ERAM"
```
The default dual-image configuration mode on MAX 10 reserves M9K blocks for configuration and does not allow user memory initialization. Switching to single-image mode with ERAM enabled frees the M9K blocks for user logic with `.mif` initialization.

### 7.2 Simulation Environment

**Questa license issues.** The Questa Starter edition bundled with Quartus Prime Lite 25.1std generated a license file containing `error 300` entries instead of valid FEATURE grants. Multiple reinstallation attempts did not resolve it. We switched to Icarus Verilog, which is open-source and requires no license.

**MSYS2 path handling.** On Windows, MSYS2's `make` resolves paths in Unix notation (`/c/Users/...`), but both Quartus and Icarus Verilog require Windows-style paths (`C:/Users/...`). This caused cryptic "file not found" errors during both simulation and synthesis. The fix was adding a `cygpath -m` call in the Makefile to normalize all paths.

**Icarus Verilog SystemVerilog support.** Icarus Verilog 12.0 supports a useful subset of SystemVerilog-2012 when invoked with `-g2012`, including `always_ff`, `always_comb`, `logic`, `typedef enum`, parameterized modules, and `$readmemh`. However, it does **not** support `altsyncram` or other vendor primitives — hence the `` `ifdef SYNTHESIS`` guards around any Altera-specific code.

### 7.3 File Organization

The design was originally split into 21 RTL files (one per small submodule), plus a separate testbench clock generator. This was consolidated to **10 RTL files + 1 testbench** by inlining submodules that were only instantiated once:
- 5 CPU submodules (register_file, execute, branch_control, igen, control) → inlined into `cpu.sv`
- `uart_tx.sv` + `uart_rx.sv` → merged into `uart.sv`
- `ps2_rx.sv` → inlined into `keyboard.sv`
- `vga_timing.sv` → inlined into `vga_text.sv`
- `mem_map.sv` → inlined into `top.sv`
- `clockgen.sv` → inlined into `test_top.sv`

This reduced cross-file dependencies and made synthesis debug easier, since each file is self-contained.

---

## 8. Building Programs

Test programs are provided as pre-built `.x` hex files in `programs/`. The hex format is one 32-bit word per line in hexadecimal (e.g., `00000093`), loaded by `$readmemh` in simulation and by Quartus via the `MEM_PATH` macro.

To change the program loaded during synthesis, edit the `MEM_PATH` macro in `de10_lite.qsf`:
```tcl
set_global_assignment -name VERILOG_MACRO "MEM_PATH=../programs/demo.x"
```

The `programs/src/` directory contains C source and a linker script for writing new programs. Building requires a RISC-V GCC cross-compiler (`riscv32-unknown-elf-gcc`). See `programs/src/build.sh` for the compilation and hex-generation flow.

---

## 9. Pin Assignments

All pin assignments are in `constraints/de10_lite.qsf`. Key mappings:

| Signal | FPGA Pin | Board Connection |
|---|---|---|
| `MAX10_CLK1_50` | PIN_P11 | 50 MHz oscillator |
| `KEY[0]` (active-low reset) | PIN_B8 | Push button |
| `GPIO[0]` (UART TX) | PIN_V10 | GPIO header |
| `GPIO[1]` (UART RX) | PIN_W10 | GPIO header |
| `GPIO[3]` (PS/2 clock) | PIN_W9 | GPIO header |
| `GPIO[5]` (PS/2 data) | PIN_W5 | GPIO header |
| `VGA_R[3:0]` | Various | VGA DAC red channel |
| `VGA_G[3:0]` | Various | VGA DAC green channel |
| `VGA_B[3:0]` | Various | VGA DAC blue channel |
| `VGA_HS`, `VGA_VS` | PIN_N3, PIN_N1 | VGA sync |
| `LEDR[9]` | PIN_B11 | Heartbeat LED (1 Hz blink) |
