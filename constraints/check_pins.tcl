project_open de10_lite
load_package device
set device_name [get_part_info -device 10M50DAF484C7G]
foreach_in_collection pin [get_pkg_pin_names -device 10M50DAF484C7G] {
    set p [lindex [get_pkg_pin_names -pin_name "\"] 0]
    if {[string match "PIN_W*" "\"]} { puts "\" }
}
project_close
