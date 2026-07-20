#!/usr/bin/env python3
"""Hold-open serial watcher that avoids ESP32 EN reset when possible.

Many USB-UART bridges pulse DTR/RTS on port open; on ESP32 devkits that is
wired to EN / GPIO0 and reboots the chip mid-BLE session.

Usage:
  python3 firmware/scripts/serial_watch.py
  python3 firmware/scripts/serial_watch.py --seconds 60
  NN_SERIAL_PORT=/dev/ttyUSB0 python3 firmware/scripts/serial_watch.py

Leaves the port open for the whole window (open once). Prefer this over
repeated short polls while the phone is connected.
"""
from __future__ import annotations

import argparse
import os
import sys
import time

import serial

DEFAULT_PORT = os.environ.get("NN_SERIAL_PORT", "/dev/ttyUSB0")


def open_port(port: str, baud: int) -> serial.Serial:
    ser = serial.Serial()
    ser.port = port
    ser.baudrate = baud
    ser.timeout = 0.2
    ser.write_timeout = 0.2
    ser.dsrdtr = False
    ser.rtscts = False
    # Apply inactive modem lines at open (pyserial).
    ser.dtr = False
    ser.rts = False
    ser.open()
    try:
        ser.dtr = False
        ser.rts = False
    except Exception:
        pass
    return ser


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--port", default=DEFAULT_PORT)
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--seconds", type=float, default=0.0, help="0 = until Ctrl-C")
    args = ap.parse_args()

    print(
        f"serial_watch port={args.port} baud={args.baud} "
        f"dtr=0 rts=0 hold_open=1",
        flush=True,
    )
    print(
        "NOTE: first open may still glitch EN on some CP2102 setups; "
        "after that this process keeps the port open so BLE stays up.",
        flush=True,
    )

    ser = open_port(args.port, args.baud)
    t0 = time.time()
    nonzero = 0
    connects = 0
    try:
        while True:
            if args.seconds > 0 and (time.time() - t0) >= args.seconds:
                break
            data = ser.read(8192)
            if not data:
                continue
            text = data.decode("utf-8", errors="replace")
            sys.stdout.write(text)
            sys.stdout.flush()
            if "[BLE] connected" in text:
                connects += 1
            for line in text.splitlines():
                if "L=" in line and "R=" in line:
                    try:
                        lv = rv = 0
                        for p in line.replace(",", " ").split():
                            if p.startswith("L="):
                                lv = int(p.split("=", 1)[1])
                            elif p.startswith("R="):
                                rv = int(p.split("=", 1)[1])
                        if lv or rv:
                            nonzero += 1
                    except ValueError:
                        pass
    except KeyboardInterrupt:
        print("\n[watch] interrupted", flush=True)
    finally:
        ser.close()
        print(
            f"\n[watch] done connects={connects} nonzero_drive_lines={nonzero}",
            flush=True,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
