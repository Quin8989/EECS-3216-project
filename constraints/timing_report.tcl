project_open de10_lite
create_timing_netlist
read_sdc
update_timing_netlist
report_timing -setup -npaths 5 -detail full_path
project_close
