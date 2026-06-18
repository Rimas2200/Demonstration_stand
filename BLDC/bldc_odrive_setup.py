import argparse
import contextlib
import io
import logging
import os
import time
from pathlib import Path

for dll_dir in (
    Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Python" / "Python311" / "Lib" / "site-packages" / "libusb" / "_platform" / "windows" / "x86_64",
    Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Python" / "Python311" / "Lib" / "site-packages" / "usb1",
):
    if dll_dir.exists():
        os.environ["PATH"] = str(dll_dir) + os.pathsep + os.environ.get("PATH", "")
        try:
            os.add_dll_directory(str(dll_dir))
        except (AttributeError, OSError):
            pass

import odrive
from odrive.enums import (
    AXIS_STATE_CLOSED_LOOP_CONTROL,
    AXIS_STATE_ENCODER_OFFSET_CALIBRATION,
    AXIS_STATE_FULL_CALIBRATION_SEQUENCE,
    AXIS_STATE_IDLE,
    AXIS_STATE_MOTOR_CALIBRATION,
    CONTROL_MODE_VELOCITY_CONTROL,
    INPUT_MODE_PASSTHROUGH,
)
from odrive.utils import dump_errors


DEFAULT_SERIAL = "375438683232"
LOG_DIR = Path("logs")


def build_logger(action):
    LOG_DIR.mkdir(exist_ok=True)
    stamp = time.strftime("%Y%m%d_%H%M%S")
    log_path = LOG_DIR / f"{stamp}_{action}.log"

    logger = logging.getLogger("bldc_odrive")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()

    fmt = logging.Formatter("%(asctime)s %(levelname)s %(message)s")
    file_handler = logging.FileHandler(log_path, encoding="utf-8")
    file_handler.setFormatter(fmt)
    stream_handler = logging.StreamHandler()
    stream_handler.setFormatter(fmt)

    logger.addHandler(file_handler)
    logger.addHandler(stream_handler)
    logger.info("Logging to %s", log_path.resolve())
    return logger, log_path


def get_path(root, dotted, default=None):
    node = root
    try:
        for part in dotted.split("."):
            node = getattr(node, part)
        return node
    except Exception:
        return default


def set_path(root, dotted, value, logger, required=False):
    node = root
    parts = dotted.split(".")
    try:
        for part in parts[:-1]:
            node = getattr(node, part)
        setattr(node, parts[-1], value)
        logger.info("set %-55s = %r", dotted, value)
        return True
    except Exception as exc:
        level = logging.ERROR if required else logging.WARNING
        logger.log(level, "skip %-54s = %r (%s)", dotted, value, exc)
        return False


def call_if_exists(root, name, logger):
    fn = getattr(root, name, None)
    if callable(fn):
        logger.info("call %s()", name)
        return fn()
    logger.warning("skip %s(): method not present", name)
    return None


def find_drive(serial, timeout, logger):
    logger.info("Finding ODrive/ODESC, serial=%s, timeout=%ss", serial or "any", timeout)
    if serial:
        return odrive.find_any(serial_number=serial, timeout=timeout)
    return odrive.find_any(timeout=timeout)


def dump_errors_to_log(odrv, logger):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        try:
            dump_errors(odrv, True)
        except TypeError:
            dump_errors(odrv)
    text = buf.getvalue().strip()
    logger.info("dump_errors:\n%s", text if text else "(no output)")


def snapshot(odrv, logger):
    logger.info("device serial_number=%s", get_path(odrv, "serial_number", "unknown"))
    fw = (
        get_path(odrv, "fw_version_major", "?"),
        get_path(odrv, "fw_version_minor", "?"),
        get_path(odrv, "fw_version_revision", "?"),
    )
    logger.info("firmware=%s.%s.%s", *fw)
    logger.info("vbus_voltage=%r V", get_path(odrv, "vbus_voltage", None))

    for axis_name in ("axis0", "axis1"):
        axis = getattr(odrv, axis_name, None)
        if axis is None:
            continue
        logger.info("%s.error=%r", axis_name, get_path(axis, "error"))
        logger.info("%s.current_state=%r", axis_name, get_path(axis, "current_state"))
        logger.info("%s.motor.error=%r", axis_name, get_path(axis, "motor.error"))
        logger.info("%s.motor.is_calibrated=%r", axis_name, get_path(axis, "motor.is_calibrated"))
        logger.info("%s.encoder.error=%r", axis_name, get_path(axis, "encoder.error"))
        logger.info("%s.encoder.is_ready=%r", axis_name, get_path(axis, "encoder.is_ready"))
        logger.info("%s.controller.error=%r", axis_name, get_path(axis, "controller.error"))
        logger.info("%s.sensorless_estimator.error=%r", axis_name, get_path(axis, "sensorless_estimator.error"))

    dump_errors_to_log(odrv, logger)


def wait_axis_idle(axis, logger, timeout=45):
    start = time.monotonic()
    while time.monotonic() - start < timeout:
        state = get_path(axis, "current_state")
        err = get_path(axis, "error", 0)
        motor_err = get_path(axis, "motor.error", 0)
        encoder_err = get_path(axis, "encoder.error", 0)
        logger.info("wait: state=%r axis.error=%r motor.error=%r encoder.error=%r", state, err, motor_err, encoder_err)
        if err or motor_err or encoder_err:
            return False
        if state == AXIS_STATE_IDLE:
            return True
        time.sleep(1)
    logger.error("timeout waiting for axis idle")
    return False


