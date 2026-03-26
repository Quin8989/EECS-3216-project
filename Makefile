# EECS 3216 Project
#
# Usage:
#   make compile              Compile + build Verilator binary
#   make run                  Compile + simulate
#   make run TEST=test1       Simulate a specific program
#   make run-all              Run every ISA + SoC test
#   make run-ctests           Build + simulate all C test programs
#   make build-tests          Build all C test programs to .x hex
#   make clean                Remove build artifacts

TEST     ?= test1
TB       ?= test_top

# Convert MSYS /c/… paths to C:/… so Verilator can resolve them on Windows.
ifeq ($(OS),Windows_NT)
  ROOT := $(shell cygpath -m "$(realpath $(dir $(lastword $(MAKEFILE_LIST))))")
else
  ROOT := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
endif

# Find test hex: check programs/, then isa-tests/, then soc-tests/
ifneq ($(wildcard $(ROOT)/programs/$(TEST).x),)
  MEM_PATH := $(ROOT)/programs/$(TEST).x
else ifneq ($(wildcard $(ROOT)/programs/isa-tests/$(TEST).x),)
  MEM_PATH := $(ROOT)/programs/isa-tests/$(TEST).x
else
  MEM_PATH := $(ROOT)/programs/soc-tests/$(TEST).x
endif

SRC := $(addprefix $(ROOT)/rtl/, $(shell cat $(ROOT)/rtl_sources.f)) \
	$(ROOT)/tb/vga_capture.sv \
	$(ROOT)/tb/sdram_ctrl_stub.sv \
	$(ROOT)/tb/$(TB).sv

ISA_TESTS := $(basename $(notdir $(wildcard $(ROOT)/programs/isa-tests/*.x)))
SOC_TESTS := $(basename $(notdir $(wildcard $(ROOT)/programs/soc-tests/*.x)))

INC_DIRS := $(ROOT)/rtl/soc $(ROOT)/rtl/cpu $(ROOT)/rtl/periph $(ROOT)/tb

VDIR    := $(ROOT)/work/vl_$(TEST)
VFLAGS  := --binary --timing --sv \
           $(addprefix +incdir+,$(INC_DIRS)) \
           -DMEM_PATH=\"$(MEM_PATH)\" \
           --top-module $(TB) \
           --public-flat-rw \
           --x-assign 0 --x-initial 0 \
           -Wno-TIMESCALEMOD \
           -Wno-WIDTHEXPAND \
           -Wno-WIDTHTRUNC \
           -Wno-PINMISSING \
           -Mdir $(VDIR) \
           -j 0

compile:
	@echo "=== Compile (Verilator) ==="
	@mkdir -p $(VDIR)
	verilator $(VFLAGS) $(SRC)

run: compile
	@echo "=== Run (Verilator) ==="
	$(VDIR)/V$(TB)

# ---------- Run all ISA + SoC tests ----------
run-all:
	@pass=0; fail=0; \
	for t in $(ISA_TESTS) $(SOC_TESTS); do \
		result=$$($(MAKE) --no-print-directory run TEST=$$t 2>&1); \
		if echo "$$result" | grep -q "PASS"; then \
			echo "PASS  $$t"; pass=$$((pass+1)); \
		else \
			echo "FAIL  $$t"; fail=$$((fail+1)); \
		fi; \
	done; \
	echo ""; echo "=== $$pass passed, $$fail failed ==="

clean:
	rm -rf $(ROOT)/work $(ROOT)/run.macro

# ---------- C test programs ----------
C_TESTS := test_timer test_uart test_framebuffer

build-tests:
	@for t in $(C_TESTS); do \
		echo "=== Build $$t ==="; \
		$(ROOT)/tools/build.sh $$t || exit 1; \
	done

run-ctests: build-tests
	@pass=0; fail=0; \
	for t in $(C_TESTS); do \
		result=$$($(MAKE) --no-print-directory run TEST=$$t 2>&1); \
		if echo "$$result" | grep -q "RESULT: PASS"; then \
			echo "PASS  $$t"; pass=$$((pass+1)); \
		else \
			echo "FAIL  $$t"; fail=$$((fail+1)); \
		fi; \
	done; \
	echo ""; echo "=== C tests: $$pass passed, $$fail failed ==="

.PHONY: compile run run-all run-ctests build-tests clean
