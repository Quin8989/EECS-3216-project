# keyboard_server.tcl — JTAG keyboard injection server for EECS 3216 SoC
#
# Runs inside Intel System Console.  Opens a TCP socket server on $PORT.
# Each byte received from a connected client is written to the JTAG keyboard
# injection address (JTAG_KBD_INJECT_ADDR in top_fpga.sv), which the RTL
# captures and delivers to the keyboard peripheral at 0x40000000.
#
# Usage (Linux / York lab):
#   system-console --no-gui --script=tools/keyboard_server.tcl
#
# Usage (Windows):
#   & "C:\altera_lite\25.1std\quartus\sopc_builder\bin\system-console.exe" --no-gui --script=tools/keyboard_server.tcl
#
# Then in another terminal:
#   python3 tools/keyboard_inject.py
#   (or:  python tools/keyboard_inject.py  on Windows)
#
# The FPGA must already be programmed before running this script.

set INJECT_ADDR 0x4FFFFF00   ;# JTAG_KBD_INJECT_ADDR from top_fpga.sv
set PORT        2540

# ── Connect to JTAG master ───────────────────────────────────────────────────

set masters [get_service_paths master]
if {[llength $masters] == 0} {
    puts "ERROR: No JTAG master found."
    puts "Make sure the FPGA is programmed with the JTAG master IP."
    exit 1
}

set master [lindex $masters 0]
open_service master $master
puts "JTAG master: $master"

# ── Socket server ────────────────────────────────────────────────────────────

proc inject_byte {val} {
    global master INJECT_ADDR
    master_write_32 $master $INJECT_ADDR $val
}

proc handle_key {chan} {
    if {[eof $chan]} {
        close $chan
        puts "Client disconnected."
        return
    }
    set raw [read $chan 1]
    if {$raw ne ""} {
        binary scan $raw cu val
        inject_byte $val
    }
}

proc accept_conn {chan addr port} {
    puts "Client connected from $addr:$port"
    fconfigure $chan -translation binary -blocking 0 -buffering none
    fileevent $chan readable [list handle_key $chan]
}

socket -server accept_conn $PORT
puts "Keyboard server listening on TCP port $PORT."
puts "Run  python3 tools/keyboard_inject.py  to connect."
puts "(Ctrl+C in the Python script to quit.)"

# Block here, running the Tcl event loop so fileevent callbacks fire.
vwait forever
