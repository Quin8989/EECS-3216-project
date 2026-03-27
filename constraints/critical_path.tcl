project_open de10_lite
create_timing_netlist
read_sdc
update_timing_netlist
report_timing -setup -npaths 1 -detail full_path -from_clock clk_25m -to_clock clk_25m
project_close
