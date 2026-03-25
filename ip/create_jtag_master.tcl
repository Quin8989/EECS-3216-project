# Create JTAG-to-Avalon Master system for DE10-Lite
#
# The committed ip/jtag_master/ tree was generated with Quartus 25.1.
# Quartus cannot compile IP from a *newer* version, so if you are on
# an older Quartus (e.g. 20.1 at York) you must regenerate:
#
#   cd <repo>/ip
#   qsys-script --script=create_jtag_master.tcl
#
# This will recreate jtag_master.qsys and the synthesis/ output for
# your local Quartus version.

# Accept whichever Qsys package version the current Quartus provides.
package require qsys

# Create the system
create_system jtag_master

# Set device family
set_project_property DEVICE_FAMILY {MAX 10}
set_project_property DEVICE {10M50DAF484C7G}

# Add clock source
add_instance clk_0 clock_source
set_instance_parameter_value clk_0 clockFrequency {25000000}
set_instance_parameter_value clk_0 resetSynchronousEdges {DEASSERT}

# Add JTAG-to-Avalon Master Bridge
add_instance jtag_master_0 altera_jtag_avalon_master
set_instance_parameter_value jtag_master_0 USE_PLI {0}
set_instance_parameter_value jtag_master_0 PLI_PORT {50000}

# Connect clock and reset
add_connection clk_0.clk jtag_master_0.clk
add_connection clk_0.clk_reset jtag_master_0.clk_reset

# Export interfaces using set_interface_property
add_interface clk clock sink
set_interface_property clk EXPORT_OF clk_0.clk_in

add_interface reset reset sink  
set_interface_property reset EXPORT_OF clk_0.clk_in_reset

add_interface master avalon master
set_interface_property master EXPORT_OF jtag_master_0.master

# Save
save_system jtag_master.qsys

# Generate HDL
generate_system jtag_master -synthesis VERILOG
