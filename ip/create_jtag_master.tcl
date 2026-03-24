# Create JTAG-to-Avalon Master system for DE10-Lite
# Run with: qsys-script --script=create_jtag_master.tcl

package require -exact qsys 20.1

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
