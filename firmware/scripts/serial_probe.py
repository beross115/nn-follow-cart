#!/usr/bin/env python3
"""Probe whether opening /dev/ttyUSB0 restarts the ESP32 (DTR/RTS/EN)."""
from __future__ import annotations

import array
import fcntl
import os
import sys
import time

import serial
import termios

PORT = os.environ.get("NN_SERIAL_PORT", "/dev/ttyUSB0")
BAUD = 115200


def collect(ser: serial.Serial, secs: float = 2.0) -> str:
    t0 = time.time()
    buf = b""
    while time.time() - t0 < secs:
        buf += ser.read(4096)
    ser.close()
    return buf.decode("utf-8", errors="replace")


def analyze(label: str, text: str) -> None:
    start_signs = any(
        s in text for s in ("PRIMARY ===", "rst:0x", "entry 0x", "advertising as")
    )
    idle = ("[P] rssi=" in text) and ("PRIMARY ===" not in text) and ("rst:0x" not in text)
    print(f"=== {label} === start_signs={start_signs} idle_stream={idle} nbytes={len(text)}")
    lines = [ln for ln in text.splitlines() if ln.strip()]
    for ln in lines[:6]:
        print(" ", ln[:120])
    print()


def open_preclear() -> str:
    ser = serial.Serial()
    ser.port = PORT
    ser.baudrate = BAUD
    ser.timeout = 0.2
    ser.dsrdtr = False
    ser.rtscts = False
    ser.dtr = False
    ser.rts = False
    ser.open()
    return collect(ser)


def clear_modem_lines(fd: int) -> None:
    attrs = termios.tcgetattr(fd)
    # c_cflag index 2 — clear hangup-on-close
    attrs[2] = attrs[2] & ~getattr(termios, "HUPCL", 0)
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    tio_cmget = 0x5415
    tio_cmset = 0x5418
    tiocm_dtr = 0x002
    tiocm_rts = 0x004
    buf = array.array("i", [0])
    fcntl.ioctl(fd, tio_cmget, buf, True)
    buf[0] = buf[0] & ~(tiocm_dtr | tiocm_rts)
    fcntl.ioctl(fd, tio_cmset, buf, True)


def open_termios_first() -> str:
    fd = os.open(PORT, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    try:
        clear_modem_lines(fd)
    finally:
        os.close(fd)
    time.sleep(0.05)
    return open_preclear()


def main() -> int:
    print(f"port={PORT}", flush=True)
    analyze("preclear dtr/rts before open", open_preclear())
    time.sleep(2.5)
    analyze("termios clear then open", open_termios_first())
    return 0


if __name__ == "__main__":
    sys.exit(main())
