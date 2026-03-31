# Project Cheat Sheet

## Workflow A: Run Tests in Simulation

```bash
# Build the simulator (only needed once, or after RTL changes)
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

# 2. Synthesize in Quartus (Windows — from constraints/ folder)
#    Open constraints/de10_lite.qpf in Quartus, compile

# 3. Program the FPGA via USB-Blaster

# 4. Start keyboard input (two terminals):
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
| Clean build | `make clean` |
