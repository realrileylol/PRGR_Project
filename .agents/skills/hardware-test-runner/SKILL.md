# Hardware Test Runner

Guides systematic hardware testing for the PRGR Launch Monitor, one component at a time. Produces a structured checklist with pass/fail criteria, expected outputs, and troubleshooting steps. Records results to a test log file.

## When to Use

Invoke this skill when:
- Bringing up new hardware (first-time sensor connection)
- Verifying hardware after a software change that touches sensor drivers or camera pipelines
- Debugging a sensor that stopped working
- Running a full pre-session hardware validation

## General Principles

- Test ONE component at a time. Never debug two sensors simultaneously.
- Each step has: what to do, what you should see, and what to try if it fails.
- Record every result. Intermittent failures are real failures.
- Always start with physical layer (is it plugged in?) before software layer.

## Test Log

Record results to `test_logs/hardware_test_YYYY-MM-DD_HHMMSS.log` in the project root. Create the `test_logs/` directory if it does not exist. Format each entry as:

```
[TIMESTAMP] COMPONENT | STEP | RESULT | NOTES
```

Example:
```
[2026-06-18 14:32:01] OPS243-A | Serial Connection | PASS | /dev/ttyACM0 detected
[2026-06-18 14:32:15] OPS243-A | Raw Speed Reading | FAIL | No data after 10s, check antenna orientation
```

---

## Checklist 1: OPS243-A Doppler Radar

### Step 1.1 -- Serial Connection

- **Action**: Check that the OPS243-A is enumerated as a serial device.
  ```bash
  ls /dev/ttyACM* /dev/ttyUSB*
  ```
- **Expected**: `/dev/ttyACM0` (or similar) appears.
- **Pass criteria**: Device file exists and is accessible by the current user.
- **If it fails**:
  - Check USB cable is seated fully.
  - Run `dmesg | tail -20` to see if the kernel recognized the device.
  - Check `lsusb` for the OPS243-A's USB VID/PID.
  - Verify user is in the `dialout` group: `groups $USER`.

### Step 1.2 -- Raw Speed Readings

- **Action**: Open a serial terminal and read raw output.
  ```bash
  stty -F /dev/ttyACM0 115200 raw -echo
  cat /dev/ttyACM0 &
  # Wave hand in front of sensor
  ```
  Or use `minicom -D /dev/ttyACM0 -b 115200`.
- **Expected**: Speed values printed when an object moves in front of the sensor. Format is typically a JSON-like string or comma-separated values depending on firmware configuration.
- **Pass criteria**: At least 3 readings within 10 seconds of motion in front of the sensor.
- **If it fails**:
  - Confirm baud rate (default 115200, check OPS243-A documentation).
  - Send `??` command to query module info.
  - Check antenna orientation (the flat face must point toward the target area).
  - Try power-cycling the module (unplug USB, wait 5s, replug).

### Step 1.3 -- Rolling Buffer Capture

- **Action**: Run the project's radar capture utility or Python driver to verify rolling buffer functionality.
  ```bash
  python3 radar/ops243a_capture.py --port /dev/ttyACM0 --duration 5
  ```
- **Expected**: A buffer of speed readings captured over the 5-second window, printed or saved to file.
- **Pass criteria**: Buffer contains continuous readings with no gaps > 100ms.
- **If it fails**:
  - Check for serial port contention (another process holding the port).
  - Verify Python serial library is installed: `pip3 show pyserial`.
  - Run with `--debug` flag if available to see raw bytes.

### Step 1.4 -- I/Q Data Quality

- **Action**: If the OPS243-A is configured for I/Q output, verify data quality.
  ```bash
  python3 radar/ops243a_capture.py --port /dev/ttyACM0 --mode iq --duration 5
  ```
- **Expected**: I and Q channels with consistent amplitude and 90-degree phase offset during motion.
- **Pass criteria**: I/Q amplitude ratio between 0.8 and 1.2; phase offset between 80 and 100 degrees.
- **If it fails**:
  - Send configuration command to re-enable I/Q mode: `OI` (consult OPS243-A API).
  - Check for DC offset issues (sensor too close to a reflective surface).

---

## Checklist 2: K-LD7 Radar Module

