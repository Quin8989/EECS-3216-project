#!/usr/bin/env python3
"""
keyboard_inject.py — Capture desktop keypresses and inject into RISC-V SoC
via the System Console JTAG keyboard server (keyboard_server.tcl).

Each keypress is sent as a single ASCII byte (e.g., 'w'=0x77, ' '=0x20) to
the Tcl server, which writes it to the JTAG keyboard injection address.
The FPGA RTL captures it and delivers it to the keyboard peripheral.

NOTE: This sends ASCII codes, NOT PS/2 scan codes. Software reading the
keyboard peripheral should compare against ASCII values like 'w', 's', ' '.

Usage
-----
  Linux / York lab:
      python3 tools/keyboard_inject.py

  Windows (from project root):
      python tools\\keyboard_inject.py

Requirements
------------
  Python 3.x, stdlib only (no pip installs needed).
  System Console must be running keyboard_server.tcl first.
"""

import socket
import sys

HOST = 'localhost'
PORT = 2540


def main():
    print(f"Connecting to keyboard server at {HOST}:{PORT} ...")
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    try:
        sock.connect((HOST, PORT))
    except ConnectionRefusedError:
        print("ERROR: Connection refused.")
        print("Is System Console running tools/keyboard_server.tcl ?")
        sys.exit(1)

    print("Connected.  Type on your keyboard — chars appear on the FPGA VGA output.")
    print("Press Ctrl+C to quit.\n")

    try:
        if sys.platform == 'win32':
            _run_windows(sock)
        else:
            _run_linux(sock)
    finally:
        sock.close()


def _run_linux(sock):
    """Read one raw byte at a time from stdin (no echo, no line buffering)."""
    import tty
    import termios

    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        while True:
            ch = sys.stdin.buffer.read(1)
            if not ch:
                break
            if ch == b'\x03':   # Ctrl+C
                print("\r\nQuit.")
                break
            sock.sendall(ch)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)


def _run_windows(sock):
    """Read one character at a time using msvcrt (no Enter needed)."""
    import msvcrt

    while True:
        # getwch returns a wide char; encode to latin-1 for single-byte values.
        ch = msvcrt.getwch()
        if ch == '\x03':        # Ctrl+C
            print("\nQuit.")
            break
        try:
            sock.sendall(ch.encode('latin-1'))
        except (UnicodeEncodeError, ValueError):
            pass   # ignore unmappable keys


if __name__ == '__main__':
    main()
