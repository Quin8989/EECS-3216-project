# SDRAM Loader via Intel JTAG-to-Avalon Master
# Usage: system-console --script=jtag_loader.tcl <filename> [base_address]
#
# Example: system-console --script=jtag_loader.tcl game.bin 0x04000000

proc load_file {filename base_addr} {
    # Find and claim master
    set masters [get_service_paths master]
    if {[llength $masters] == 0} {
        error "No JTAG master found. Ensure FPGA is programmed."
    }
    
    set master [lindex $masters 0]
    puts "Using master: $master"
    open_service master $master
    
    # Read file
    puts "Loading file: $filename"
    set fp [open $filename rb]
    set data [read $fp]
    close $fp
    
    set file_size [string length $data]
    puts "File size: $file_size bytes ([expr {$file_size / 1024}] KB)"
    
    # Convert to byte list
    set bytes [list]
    for {set i 0} {$i < $file_size} {incr i} {
        lappend bytes [scan [string index $data $i] %c]
    }
    
    # Write in 16KB chunks (optimal for speed)
    set chunk_size 16384
    set num_chunks [expr {($file_size + $chunk_size - 1) / $chunk_size}]
    
    puts "Writing to 0x[format %08X $base_addr] in $num_chunks chunks..."
    set start_time [clock milliseconds]
    
    for {set c 0} {$c < $num_chunks} {incr c} {
        set offset [expr {$c * $chunk_size}]
        set addr [expr {$base_addr + $offset}]
        set remaining [expr {$file_size - $offset}]
        set len [expr {$remaining < $chunk_size ? $remaining : $chunk_size}]
        
        set chunk [lrange $bytes $offset [expr {$offset + $len - 1}]]
        master_write_memory $master $addr $chunk
        
        set pct [expr {($c + 1) * 100 / $num_chunks}]
        puts -nonewline "\r  Progress: $pct% (chunk [expr {$c + 1}]/$num_chunks)"
        flush stdout
    }
    puts ""
    
    set end_time [clock milliseconds]
    set elapsed_ms [expr {$end_time - $start_time}]
    set speed_kbps [expr {$file_size * 1000.0 / $elapsed_ms / 1024.0}]
    
    puts "Done!"
    puts "Elapsed: [expr {$elapsed_ms / 1000.0}] seconds"
    puts "Speed: [format %.1f $speed_kbps] KB/s"
    
    # Verify first word
    puts "\nVerifying first word..."
    set verify [master_read_32 $master $base_addr 1]
    set expected [expr {[lindex $bytes 0] | ([lindex $bytes 1] << 8) | ([lindex $bytes 2] << 16) | ([lindex $bytes 3] << 24)}]
    if {$verify == $expected} {
        puts "Verification OK: 0x[format %08X $verify]"
    } else {
        puts "WARNING: First word mismatch!"
        puts "  Expected: 0x[format %08X $expected]"
        puts "  Read:     0x[format %08X $verify]"
    }
    
    close_service master $master
}

# Parse arguments
if {$argc < 1} {
    puts "Usage: system-console --script=jtag_loader.tcl <filename> \[base_address\]"
    puts "  filename:     Binary file to load"
    puts "  base_address: SDRAM address (default: 0x04000000)"
    exit 1
}

set filename [lindex $argv 0]
set base_addr 0x04000000
if {$argc >= 2} {
    set base_addr [lindex $argv 1]
}

load_file $filename $base_addr
