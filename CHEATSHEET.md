# Project Cheat Sheet

> **Key concept:** There are two separate compile steps:
>
> - `make compile` builds the **hardware simulator** (the RTL/Verilog design) — no program is specified because it's building the simulated chip, not software.
>
> - `bash tools/build.sh <name>` builds a **C program** to run on that chip. The pipeline is:
>   1. `riscv64-unknown-elf-gcc` compiles C source → **ELF binary** (`programs/<name>.elf`)
>   2. `objcopy` converts ELF → **hex text file** (`programs/<name>.x`) — one 32-bit word per line
>   3. `objdump -d` generates a **disassembly** (`programs/<name>.objdmp`) for debugging
>
>   The `.x` file is what the simulator loads into instruction ROM via `$readmemh` at runtime.
>
> Programs are loaded at runtime via `+MEM_PATH`, so you can switch programs without recompiling the simulator.

## Workflow A: Run Tests in Simulation

```bash
# Build the hardware simulator from RTL sources (only once, or after RTL changes)
# This does NOT compile any C program — it builds the simulated chip.
make compile

# Run a single test
make run TEST=rv32ui-p-add

# Run ALL ISA + SoC tests
make run-all
```

---

## Workflow B: Generate VGA Frames

```bash
# 1. Build the program you want to capture
bash tools/build.sh demo

# 2. Build simulator (skip if already done)
make compile

# 3. Generate a frame gallery (HTML)
make vga-gallery GALLERY_TEST=demo GALLERY_FRAMES=5
# Output: work/gallery/vga_gallery.html

# --- OR manually dump PPM frames ---
mkdir -p work/gallery
cd work/gallery
../sim/Vtest_top +MEM_PATH=../../programs/demo.x \
    +CAPTURE_FRAMES=1 +MIN_FRAMES=5 +STOP_AFTER_MIN_FRAMES
# Output: vga_frame0.ppm, vga_frame1.ppm, ...
```

---

## Workflow C: Run demo.c

### In simulation

```bash
bash tools/build.sh demo        # compile C → programs/demo.x
make compile                    # build RTL sim (skip if done)
make run TEST=demo              # run it
```

### On FPGA (hardware)

```bash
# 1. Build the program
bash tools/build.sh demo

# 2. Add Quartus to PATH (one-time setup)
#    Quartus is installed at ~/altera_lite/25.1std/quartus/ but its bin/
#    directory is not on PATH by default, so the shell can't find quartus_sh.
#    Run this once per terminal session:
export PATH="$HOME/altera_lite/25.1std/quartus/bin:$PATH"
#
#    To make it permanent (never type it again), run:
#    echo 'export PATH="$HOME/altera_lite/25.1std/quartus/bin:$PATH"' >> ~/.bashrc
#    Then restart your terminal or run: source ~/.bashrc

# 3. Synthesize from the command line
cd constraints
quartus_sh --flow compile de10_lite
cd ..
# This runs Analysis → Synthesis → Fitter → Assembler → Timing (takes a few minutes)

# 4. Program the FPGA via USB-Blaster
quartus_pgm -m jtag -o "P;constraints/output_files/de10_lite.sof"

# 5. Start keyboard input (two terminals):
wish tools/keyboard_server.tcl          # terminal 1
python3 tools/keyboard_inject.py        # terminal 2

# Controls: W/S to navigate menu, SPACE to select
```

---

## Quick Reference

| What | Command |
|---|---|
| Build any C program | `bash tools/build.sh <name>` |
| Build simulator | `make compile` |
| Run one test | `make run TEST=<name>` |
| Run all tests | `make run-all` |
| Frame gallery | `make vga-gallery GALLERY_TEST=<name> GALLERY_FRAMES=N` |
| Waveform trace | `work/sim/Vtest_top +MEM_PATH=programs/<name>.x +TRACE` |
| FPGA synthesis | `cd constraints && quartus_sh --flow compile de10_lite` |
| Program FPGA | `quartus_pgm -m jtag -o "P;constraints/output_files/de10_lite.sof"` |
| Clean build | `make clean` |
