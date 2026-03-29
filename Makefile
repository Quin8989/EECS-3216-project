# EECS 3216 Project — Simulation
#
# The Verilator binary is compiled ONCE (make compile) and reused for every
# test.  Programs are loaded at runtime via +MEM_PATH=<file> plusarg.
#
# Usage:
#   make compile                 Build the Verilator binary (once)
#   make run TEST=test1          Compile (if needed) + simulate one program
#   make run-all                 Run every ISA + SoC test
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

# Build directory — no tracing for fast simulation
VDIR   := $(ROOT)/work/sim
SIM    := $(VDIR)/V$(TB)
VFLAGS_BASE := --binary --timing --sv \
          $(addprefix +incdir+,$(INC_DIRS)) \
          --top-module $(TB) \
          --public-flat-rw \
          --x-assign 0 --x-initial 0 \
          -Wno-TIMESCALEMOD \
          -Wno-WIDTHEXPAND \
          -Wno-WIDTHTRUNC \
          -Wno-PINMISSING \
          $(EXTRA_VFLAGS) \
          -j 0
VFLAGS := $(VFLAGS_BASE) -Mdir $(VDIR)

# Stamp file: recompile only when sources change
STAMP := $(VDIR)/.built
$(STAMP): $(SRC)
	@echo "=== Compile (Verilator, no-trace) ==="
	@mkdir -p $(VDIR)
	verilator $(VFLAGS) $(SRC)
	@touch $@

compile: $(STAMP)

run: compile
	@echo "=== Run $(TEST) ==="
	@$(SIM) +MEM_PATH=$(MEM_PATH)

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

# ---------- VGA frame gallery ----------
GALLERY_TEST   ?= demo
GALLERY_FRAMES ?= 10
GALLERY_DIR    ?= $(ROOT)/work/gallery

vga-gallery: compile
	@echo "=== Build $(GALLERY_TEST) ==="
	@$(ROOT)/tools/build.sh $(GALLERY_TEST)
	@mkdir -p $(GALLERY_DIR)
	@echo "=== Simulate $(GALLERY_TEST) (capture $(GALLERY_FRAMES) frames) ==="
	@cd $(GALLERY_DIR) && rm -f vga_frame*.ppm && $(SIM) +MEM_PATH=$(call find_hex,$(GALLERY_TEST)) +TIMEOUT_MS=1000 +MIN_FRAMES=$(GALLERY_FRAMES) +CAPTURE_FRAMES=1 +CAPTURE_MAX_FRAMES=$(GALLERY_FRAMES) +STOP_AFTER_MIN_FRAMES
	@echo "=== Generate HTML gallery ==="
	@python3 $(ROOT)/tools/vga_frames.py gallery \
		--frames $(GALLERY_FRAMES) --dir $(GALLERY_DIR) \
		--name $(GALLERY_TEST) -o $(GALLERY_DIR)/vga_gallery.html
	@echo "=== Gallery: $(GALLERY_DIR)/vga_gallery.html ==="

.PHONY: compile run run-all clean vga-gallery
