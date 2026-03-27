"""Parse VCD trace and dump a cycle-by-cycle log of key CPU/bus signals."""
import sys, re

# ── Parse VCD header: build code→(name, width) mapping ──────
signals = {}   # code → (hierarchical_name, width)
scope = []

# Signal patterns we care about
WANT = {
    'TOP.test_top.dut.u_cpu.u_fetch.pc_o': 'PC',
    'TOP.test_top.dut.u_cpu.insn':        'INSN',
    'TOP.test_top.dut.u_cpu.any_stall':   'STALL',
    'TOP.test_top.dut.u_cpu.load_stall':  'LSTALL',
    'TOP.test_top.dut.u_cpu.load_wb':     'LWB',
    'TOP.test_top.dut.u_cpu.div_stall':   'DSTALL',
    'TOP.test_top.dut.u_cpu.shift_stall': 'SSTALL',
    'TOP.test_top.dut.u_cpu.mul_stall':   'MSTALL',
    'TOP.test_top.dut.dmem_addr':         'DADDR',
    'TOP.test_top.dut.dmem_rdata':        'DRDATA',
    'TOP.test_top.dut.dmem_wdata':        'DWDATA',
    'TOP.test_top.dut.dmem_wen':          'DWEN',
    'TOP.test_top.dut.dmem_ren':          'DREN',
    'TOP.test_top.dut.sel':               'SEL',
    'TOP.test_top.dut.u_cpu.u_alu.result_o': 'ALURES',
    'TOP.test_top.dut.u_cpu.u_alu.div_state': 'DIVST',
    'TOP.test_top.dut.u_cpu.u_alu.div_count': 'DIVCNT',
    'TOP.test_top.dut.u_cpu.wb_data':     'WBDATA',
    'TOP.test_top.dut.u_cpu.rd':          'RD',
    'TOP.test_top.dut.u_cpu.regwren':     'RWEN',
    'TOP.test_top.dut.u_cpu.wbsel':       'WBSEL',
    'TOP.test_top.dut.u_cpu.brtaken':     'BRTK',
    'TOP.test_top.dut.u_cpu.rs1_data':    'RS1D',
    'TOP.test_top.dut.u_cpu.rs2_data':    'RS2D',
    'TOP.test_top.dut.u_cpu.opcode':      'OPC',
    'TOP.test_top.dut.u_cpu.funct3':      'F3',
    'TOP.test_top.dut.u_cpu.funct7':      'F7',
    'TOP.test_top.dut.u_cpu.u_alu.alu_res_comb': 'ALUCOMB',
    'TOP.test_top.dut.u_cpu.u_alu.alusel_i': 'ALUSEL',
    'TOP.test_top.dut.u_uart.tx_ready':   'UTXRDY',
    'TOP.test_top.dut.uart_rdata':        'URTDATA',
    'TOP.test_top.reset':                 'RESET',
    'TOP.test_top.clk':                   'CLK',
}

code_to_tag = {}  # VCD code → short tag
tag_values = {}   # tag → current value string

vcd_path = 'trace.vcd'

