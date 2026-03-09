# EECS 3216 Project - Main Makefile
#
# Usage:
#   make compile VSIM=1    Compile with ModelSim
#   make run     VSIM=1    Simulate
#   make clean             Remove build artifacts
#   make package TEAM=<name>

export CL_ROOT = $(realpath $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))/../..)
export SIM_DIR = $(CL_ROOT)/verif/sim

# Simulator selection
ifeq ($(VSIM), 1)
    export SIMULATOR = vsim
    include Makefile.vsim
endif

# Packaging
package:
	tar czvf package.$(TEAM).tar.gz \
		-C $(CL_ROOT) ./design/code ./verif/scripts/design.f

.PHONY: compile run clean package
