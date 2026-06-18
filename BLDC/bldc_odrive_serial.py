import argparse
import logging
import time
from pathlib import Path

import serial
from serial.tools import list_ports


DEFAULT_SERIAL = "375438683232"
DEFAULT_BAUD = 115200
LOG_DIR = Path("logs")


READ_PROPS = [
    "vbus_voltage",
    "fw_version_major",
    "fw_version_minor",
    "fw_version_revision",
    "axis0.error",
    "axis0.current_state",
    "axis0.motor.error",
    "axis0.motor.is_calibrated",
    "axis0.motor.config.pre_calibrated",
    "axis0.motor.config.direction",
    "axis0.motor.config.pole_pairs",
    "axis0.motor.config.motor_type",
    "axis0.motor.config.current_lim",
    "axis0.motor.config.calibration_current",
    "axis0.motor.config.resistance_calib_max_voltage",
    "axis0.motor.config.torque_constant",
    "axis0.encoder.error",
    "axis0.encoder.is_ready",
    "axis0.encoder.config.mode",
    "axis0.encoder.config.cpr",
    "axis0.controller.error",
    "axis0.controller.config.control_mode",
    "axis0.controller.config.input_mode",
    "axis0.controller.config.vel_limit",
    "axis0.controller.input_vel",
    "axis0.sensorless_estimator.error",
    "axis0.sensorless_estimator.config.pm_flux_linkage",
    "axis0.config.startup_sensorless_control",
    "axis0.config.startup_motor_calibration",
    "config.dc_bus_overvoltage_trip_level",
    "config.dc_bus_undervoltage_trip_level",
    "config.dc_max_positive_current",
    "config.dc_max_negative_current",
    "config.brake_resistance",
    "config.enable_brake_resistor",
]


SAFE_CONFIG = [
    ("config.dc_bus_overvoltage_trip_level", 30.0),
    ("config.dc_bus_undervoltage_trip_level", 18.0),
    ("config.dc_max_positive_current", 4.0),
    ("config.dc_max_negative_current", -1.0),
    ("config.brake_resistance", 2.0),
    ("config.enable_brake_resistor", 1),
    ("axis0.motor.config.motor_type", 0),
    ("axis0.motor.config.pole_pairs", 4),
    ("axis0.motor.config.calibration_current", 3.0),
    ("axis0.motor.config.resistance_calib_max_voltage", 4.0),
    ("axis0.motor.config.current_lim", 4.0),
    ("axis0.motor.config.current_lim_margin", 2.0),
    ("axis0.motor.config.requested_current_range", 10.0),
    ("axis0.motor.config.torque_constant", 8.27 / 90.0),
    ("axis0.controller.config.control_mode", 2),
    ("axis0.controller.config.input_mode", 1),
    ("axis0.controller.config.vel_limit", 1.0),
    ("axis0.controller.config.vel_gain", 0.02),
    ("axis0.controller.config.vel_integrator_gain", 0.05),
    ("axis0.controller.input_vel", 0.0),
    ("axis0.sensorless_estimator.config.pm_flux_linkage", 5.51328895422 / (4 * 90.0)),
    ("axis0.config.general_lockin.current", 2.0),
    ("axis0.config.general_lockin.accel", 5.0),
    ("axis0.config.general_lockin.vel", 10.0),
    ("axis0.config.sensorless_ramp.current", 2.0),
    ("axis0.config.sensorless_ramp.accel", 20.0),
    ("axis0.config.sensorless_ramp.vel", 40.0),
    ("axis0.config.startup_motor_calibration", 0),
    ("axis0.config.startup_encoder_offset_calibration", 0),
    ("axis0.config.startup_closed_loop_control", 0),
    ("axis0.config.startup_sensorless_control", 0),
]


def build_logger(action):
    LOG_DIR.mkdir(exist_ok=True)
    stamp = time.strftime("%Y%m%d_%H%M%S")
    path = LOG_DIR / f"{stamp}_serial_{action}.log"
    logger = logging.getLogger("bldc_odrive_serial")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()
    fmt = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
    for handler in (logging.FileHandler(path, encoding="utf-8"), logging.StreamHandler()):
        handler.setFormatter(fmt)
        logger.addHandler(handler)
    logger.info("Logging to %s", path.resolve())
    return logger