with open(vcd_path, 'r') as f:
    # Parse header
    for line in f:
        line = line.strip()
        if line.startswith('$scope'):
            parts = line.split()
            scope.append(parts[2])
        elif line.startswith('$upscope'):
            if scope:
                scope.pop()
        elif line.startswith('$var'):
            parts = line.split()
            code = parts[3]
            name = parts[4]
            width = int(parts[2])
            full = '.'.join(scope) + '.' + name
            signals[code] = (full, width)
            if full in WANT:
                tag = WANT[full]
                code_to_tag[code] = tag
                tag_values[tag] = '0'
        elif line.startswith('$enddefinitions'):
            break

    print(f"Matched {len(code_to_tag)} signals out of {len(WANT)} wanted")
    # Show which wanted signals were NOT found
    found_fulls = set()
    for code, (full, w) in signals.items():
        if full in WANT:
            found_fulls.add(full)
    missing = set(WANT.keys()) - found_fulls
    if missing:
        print(f"Missing: {missing}")

    # Parse value changes
    time = 0
    cycles = []  # list of (time, snapshot_dict)
    prev_clk = '0'

    for line in f:
        line = line.strip()
        if not line:
            continue
        if line[0] == '#':
            time = int(line[1:])
            continue
        # Single-bit value change: 0x or 1x
        if line[0] in '01xzXZ' and len(line) >= 2:
            val = line[0]
            code = line[1:]
            if code in code_to_tag:
                tag = code_to_tag[code]
                tag_values[tag] = val

                # Detect rising clock edge
                if tag == 'CLK' and val == '1' and prev_clk == '0':
                    cycles.append((time, dict(tag_values)))
                if tag == 'CLK':
                    prev_clk = val
        # Multi-bit value change: bXXXX code
        elif line[0] == 'b' or line[0] == 'B':
            parts = line.split()
            if len(parts) == 2:
                val = parts[0][1:]  # strip 'b'
                code = parts[1]
                if code in code_to_tag:
                    tag = code_to_tag[code]
                    tag_values[tag] = val

print(f"\nTotal clock cycles: {len(cycles)}")

# ── Dump cycle-by-cycle log ────────────────────────────────
def to_hex(binstr, width=32):
    """Convert binary string to hex."""
    try:
        if 'x' in binstr or 'X' in binstr:
            return 'x' * (width//4)
        val = int(binstr, 2)
        return f'{val:0{width//4}x}'
    except:
        return binstr

def to_int(binstr):
    try:
        if 'x' in binstr or 'X' in binstr:
            return -1
        return int(binstr, 2)
    except:
        return -1

# Print header
print(f"\n{'CYC':>5} {'TIME':>8} {'PC':>10} {'INSN':>10} {'STL':>3} "
      f"{'DADDR':>10} {'DRDATA':>10} {'DWDATA':>10} {'WEN':>3} {'REN':>3} "
      f"{'SEL':>4} {'ALURES':>10} {'WBDATA':>10} {'RD':>3} {'RWEN':>4} "
      f"{'BRTK':>4} {'UTXRDY':>6}")

for i, (t, snap) in enumerate(cycles):
    # Skip reset
    if snap.get('RESET', '1') == '1':
        continue

    pc    = to_hex(snap.get('PC', '0'))
    insn  = to_hex(snap.get('INSN', '0'))
    stall = snap.get('STALL', '0')
    lstall = snap.get('LSTALL', '0')
    lwb    = snap.get('LWB', '0')
    daddr = to_hex(snap.get('DADDR', '0'))
    drdata = to_hex(snap.get('DRDATA', '0'))
    dwdata = to_hex(snap.get('DWDATA', '0'))
    wen   = snap.get('DWEN', '0')
    ren   = snap.get('DREN', '0')
    sel   = to_hex(snap.get('SEL', '0'), 8)
    alures = to_hex(snap.get('ALURES', '0'))
    wbdata = to_hex(snap.get('WBDATA', '0'))
    rd    = to_int(snap.get('RD', '0'))
    rwen  = snap.get('RWEN', '0')
    brtk  = snap.get('BRTK', '0')
    utxrdy = snap.get('UTXRDY', '0')

    stall_str = ''
    if lstall == '1': stall_str += 'L'
    if lwb == '1': stall_str += 'W'
    if snap.get('DSTALL', '0') == '1': stall_str += 'D'
    if snap.get('SSTALL', '0') == '1': stall_str += 'S'
    if snap.get('MSTALL', '0') == '1': stall_str += 'M'
    if not stall_str: stall_str = '.'

    print(f'{i:5d} {t:8d} {pc:>10} {insn:>10} {stall_str:>3} '
          f'{daddr:>10} {drdata:>10} {dwdata:>10} {wen:>3} {ren:>3} '
          f'{sel:>4} {alures:>10} {wbdata:>10} {rd:>3} {rwen:>4} '
          f'{brtk:>4} {utxrdy:>6}')

    # Stop at 200 cycles for readability
    if i > 220:
        print("... (truncated)")
        break
