project_open de10_lite
create_timing_netlist
read_sdc
update_timing_netlist
set path [lindex [get_timing_paths -setup -npaths 1 -from_clock clk_25m -to_clock clk_25m] 0]
puts "FROM: [get_node_info -name [get_path_info -from ]]"
puts "TO:   [get_node_info -name [get_path_info -to ]]"
puts "SLACK: [get_path_info -slack ]"
project_close
