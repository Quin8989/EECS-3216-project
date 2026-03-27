# EECS 3216 Project — Simulation
#
# The Verilator binary is compiled ONCE (make compile) and reused for every
# test.  Programs are loaded at runtime via +MEM_PATH=<file> plusarg.
#
# Usage:
#   make compile                 Build the Verilator binary (once)
#   make run TEST=test1          Compile (if needed) + simulate one program
#   make run-all                 Run every ISA + SoC test
#   make run-ctests              Build + simulate all C test programs
#   make build-tests             Build all C test .x images
#   make clean                   Remove build artifacts

TEST         ?= test1
TB           ?= test_top
EXTRA_VFLAGS ?=

# Convert MSYS /c/… paths to C:/… so Verilator can resolve them on Windows.
ifeq ($(OS),Windows_NT)
  ROOT := $(shell cygpath -m "$(realpath $(dir $(lastword $(MAKEFILE_LIST))))")
else
  ROOT := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
endif

# Resolve .x path for the selected TEST
find_hex = $(firstword $(wildcard $(ROOT)/programs/$(1).x) \
                       $(wildcard $(ROOT)/programs/isa-tests/$(1).x) \
                       $(wildcard $(ROOT)/programs/soc-tests/$(1).x))
MEM_PATH := $(call find_hex,$(TEST))

SRC := $(addprefix $(ROOT)/rtl/, $(shell cat $(ROOT)/rtl_sources.f)) \
	$(ROOT)/tb/vga_capture.sv \
	$(ROOT)/tb/$(TB).sv

ISA_TESTS := $(basename $(notdir $(wildcard $(ROOT)/programs/isa-tests/*.x)))
SOC_TESTS := $(basename $(notdir $(wildcard $(ROOT)/programs/soc-tests/*.x)))

INC_DIRS := $(ROOT)/rtl/soc $(ROOT)/rtl/cpu $(ROOT)/rtl/periph $(ROOT)/tb

# Single build directory — program-independent
VDIR   := $(ROOT)/work/sim
SIM    := $(VDIR)/V$(TB)
VFLAGS := --binary --timing --sv \
          --trace \
          $(addprefix +incdir+,$(INC_DIRS)) \
          --top-module $(TB) \
          --public-flat-rw \
          --x-assign 0 --x-initial 0 \
          -Wno-TIMESCALEMOD \
          -Wno-WIDTHEXPAND \
          -Wno-WIDTHTRUNC \
          -Wno-PINMISSING \
          -Mdir $(VDIR) \
          $(EXTRA_VFLAGS) \
          -j 0

# Stamp file: recompile only when sources change
STAMP := $(VDIR)/.built
$(STAMP): $(SRC)
	@echo "=== Compile (Verilator) ==="
	@mkdir -p $(VDIR)
	verilator $(VFLAGS) $(SRC)
	@touch $@

compile: $(STAMP)

run: compile
	@echo "=== Run $(TEST) ==="
	@$(SIM) +MEM_PATH=$(MEM_PATH)

trace: compile
	@echo "=== Trace $(TEST) ==="
	@$(SIM) +MEM_PATH=$(MEM_PATH) +TRACE
	@echo "=== Wrote trace.vcd ==="

# ---------- Run all ISA + SoC tests ----------
# Shell helper: resolve hex path for a test name
define find_hex_sh
  for dir in programs programs/isa-tests programs/soc-tests; do \
    f="$(ROOT)/$$dir/$(1).x"; \
    if [ -f "$$f" ]; then echo "$$f"; break; fi; \
  done
endef

ALL_TESTS := $(ISA_TESTS) $(SOC_TESTS)

run-all: compile
	@pass=0; fail=0; \
	for t in $(ALL_TESTS); do \
		hex=$$($(call find_hex_sh,$$t)); \
		result=$$($(SIM) +MEM_PATH=$$hex 2>&1); \
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
C_TESTS := test_uart test_framebuffer \
           test_pat_arith test_pat_timer test_pat_vga \
           test_integration

build-tests:
	@for t in $(C_TESTS); do \
		echo "=== Build $$t ==="; \
		$(ROOT)/tools/build.sh $$t || exit 1; \
	done

run-ctests: build-tests compile
	@pass=0; fail=0; \
	for t in $(C_TESTS); do \
		hex=$$($(call find_hex_sh,$$t)); \
		result=$$($(SIM) +MEM_PATH=$$hex 2>&1); \
		if echo "$$result" | grep -q "RESULT: PASS"; then \
			echo "PASS  $$t"; pass=$$((pass+1)); \
		else \
			echo "FAIL  $$t"; fail=$$((fail+1)); \
		fi; \
	done; \
	echo ""; echo "=== C tests: $$pass passed, $$fail failed ==="

.PHONY: compile run trace run-all run-ctests build-tests clean