def apply_safe_config(odrv, logger):
    axis = odrv.axis0

    logger.info("Applying conservative config for 24 V / 5 A supply, unloaded motor")
    call_if_exists(odrv, "clear_errors", logger)

    # Board and supply protection. Keep values below the ODESC V4.1 VIN limit.
    set_path(odrv, "config.dc_bus_overvoltage_trip_level", 30.0, logger)
    set_path(odrv, "config.dc_bus_undervoltage_trip_level", 18.0, logger)
    set_path(odrv, "config.dc_max_positive_current", 4.0, logger)
    set_path(odrv, "config.dc_max_negative_current", -1.0, logger)
    set_path(odrv, "config.brake_resistance", 2.0, logger)
    set_path(odrv, "config.enable_brake_resistor", True, logger)

    # Motor estimate: 72 V, 6500 rpm => about 90 rpm/V => 1.5 turn/s/V.
    # Sensorless needs correct pole pairs; 4 is only the current test value.
    set_path(axis, "motor.config.pole_pairs", 4, logger, required=True)
    set_path(axis, "motor.config.torque_constant", 8.27 / 90.0, logger)
    set_path(axis, "motor.config.motor_type", 0, logger)
    set_path(axis, "motor.config.calibration_current", 3.0, logger)
    set_path(axis, "motor.config.resistance_calib_max_voltage", 4.0, logger)
    set_path(axis, "motor.config.current_lim", 4.0, logger)
    set_path(axis, "motor.config.current_lim_margin", 2.0, logger)
    set_path(axis, "motor.config.requested_current_range", 10.0, logger)

    set_path(axis, "controller.config.control_mode", CONTROL_MODE_VELOCITY_CONTROL, logger)
    set_path(axis, "controller.config.input_mode", INPUT_MODE_PASSTHROUGH, logger)
    set_path(axis, "controller.config.vel_limit", 1.0, logger)
    set_path(axis, "controller.config.vel_gain", 0.02, logger)
    set_path(axis, "controller.config.vel_integrator_gain", 0.05, logger)
    set_path(axis, "controller.input_vel", 0.0, logger)

    # Sensorless startup settings are firmware-dependent. Set what exists.
    set_path(axis, "sensorless_estimator.config.pm_flux_linkage", 5.51328895422 / (4 * 90.0), logger)
    set_path(axis, "config.startup_motor_calibration", False, logger)
    set_path(axis, "config.startup_encoder_offset_calibration", False, logger)
    set_path(axis, "config.startup_closed_loop_control", False, logger)
    set_path(axis, "config.startup_sensorless_control", False, logger)

    logger.info("Saving configuration")
    call_if_exists(odrv, "save_configuration", logger)
    logger.info("If the device reboots/disconnects here, that is normal after save_configuration().")


def calibrate(axis, logger, mode):
    if mode == "full":
        requested = AXIS_STATE_FULL_CALIBRATION_SEQUENCE
    elif mode == "motor":
        requested = AXIS_STATE_MOTOR_CALIBRATION
    elif mode == "encoder":
        requested = AXIS_STATE_ENCODER_OFFSET_CALIBRATION
    else:
        raise ValueError(mode)

    logger.info("Requesting calibration mode=%s state=%s", mode, requested)
    axis.requested_state = requested
    ok = wait_axis_idle(axis, logger)
    logger.info("calibration result=%s", "ok" if ok else "failed")
    return ok


def spin(axis, logger, velocity, seconds):
    logger.info("Preparing low-speed velocity test: input_vel=%s turns/s duration=%ss", velocity, seconds)
    axis.controller.input_vel = 0.0
    axis.requested_state = AXIS_STATE_CLOSED_LOOP_CONTROL
    time.sleep(2)
    logger.info("state after closed-loop request=%r error=%r", get_path(axis, "current_state"), get_path(axis, "error"))

    axis.controller.input_vel = velocity
    start = time.monotonic()
    while time.monotonic() - start < seconds:
        logger.info(
            "spin: t=%.1fs vbus=%r input_vel=%r encoder.vel_estimate=%r axis.error=%r motor.error=%r",
            time.monotonic() - start,
            get_path(axis, "_parent.vbus_voltage"),
            get_path(axis, "controller.input_vel"),
            get_path(axis, "encoder.vel_estimate"),
            get_path(axis, "error"),
            get_path(axis, "motor.error"),
        )
        time.sleep(0.5)

    axis.controller.input_vel = 0.0
    time.sleep(1)
    axis.requested_state = AXIS_STATE_IDLE
    logger.info("spin complete; axis requested idle")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("diagnose", "configure", "calibrate", "spin"))
    parser.add_argument("--serial", default=os.environ.get("ODRIVE_SERIAL", DEFAULT_SERIAL))
    parser.add_argument("--timeout", type=float, default=20.0)
    parser.add_argument("--calibration-mode", choices=("full", "motor", "encoder"), default="full")
    parser.add_argument("--velocity", type=float, default=0.2, help="turns/s, not rpm")
    parser.add_argument("--seconds", type=float, default=5.0)
    args = parser.parse_args()

    logger, _ = build_logger(args.action)
    odrv = find_drive(args.serial, args.timeout, logger)
    snapshot(odrv, logger)

    if args.action == "diagnose":
        return
    if args.action == "configure":
        apply_safe_config(odrv, logger)
        return

    axis = odrv.axis0
    call_if_exists(odrv, "clear_errors", logger)
    if args.action == "calibrate":
        calibrate(axis, logger, args.calibration_mode)
        snapshot(odrv, logger)
        return
    if args.action == "spin":
        spin(axis, logger, args.velocity, args.seconds)
        snapshot(odrv, logger)


if __name__ == "__main__":
    main()
