project_open de10_lite
load_package device 
set pins [get_pkg_pin_names -device [get_part_info -device_name]]
foreach pin $pins {
    if {[string match "*W2*" $pin]} { puts $pin }
}
project_close
