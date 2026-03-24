project_open de10_lite
create_timing_netlist
read_sdc
update_timing_netlist
report_timing -setup -npaths 3 -detail path_only
project_close