def find_port(serial_hint):
    candidates = []
    for port in list_ports.comports():
        if "1209:0D32" in port.hwid.upper() or "ODRIVE" in port.description.upper():
            candidates.append(port)
    if serial_hint:
        for port in candidates:
            if serial_hint in port.hwid:
                return port.device
    if candidates:
        return candidates[0].device
    raise RuntimeError("ODrive CDC COM port not found")


class ODriveAscii:
    def __init__(self, port, baud, logger):
        self.logger = logger
        self.ser = serial.Serial(port, baud, timeout=0.35, write_timeout=1)
        time.sleep(0.2)
        self.ser.reset_input_buffer()
        self.logger.info("Opened %s at %s baud", port, baud)

    def close(self):
        self.ser.close()

    def cmd(self, text, expect_reply=False):
        self.logger.info("> %s", text)
        self.ser.write((text + "\n").encode("ascii"))
        self.ser.flush()
        if expect_reply:
            reply = self.ser.readline().decode("ascii", errors="replace").strip()
            self.logger.info("< %s", reply)
            return reply
        time.sleep(0.04)
        replies = []
        while self.ser.in_waiting:
            replies.append(self.ser.readline().decode("ascii", errors="replace").strip())
        if replies:
            self.logger.info("< %s", " | ".join(replies))
        return None

    def read(self, prop):
        return self.cmd(f"r {prop}", expect_reply=True)

    def write(self, prop, value):
        self.cmd(f"w {prop} {value}", expect_reply=False)
        check = self.read(prop)
        if check == "invalid property":
            self.logger.warning("property not accepted: %s", prop)
        return check

    def snapshot(self):
        for prop in READ_PROPS:
            self.read(prop)


def configure(dev, logger, save):
    logger.info("Applying conservative non-motion config for 24 V / 5 A supply")
    dev.cmd("w axis0.requested_state 1")
    dev.cmd("w axis0.controller.input_vel 0")
    for prop, value in SAFE_CONFIG:
        dev.write(prop, value)
    if save:
        logger.info("Saving configuration with ASCII command 'ss'")
        dev.cmd("ss")
        time.sleep(2)


def wait_idle(dev, logger, timeout=40):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        state = dev.read("axis0.current_state")
        axis_error = dev.read("axis0.error")
        motor_error = dev.read("axis0.motor.error")
        encoder_error = dev.read("axis0.encoder.error")
        logger.info("wait state=%s axis=%s motor=%s encoder=%s", state, axis_error, motor_error, encoder_error)
        if not str(axis_error).startswith("0") or not str(motor_error).startswith("0") or not str(encoder_error).startswith("0"):
            return False
        if state == "1":
            return True
        time.sleep(1)
    return False


def calibrate_motor(dev, logger):
    logger.info("Requesting motor calibration only. This may twitch/lock the shaft.")
    dev.cmd("w axis0.requested_state 4")
    return wait_idle(dev, logger)


def spin_lockin(dev, logger, seconds):
    logger.info("Requesting LOCKIN_SPIN for %.1fs with conservative lockin settings", seconds)
    dev.cmd("w axis0.controller.input_vel 0")
    dev.cmd("w axis0.requested_state 1")
    dev.write("axis0.motor.config.pre_calibrated", 1)
    dev.write("axis0.motor.config.direction", 1)
    time.sleep(0.5)
    dev.cmd("w axis0.requested_state 9")
    start = time.monotonic()
    while time.monotonic() - start < seconds:
        logger.info("lockin t=%.1fs", time.monotonic() - start)
        for prop in ("vbus_voltage", "axis0.current_state", "axis0.error", "axis0.motor.error", "axis0.encoder.error"):
            dev.read(prop)
        time.sleep(0.25)
    dev.cmd("w axis0.requested_state 1")
    time.sleep(0.5)
    logger.info("LOCKIN_SPIN complete; axis requested idle")


