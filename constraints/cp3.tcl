project_open de10_lite
create_timing_netlist
read_sdc
update_timing_netlist
report_timing -setup -npaths 1 -from_clock clk_25m -to_clock clk_25m -detail summary
project_close