### Step 2.1 -- Serial Connection at 3 Mbaud

- **Action**: Verify the K-LD7 is connected and the serial port supports 3 Mbaud.
  ```bash
  ls /dev/ttyUSB* /dev/ttyAMA*
  stty -F /dev/ttyUSB0 3000000
  ```
- **Expected**: No error from `stty`. Device file exists.
- **Pass criteria**: `stty` completes without "invalid argument" error.
- **If it fails**:
  - Not all USB-serial adapters support 3 Mbaud. Use an FTDI-based adapter (FT232H recommended).
  - Check kernel support: `dmesg | grep -i ftdi`.
  - For Pi 5 UART (ttyAMA*), verify `/boot/firmware/config.txt` has the correct UART overlay enabled.

### Step 2.2 -- RADC Frame Streaming

- **Action**: Start reading RADC (raw ADC) frames from the K-LD7.
  ```bash
  python3 radar/kld7_capture.py --port /dev/ttyUSB0 --mode radc --frames 10
  ```
- **Expected**: 10 RADC frames captured, each containing the expected number of samples per the K-LD7 configuration.
- **Pass criteria**: All 10 frames received with consistent size and no CRC/framing errors.
- **If it fails**:
  - Verify baud rate matches K-LD7 configuration (default 3000000).
  - Check for buffer overruns: reduce frame rate or increase serial buffer size.
  - Confirm K-LD7 firmware version supports RADC output.

### Step 2.3 -- Bearing Data

- **Action**: Verify bearing/angle data is present in the radar output.
  ```bash
  python3 radar/kld7_capture.py --port /dev/ttyUSB0 --mode bearing --duration 5
  ```
- **Expected**: Bearing values reported for detected targets.
- **Pass criteria**: Bearing values are within the K-LD7's specified field of view (typically +/- 45 degrees).
- **If it fails**:
  - Confirm the K-LD7 is configured for bearing output (not all modes include it).
  - Check antenna array alignment.

### Step 2.4 -- Angle Extraction

- **Action**: Verify the software correctly extracts angle from bearing data.
  ```bash
  python3 radar/kld7_capture.py --port /dev/ttyUSB0 --mode angle --duration 5
  ```
- **Expected**: Angle values in degrees for moving targets.
- **Pass criteria**: Angles are stable (+/- 2 degrees) for a stationary-moving target at a known position.
- **If it fails**:
  - Check phase calibration data.
  - Verify antenna spacing matches the expected value in the angle calculation code.

---

## Checklist 3: Impact Camera (Camera 0 -- OV9281 + 12mm Lens)

### Step 3.1 -- rpicam-vid at 240 FPS

- **Action**: Start a high-speed capture using rpicam-vid.
  ```bash
  rpicam-vid -t 5000 --width 640 --height 480 --framerate 240 --codec yuv420 -o /tmp/impact_test.yuv --nopreview
  ```
- **Expected**: 5-second capture completes without errors. Output file is approximately `640 * 480 * 1.5 * 240 * 5 = ~553 MB` (YUV420).
- **Pass criteria**: File size is within 10% of expected. No "frame drop" or "buffer underrun" warnings in stderr.
- **If it fails**:
  - Check that the OV9281 sensor is detected: `rpicam-hello --list-cameras`.
  - Verify the CSI cable is properly seated (Camera 0 uses CSI connection).
  - Reduce to 180 FPS (the current operational mode) and retest.
  - Check `/boot/firmware/config.txt` for the camera overlay.
  - Ensure sufficient GPU memory: `vcgencmd get_mem gpu` (need at least 256MB).

### Step 3.2 -- Frame Timing Consistency

- **Action**: Analyze frame timestamps from the capture.
  ```bash
  rpicam-vid -t 2000 --width 640 --height 480 --framerate 240 --codec yuv420 -o /dev/null --nopreview --metadata /tmp/frame_metadata.json
  ```
- **Expected**: Frame intervals are consistent at ~4.17ms (1/240s).
- **Pass criteria**: No frame interval exceeds 2x the expected interval (8.33ms). Standard deviation of frame intervals < 0.5ms.
- **If it fails**:
  - Check for thermal throttling: `vcgencmd measure_temp` (should be < 80C).
  - Reduce framerate and retest.
  - Check if other processes are consuming CPU/memory.

