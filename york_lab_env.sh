#!/bin/bash

echo "===== EECS 3216 Project Environment Setup ====="
export PROJECT_ROOT=$(cd $(dirname ${BASH_SOURCE[0]}); pwd)
echo "Location of project:  ${PROJECT_ROOT}"
export PATH=$PATH:/pkgcache/intelFPGA_lite/20.1/modelsim_ase/linuxaloem/
export VSIM_VERSION=$(vsim -version 2>/dev/null | head -n 1)
echo "VSIM version:  ${VSIM_VERSION}"
export VERILATOR_VERSION=$(verilator --version 2>/dev/null | head -n 1)
echo "Verilator version:  ${VERILATOR_VERSION}"