def spin_sensorless_startup(dev, logger, velocity, seconds):
    logger.info("Requesting STARTUP_SEQUENCE with temporary sensorless startup for %.1fs", seconds)
    dev.cmd("w axis0.controller.input_vel 0")
    dev.cmd("w axis0.requested_state 1")
    time.sleep(0.5)
    volatile_settings = [
        ("axis0.config.sensorless_ramp.current", 1.5),
        ("axis0.config.sensorless_ramp.accel", 10.0),
        ("axis0.config.sensorless_ramp.vel", 20.0),
        ("axis0.config.general_lockin.current", 1.5),
        ("axis0.config.general_lockin.accel", 3.0),
        ("axis0.config.general_lockin.vel", 6.0),
        ("axis0.controller.input_vel", velocity),
        ("axis0.config.startup_sensorless_control", 1),
    ]
    for prop, value in volatile_settings:
        dev.write(prop, value)
    dev.cmd("w axis0.requested_state 2")
    start = time.monotonic()
    try:
        while time.monotonic() - start < seconds:
            logger.info("sensorless startup t=%.1fs", time.monotonic() - start)
            for prop in (
                "vbus_voltage",
                "axis0.current_state",
                "axis0.error",
                "axis0.motor.error",
                "axis0.encoder.error",
                "axis0.sensorless_estimator.error",
                "axis0.sensorless_estimator.vel_estimate",
            ):
                dev.read(prop)
            time.sleep(0.25)
    finally:
        dev.cmd("w axis0.controller.input_vel 0")
        dev.cmd("w axis0.requested_state 1")
        dev.cmd("w axis0.config.startup_sensorless_control 0")
        logger.info("Sensorless startup attempt complete; axis requested idle and startup flag reset")


def spin_closed_loop(dev, logger, velocity, seconds):
    logger.info("Requesting CLOSED_LOOP_CONTROL, velocity %.3f turns/s for %.1fs", velocity, seconds)
    dev.cmd("w axis0.controller.input_vel 0")
    dev.cmd("w axis0.requested_state 8")
    time.sleep(2)
    dev.read("axis0.current_state")
    dev.read("axis0.error")
    dev.cmd(f"w axis0.controller.input_vel {velocity}")
    start = time.monotonic()
    while time.monotonic() - start < seconds:
        logger.info("spin t=%.1fs", time.monotonic() - start)
        for prop in ("vbus_voltage", "axis0.current_state", "axis0.error", "axis0.motor.error", "axis0.encoder.error", "axis0.encoder.vel_estimate"):
            dev.read(prop)
        time.sleep(0.5)
    dev.cmd("w axis0.controller.input_vel 0")
    time.sleep(1)
    dev.cmd("w axis0.requested_state 1")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("diagnose", "configure", "calibrate-motor", "spin-lockin", "spin-sensorless-startup", "spin-closed-loop"))
    parser.add_argument("--port")
    parser.add_argument("--serial", default=DEFAULT_SERIAL)
    parser.add_argument("--baud", type=int, default=DEFAULT_BAUD)
    parser.add_argument("--save", action="store_true")
    parser.add_argument("--velocity", type=float, default=0.2)
    parser.add_argument("--seconds", type=float, default=5.0)
    args = parser.parse_args()

    logger = build_logger(args.action)
    port = args.port or find_port(args.serial)
    dev = ODriveAscii(port, args.baud, logger)
    try:
        dev.snapshot()
        if args.action == "configure":
            configure(dev, logger, args.save)
            dev.snapshot()
        elif args.action == "calibrate-motor":
            ok = calibrate_motor(dev, logger)
            logger.info("motor calibration result=%s", "ok" if ok else "failed")
            dev.snapshot()
        elif args.action == "spin-lockin":
            spin_lockin(dev, logger, args.seconds)
            dev.snapshot()
        elif args.action == "spin-sensorless-startup":
            spin_sensorless_startup(dev, logger, args.velocity, args.seconds)
            dev.snapshot()
        elif args.action == "spin-closed-loop":
            spin_closed_loop(dev, logger, args.velocity, args.seconds)
            dev.snapshot()
    finally:
        dev.close()


if __name__ == "__main__":
    main()
