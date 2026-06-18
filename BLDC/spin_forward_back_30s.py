import argparse
import logging
import time
from pathlib import Path

import serial
from serial.tools import list_ports


DEFAULT_SERIAL = "375438683232"
DEFAULT_BAUD = 115200
LOG_DIR = Path("logs")


def find_port(serial_hint):
    candidates = []
    for port in list_ports.comports():
        hwid = port.hwid.upper()
        desc = port.description.upper()
        if "1209:0D32" in hwid or "ODRIVE" in desc:
            candidates.append(port)
    if serial_hint:
        for port in candidates:
            if serial_hint in port.hwid:
                return port.device
    if candidates:
        return candidates[0].device
    raise RuntimeError("ODrive CDC COM port not found")


def build_logger():
    LOG_DIR.mkdir(exist_ok=True)
    stamp = time.strftime("%Y%m%d_%H%M%S")
    path = LOG_DIR / f"{stamp}_spin_forward_back_30s.log"
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
        handlers=[logging.FileHandler(path, encoding="utf-8"), logging.StreamHandler()],
    )
    logging.info("Logging to %s", path.resolve())


def command(ser, text, delay=0.04):
    logging.info("> %s", text)
    ser.write((text + "\n").encode("ascii"))
    ser.flush()
    time.sleep(delay)
    replies = []
    while ser.in_waiting:
        replies.append(ser.readline().decode("ascii", errors="replace").strip())
    for reply in replies:
        logging.info("< %s", reply)
    return replies[-1] if replies else None


def read(ser, prop):
    return command(ser, "r " + prop)


def write_and_check(ser, prop, value):
    command(ser, f"w {prop} {value}")
    return read(ser, prop)


def stop_axis(ser, pause_s):
    command(ser, "w axis0.controller.input_vel 0")
    command(ser, "w axis0.requested_state 1")
    time.sleep(pause_s)


def configure_temporary_lockin(ser, current, accel, velocity):
    # These settings are intentionally not saved to flash.
    write_and_check(ser, "axis0.motor.config.pre_calibrated", 1)
    write_and_check(ser, "axis0.controller.input_vel", 0)
    write_and_check(ser, "axis0.config.general_lockin.current", current)
    write_and_check(ser, "axis0.config.general_lockin.accel", accel)
    write_and_check(ser, "axis0.config.general_lockin.vel", abs(velocity))
    write_and_check(ser, "axis0.config.general_lockin.finish_on_vel", 0)
    write_and_check(ser, "axis0.config.general_lockin.finish_on_distance", 0)


def spin_leg(ser, name, direction, seconds, poll_s):
    logging.info("Starting %s leg: direction=%s duration=%.1fs", name, direction, seconds)
    stop_axis(ser, 0.3)
    write_and_check(ser, "axis0.motor.config.direction", direction)
    command(ser, "w axis0.requested_state 9")

    start = time.monotonic()
    while time.monotonic() - start < seconds:
        elapsed = time.monotonic() - start
        logging.info("%s t=%.1fs", name, elapsed)
        for prop in (
            "vbus_voltage",
            "axis0.current_state",
            "axis0.error",
            "axis0.motor.error",
            "axis0.encoder.error",
        ):
            read(ser, prop)
        time.sleep(poll_s)

    stop_axis(ser, 0.5)
    logging.info("Finished %s leg", name)


def main():
    parser = argparse.ArgumentParser(description="Run ODESC/ODrive lockin spin forward, stop, then reverse.")
    parser.add_argument("--port", help="COM port, for example COM5. Auto-detected by default.")
    parser.add_argument("--serial", default=DEFAULT_SERIAL)
    parser.add_argument("--baud", type=int, default=DEFAULT_BAUD)
    parser.add_argument("--seconds", type=float, default=30.0)
    parser.add_argument("--stop-seconds", type=float, default=2.0)
    parser.add_argument("--current", type=float, default=3.0)
    parser.add_argument("--accel", type=float, default=20.0)
    parser.add_argument("--velocity", type=float, default=25.0)
    parser.add_argument("--poll", type=float, default=1.0)
    args = parser.parse_args()

    build_logger()
    port = args.port or find_port(args.serial)
    logging.info("Opening %s at %s baud", port, args.baud)

    with serial.Serial(port, args.baud, timeout=0.35, write_timeout=1) as ser:
        time.sleep(0.2)
        ser.reset_input_buffer()
        try:
            stop_axis(ser, 0.5)
            configure_temporary_lockin(ser, args.current, args.accel, args.velocity)
            for prop in ("vbus_voltage", "axis0.error", "axis0.current_state", "axis0.motor.error"):
                read(ser, prop)

            spin_leg(ser, "forward", 1, args.seconds, args.poll)
            logging.info("Middle stop for %.1fs", args.stop_seconds)
            stop_axis(ser, args.stop_seconds)
            spin_leg(ser, "reverse", -1, args.seconds, args.poll)
        finally:
            logging.info("Final stop/idle")
            try:
                stop_axis(ser, 0.2)
                for prop in ("vbus_voltage", "axis0.current_state", "axis0.error", "axis0.motor.error"):
                    read(ser, prop)
            except Exception as exc:
                logging.error("Failed during final stop: %s", exc)


if __name__ == "__main__":
    main()
