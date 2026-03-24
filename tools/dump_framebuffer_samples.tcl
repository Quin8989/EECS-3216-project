# Dump representative framebuffer words from SDRAM through the Intel JTAG master.
#
# Run with:
#   system-console --script=tools/dump_framebuffer_samples.tcl

proc fb_addr {x y} {
    set words_per_line 80
    set base 0x04000000
    set word_index [expr {$y * $words_per_line + ($x / 4)}]
    return [expr {$base + ($word_index * 4)}]
}

proc read_word {master addr} {
    return [master_read_32 $master $addr 1]
}

set masters [get_service_paths master]
if {[llength $masters] == 0} {
    puts "ERROR: No JTAG master services found"
    exit 1
}

set master [lindex $masters 0]
open_service master $master

puts "Using master: $master"
puts "Framebuffer base: 0x04000000"

set samples {
    {0   0   "top_left_border"}
    {16  16  "upper_gradient"}
    {100 60  "left_mid_gradient"}
    {160 120 "center_rect"}
    {280 200 "lower_gradient"}
    {319 239 "bottom_right_border"}
}

puts "\nSample pixels (read as containing 32-bit word):"
foreach sample $samples {
    lassign $sample x y label
    set addr [fb_addr $x $y]
    set word [read_word $master $addr]
    puts [format "  %-20s x=%3d y=%3d addr=0x%08X word=0x%08X" $label $x $y $addr $word]
}

puts "\nFirst 8 words of row 0:"
for {set i 0} {$i < 8} {incr i} {
    set addr [expr {0x04000000 + ($i * 4)}]
    set word [read_word $master $addr]
    puts [format "  row0[%d]  addr=0x%08X word=0x%08X" $i $addr $word]
}

puts "\nFirst 8 words of row 120:"
set row120_base [fb_addr 0 120]
for {set i 0} {$i < 8} {incr i} {
    set addr [expr {$row120_base + ($i * 4)}]
    set word [read_word $master $addr]
    puts [format "  row120[%d] addr=0x%08X word=0x%08X" $i $addr $word]
}

close_service master $master
puts "\nDone."