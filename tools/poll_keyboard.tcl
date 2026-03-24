# Poll the keyboard MMIO registers through the Intel JTAG-to-Avalon master.
#
# Run with:
#   system-console --script=tools/poll_keyboard.tcl
#   system-console --script=tools/poll_keyboard.tcl 15000

set poll_ms 15000
if {$argc >= 1} {
    set poll_ms [lindex $argv 0]
}

set keyboard_data_addr   0x40000000
set keyboard_status_addr 0x40000004

proc read_word {master addr} {
    return [lindex [master_read_32 $master $addr 1] 0]
}

set masters [get_service_paths master]
if {[llength $masters] == 0} {
    puts "ERROR: No JTAG master services found"
    exit 1
}

set master [lindex $masters 0]
open_service master $master

puts "Using master: $master"
puts [format "Polling keyboard status at 0x%08X and data at 0x%08X" $keyboard_status_addr $keyboard_data_addr]
puts [format "Polling for %d ms" $poll_ms]

set start_ms [clock milliseconds]
set samples 0
set events 0

while {[expr {[clock milliseconds] - $start_ms}] < $poll_ms} {
    set status [read_word $master $keyboard_status_addr]
    incr samples

    if {$status != 0} {
        set code [read_word $master $keyboard_data_addr]
        incr events
        puts [format "EVENT t=%6dms status=0x%08X code=0x%02X" [expr {[clock milliseconds] - $start_ms}] $status [expr {$code & 0xFF}]]
    }

    after 20
}

puts [format "Done. Samples=%d Events=%d" $samples $events]

close_service master $master