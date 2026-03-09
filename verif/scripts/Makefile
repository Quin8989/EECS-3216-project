# EECS 3216 Project - Main Makefile
#
# Usage:
#   make compile VSIM=1              Compile with ModelSim
#   make run     VSIM=1 TEST=test1   Simulate
#   make clean                       Remove build artifacts
#   make package TEAM=<name>         Tar design for submission

export TEST    ?= test1
export CL_ROOT  = $(realpath $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))/../..)
export SIM_DIR  = $(CL_ROOT)/verif/sim

# Memory parameters
MEM_PATH      ?= $(CL_ROOT)/verif/data/$(TEST).x
LINE_COUNT    ?= $(shell wc -l < $(MEM_PATH) 2>/dev/null || echo 0)
MEM_PATH_STR  ?= \"$(abspath $(MEM_PATH))\"
MEM_DEPTH     ?= 1048576
TIMEOUT       ?= 50000

# Simulator selection
ifeq ($(VSIM), 1)
    export SIMULATOR = vsim
    include Makefile.vsim
endif

# Packaging
package:
	tar czvf package.$(TEAM).tar.gz \
		-C $(CL_ROOT) ./design/code ./design/probes.svh ./design/design_wrapper.sv \
		./verif/scripts/design.f

.PHONY: compile run clean package
