# Inject one keyboard scan code into the FPGA over JTAG.
#
# Usage:
#   system-console --script=tools/inject_key_jtag.tcl 0x1D
#
# Reserved injection address is decoded in rtl/soc/top_fpga.sv.

set inject_addr 0x4FFFFF00

if {$argc < 1} {
    puts "ERROR: missing scan code argument (for example: 0x1D)"
    exit 1
}

set raw_arg [lindex $argv 0]
if {[scan $raw_arg "%i" scan_code] != 1} {
    puts "ERROR: invalid scan code '$raw_arg'"
    exit 1
}
set scan_code [expr {$scan_code & 0xFF}]

set masters [get_service_paths master]
if {[llength $masters] == 0} {
    puts "ERROR: No JTAG master services found"
    exit 1
}

set master [lindex $masters 0]
open_service master $master

master_write_32 $master $inject_addr [list $scan_code]
puts [format "Injected scan code 0x%02X via %s" $scan_code $master]

close_service master $master