### Step 3.3 -- Ball Detection at 5ft

- **Action**: Place a golf ball 5 feet from Camera 0 with adequate lighting. Run the ball detection pipeline.
  ```bash
  ./PRGR_Launchmonitor --test-ball-detect --camera 0
  ```
  Or use the calibration screen in the UI to visually confirm the ball is detected.
- **Expected**: Ball is detected and highlighted in the preview. Detection confidence > 0.7.
- **Pass criteria**: Ball detected in > 90% of frames over a 3-second window.
- **If it fails**:
  - Check lighting (the OV9281 is monochrome -- needs good contrast).
  - Verify the 12mm F1.2 lens is focused at the hitbox distance (7-8 ft).
  - Check that Camera 0 rotation (90 CW) is applied before detection.
  - Adjust exposure: try `--shutter` values between 1000-5000 us.

### Step 3.4 -- Exposure Validation

- **Action**: Verify exposure settings produce usable images at high FPS.
  ```bash
  rpicam-still --width 640 --height 480 --shutter 2000 --gain 2.0 -o /tmp/exposure_test.jpg --nopreview
  ```
- **Expected**: Image is neither too dark nor blown out. Golf ball is clearly visible with defined edges.
- **Pass criteria**: Ball pixels are in the 100-240 range (8-bit). Background is distinguishable from ball.
- **If it fails**:
  - Adjust shutter speed: shorter for brighter conditions, longer for darker.
  - Adjust gain: increase for low light, but keep < 8.0 to limit noise.
  - Consider adding supplemental lighting (IR-safe LED panels work well with the OV9281).

---

## Checklist 4: Combined / Cross-Sensor Tests

### Step 4.1 -- Trigger Timing (Radar to Camera Latency)

- **Action**: Measure the time between radar trigger event and first camera frame capture.
  ```bash
  ./PRGR_Launchmonitor --test-trigger-latency
  ```
- **Expected**: Latency measurement printed in milliseconds.
- **Pass criteria**: Radar-to-camera latency < 10ms. If using software trigger, < 20ms.
- **If it fails**:
  - Check for unnecessary buffering in the radar serial read path.
  - Verify the camera is in a pre-armed state (streaming but discarding frames until trigger).
  - Profile the trigger path: is the bottleneck in serial read, frame grab, or the handoff between them?

### Step 4.2 -- Cross-Sensor Time Alignment

- **Action**: Verify that radar speed data and camera frames can be correlated in time.
  ```bash
  ./PRGR_Launchmonitor --test-time-alignment --duration 5
  ```
- **Expected**: Timestamps from radar and camera are on the same clock (or have a known, stable offset).
- **Pass criteria**: Time offset between radar and camera timestamps is stable to within 2ms over the test duration.
- **If it fails**:
  - Check that both sensors use the same system clock (CLOCK_MONOTONIC recommended).
  - If using separate clocks, implement a synchronization pulse or NTP-based alignment.
  - Log raw timestamps from both sensors and look for drift.

---

## Summary Procedure

1. Start with the sensor the user wants to test, or run all checklists in order for a full validation.
2. For each step, run the action, evaluate against pass criteria, and record the result.
3. If a step fails, attempt the troubleshooting steps before moving on.
4. After all steps complete, produce a summary:

```
## Hardware Test Summary

Date: YYYY-MM-DD HH:MM
Operator: <user>

| Component      | Steps Passed | Steps Failed | Steps Skipped |
|----------------|-------------|-------------|---------------|
| OPS243-A       | 3/4         | 1/4         | 0/4           |
| K-LD7          | 4/4         | 0/4         | 0/4           |
| Impact Camera  | 3/4         | 1/4         | 0/4           |
| Combined       | 2/2         | 0/2         | 0/2           |

### Failed Steps
- OPS243-A Step 1.4: I/Q amplitude ratio 0.6, below 0.8 threshold. Check DC offset.
- Impact Camera Step 3.3: Ball detection at 72%, below 90% threshold. Lighting insufficient.

### Log File
test_logs/hardware_test_2026-06-18_143200.log
```
