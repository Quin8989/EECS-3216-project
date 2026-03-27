# =============================================================================
# DE10-Lite SDC Timing Constraints
# =============================================================================

# ── System clock constraint ─────────────────────────────────────────────────
# Board oscillator is 50 MHz (20 ns).
create_clock -name clk_50m -period 20.000 [get_ports MAX10_CLK1_50]

# 25 MHz system clock (toggle FF divider in top_fpga)
create_generated_clock -name clk_25m \
    -source [get_ports MAX10_CLK1_50] \
    -divide_by 2 \
    [get_registers {clk_25m}]

# ── Input / output delay (relaxed — buttons, VGA DAC) ──────────────────────
set_input_delay  -clock clk_25m -max 5.0 [get_ports {KEY[*]}]
set_input_delay  -clock clk_25m -min 0.0 [get_ports {KEY[*]}]

set_output_delay -clock clk_25m -max 2.0 [get_ports {VGA_R[*] VGA_G[*] VGA_B[*] VGA_HS VGA_VS}]
set_output_delay -clock clk_25m -min 0.0 [get_ports {VGA_R[*] VGA_G[*] VGA_B[*] VGA_HS VGA_VS}]

set_output_delay -clock clk_25m -max 2.0 [get_ports {LEDR[*] GPIO[*]}]
set_output_delay -clock clk_25m -min 0.0 [get_ports {LEDR[*] GPIO[*]}]

# ── Clock uncertainty (removes Critical Warning 332168) ─────────────────────
derive_clock_uncertainty

# ── SDRAM pins are unused (driven to static idle in top_fpga.sv) ────────────
# No timing constraints needed — all DRAM_* outputs are constant.

# ── False paths (async inputs — buttons) ────────────────────────────────────
set_false_path -from [get_ports {KEY[*]}]
