# EECS 3216 Project
#
# Usage:
#   make compile          Compile with ModelSim
#   make run              Compile + simulate
#   make run TEST=test1   Simulate a specific program
#   make clean            Remove build artifacts

TEST     ?= test1
ROOT     := $(realpath $(dir $(lastword $(MAKEFILE_LIST))))
FONT_PATH := $(ROOT)/data/font8x8.hex

# Find test hex: check programs/ first, then programs/isa-tests/
ifneq ($(wildcard $(ROOT)/programs/$(TEST).x),)
  MEM_PATH := $(ROOT)/programs/$(TEST).x
else
  MEM_PATH := $(ROOT)/programs/isa-tests/$(TEST).x
endif

SRC := $(addprefix $(ROOT)/rtl/, $(shell cat $(ROOT)/design.f)) \
       $(ROOT)/tb/clockgen.sv \
       $(ROOT)/tb/test_top.sv

compile:
	@echo "=== Compile ==="
	vlog -work $(ROOT)/work \
		-suppress 7061 -sv \
		+incdir+$(ROOT)/rtl/soc \
		+incdir+$(ROOT)/rtl/cpu \
		+incdir+$(ROOT)/rtl/periph \
		+incdir+$(ROOT)/tb \
		"+define+MEM_PATH=\"$(MEM_PATH)\"" \
		"+define+FONT_PATH=\"$(FONT_PATH)\"" \
		$(SRC)

run: compile
	@echo "=== Run ==="
	@echo "run -all" > $(ROOT)/run.macro
	vsim -suppress 3839 -c \
		-do $(ROOT)/run.macro \
		$(ROOT)/work.test_top

clean:
	rm -rf $(ROOT)/work $(ROOT)/run.macro

.PHONY: compile run clean
