# read_diag.tcl — Read diagnostic test results from FPGA via JTAG
# Reads specific framebuffer rows to check pixel colors.
# Run: system-console --script read_diag.tcl

set masters [get_service_paths master]
if {[llength $masters] == 0} {
    puts "ERROR: No JTAG masters found"
    exit 1
}
set m [lindex $masters 0]
open_service master $m

# FB_BASE = 0x80000000, each row = 320 bytes = 80 words
# We read just the first word of specific rows.
set FB 0x80000000

# Helper: read first word of a row
proc read_row {m base row} {
    set addr [expr {$base + $row * 320}]
    set val [master_read_32 $m $addr 1]
    return $val
}

# Known color words
# GREEN4  = 0x1C1C1C1C
# RED4    = 0xE0E0E0E0  
# BLUE4   = 0x03030303
# CYAN4   = 0x1F1F1F1F
# YELLOW4 = 0xFCFCFCFC
# WHITE4  = 0xFFFFFFFF

proc decode_color {val} {
    switch -- $val {
        0x1C1C1C1C { return "GREEN (PASS)" }
        0xE0E0E0E0 { return "RED (FAIL)" }
        0x03030303 { return "BLUE (in progress)" }
        0x1F1F1F1F { return "CYAN (UART ok)" }
        0xFCFCFCFC { return "YELLOW (complete)" }
        0xFFFFFFFF { return "WHITE (untouched)" }
        0x00000000 { return "BLACK (never written)" }
        default    { return "UNKNOWN ($val)" }
    }
}

puts "=== Diagnostic Results ==="
puts ""

set tests {
    {0  "Background fill"}
    {35 "SRL (logical shift right)"}
    {45 "SRA (arithmetic shift right)"}
    {55 "SLL (left shift)"}
    {75 "MUL"}
    {85 "MULH (64-bit high)"}
    {105 "DIVU (unsigned divide)"}
    {115 "DIV (signed divide)"}
    {125 "REMU (unsigned remainder)"}
    {145 "UART test"}
    {165 "64-bit division (__divdi3)"}
    {185 "Volatile add (sanity)"}
    {235 "End marker"}
}

foreach t $tests {
    set row [lindex $t 0]
    set name [lindex $t 1]
    set val [read_row $m $FB $row]
    set color [decode_color $val]
    puts [format "  Row %3d  %-32s  %s" $row $name $color]
}

puts ""
puts "=== Done ==="
close_service master $m
