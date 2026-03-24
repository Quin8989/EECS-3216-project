# JTAG smoke + throughput test for the Intel JTAG-to-Avalon Master.
#
# Purpose:
# - prove a write transaction completes
# - prove a read transaction returns the expected data
# - measure sustained chunked write throughput
#
# Run with: system-console --script=test_intel_master.tcl

# Find and claim the master service
set masters [get_service_paths master]
puts "Available masters: $masters"

if {[llength $masters] == 0} {
    puts "ERROR: No master services found. Make sure FPGA is programmed with JTAG master IP."
    exit 1
}

set master_path [lindex $masters 0]
puts "Using master: $master_path"

# Open the master
set claim_result [open_service master $master_path]
puts "Claimed master service"

# Test parameters
set base_addr 0x04000000  ;# SDRAM base address
set chunk_size 16384      ;# 16 KB chunks (worked before)
set num_chunks 4          ;# Total 64 KB

puts "\n=== Smoke Test (single word write/read) ==="
master_write_32 $master_path $base_addr 0xCAFEBABE
set smoke_read [master_read_32 $master_path $base_addr 1]
puts "Read back smoke word: 0x[format %08X $smoke_read]"
if {$smoke_read != 0xCAFEBABE} {
    puts "ERROR: Smoke test failed"
    close_service master $master_path
    exit 1
}
puts "Smoke test OK"

# Pre-generate 16KB of test data once
puts "Generating test data pattern..."
set chunk_data [list]
for {set i 0} {$i < $chunk_size} {incr i} {
    lappend chunk_data [expr {$i & 0xFF}]
}
puts "Test data ready (16 KB chunk)"

# Write test - measure time with chunked transfers
puts "\n=== Chunked Write Speed Test ($num_chunks x 16 KB = 64 KB) ==="

set total_bytes 0
set start_time [clock milliseconds]

for {set c 0} {$c < $num_chunks} {incr c} {
    set addr [expr {$base_addr + ($c * $chunk_size)}]
    puts "  Chunk $c: writing to 0x[format %08X $addr]..."
    master_write_memory $master_path $addr $chunk_data
    incr total_bytes $chunk_size
}

set end_time [clock milliseconds]
set elapsed_ms [expr {$end_time - $start_time}]
set speed_kbps [expr {$total_bytes * 1000.0 / $elapsed_ms / 1024.0}]

puts "\nTotal bytes: $total_bytes"
puts "Elapsed: ${elapsed_ms} ms"
puts "Speed: [format %.1f $speed_kbps] KB/s"
puts "Estimated 4 MB load time: [format %.1f [expr {4096.0 / $speed_kbps}]] seconds"

# Do a single word read to verify write worked
puts "\n=== Quick Verify (single word read) ==="
set verify_data [master_read_32 $master_path $base_addr 1]
puts "Read back first word: 0x[format %08X $verify_data]"
set expected [expr {0x00 | (0x01 << 8) | (0x02 << 16) | (0x03 << 24)}]
if {$verify_data == $expected} {
    puts "Verification OK!"
} else {
    puts "ERROR: Verification failed"
    puts "Expected: 0x[format %08X $expected]"
    close_service master $master_path
    exit 1
}

# Close master
close_service master $master_path
puts "\nDone."
