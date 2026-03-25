# EECS 3216 Project
#
# Usage:
#   make compile              Compile with iverilog (or SIM=questa for Questa)
#   make run                  Compile + simulate
#   make run TEST=test1       Simulate a specific program
#   make run-all              Compile + run every ISA test
#   make clean                Remove build artifacts
#
# Simulator selection:  SIM=iverilog (default)  or  SIM=questa

TEST     ?= test1
SIM      ?= iverilog
TB       ?= test_top

# Convert MSYS /c/… paths to C:/… so Questa/ModelSim can resolve them.
ifeq ($(OS),Windows_NT)
  ROOT := $(shell cygpath -m "$(realpath $(dir $(lastword $(MAKEFILE_LIST))))")
else
  ROOT := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
endif

# Find test hex: check programs/ first, then programs/isa-tests/
ifneq ($(wildcard $(ROOT)/programs/$(TEST).x),)
  MEM_PATH := $(ROOT)/programs/$(TEST).x
else
  MEM_PATH := $(ROOT)/programs/isa-tests/$(TEST).x
endif

SRC := $(addprefix $(ROOT)/rtl/, $(shell cat $(ROOT)/design.f)) \
	$(ROOT)/tb/sdram_ctrl_stub.sv \
	$(ROOT)/tb/$(TB).sv

ISA_TESTS := $(basename $(notdir $(wildcard $(ROOT)/programs/isa-tests/*.x)))

INC_DIRS := $(ROOT)/rtl/soc $(ROOT)/rtl/cpu $(ROOT)/rtl/periph $(ROOT)/tb

# ---------- iverilog / vvp ----------
ifeq ($(SIM),iverilog)

IVFLAGS := -g2012 $(addprefix -I ,$(INC_DIRS)) \
		   -DMEM_PATH=\"$(MEM_PATH)\"
VVP     := $(ROOT)/work/$(TB).vvp

compile:
	@echo "=== Compile (iverilog) ==="
	@mkdir -p $(ROOT)/work
	iverilog $(IVFLAGS) -o $(VVP) $(SRC)

run: compile
	@echo "=== Run (vvp) ==="
	vvp $(VVP)

# ---------- Questa / ModelSim ----------
else ifeq ($(SIM),questa)

compile:
	@echo "=== Compile (Questa) ==="
	vlog -work $(ROOT)/work \
		-suppress 7061 -sv \
		$(addprefix +incdir+,$(INC_DIRS)) \
		"+define+MEM_PATH=\"$(MEM_PATH)\"" \
		$(SRC)

run: compile
	@echo "=== Run (vsim) ==="
	@echo "run -all" > $(ROOT)/run.macro
	vsim -suppress 3839 -c \
		-do $(ROOT)/run.macro \
		$(ROOT)/work.$(TB)

endif

# ---------- Run all ISA tests ----------
run-all:
	@pass=0; fail=0; \
	for t in $(ISA_TESTS); do \
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

.PHONY: compile run run-all clean
