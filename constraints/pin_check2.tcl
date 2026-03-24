project_open de10_lite
load_package flow
set device [get_global_assignment -name DEVICE]
puts "Device: $device"
load_package advanced_device
set all_pins [get_pad_data STRING_PAD_TO_PIN_MAP -device $device]
foreach p $all_pins {
    if {[string match "PIN_W*" $p] || [string match "*W21*" $p]} {
        puts $p
    }
}
project_close
