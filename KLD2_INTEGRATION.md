# K-LD2 Radar Sensor Integration

## Overview

The K-LD2 radar sensor is now fully integrated with the PRGR golf launch monitor for:
- **Club head speed measurement** (displayed in metrics)
- **Detection trigger** for camera capture (replaces ball motion detection)

## Hardware Setup

1. **Serial Connection:**
   - K-LD2 TX → Raspberry Pi RX (GPIO 15)
   - K-LD2 RX → Raspberry Pi TX (GPIO 14)
   - K-LD2 GND → Raspberry Pi GND
   - Default: `/dev/serial0` at 38400 baud

2. **Sensor Configuration:**
   - Protocol: ASCII (not Modbus)
   - Baud Rate: 38400
   - Data Bits: 8
   - Parity: None
   - Stop Bits: 1

## How It Works

### 1. Club Head Speed Display

The K-LD2 continuously polls for speed data at 20Hz:
- When swing is detected, speed is calculated and displayed
- Speed updates automatically appear in "CLUB SPEED" metric
- Real-time updates replace simulated data

### 2. Shot Capture Trigger

**OLD:** Camera detected ball movement to trigger capture
**NEW:** K-LD2 detection signal triggers capture

**Flow:**
1. Camera detects and locks onto ball
2. System waits for K-LD2 detection signal
3. When club hits ball, K-LD2 detects it instantly
4. Camera captures **15 frames before** + **15 frames after** impact
5. Replay video is created and displayed

**Advantages:**
- More reliable than camera-based detection
- Works in all lighting conditions
- Instant detection (no motion blur issues)
- Captures exact moment of impact

## Code Structure

### New Files

**`kld2_manager.py`** - K-LD2 sensor manager
- Handles serial communication with K-LD2
- Polls detection register ($R00) and speed data ($C00)
- Emits signals:
  - `speedUpdated(float)` - Club speed in mph
  - `detectionTriggered()` - Shot detected
  - `statusChanged(str, str)` - Status updates

### Modified Files

**`main.py`** - Integration with capture system
- Added K-LD2Manager instance
- Modified CaptureManager to accept K-LD2 trigger
- Added signal connections
- Changed trigger mode: `use_kld2_trigger = True`

**`main.qml`** - UI integration
- Added K-LD2 signal connections
- Speed updates automatically displayed in metrics
- Status messages logged to console

## Configuration

### Enable/Disable K-LD2 Trigger

In `main.py`, CaptureManager.__init__():

```python
# Set to True to use K-LD2, False for camera-based detection
self.use_kld2_trigger = True
```

### Adjust Polling Rate

In `kld2_manager.py`, _poll_loop():

```python
# Poll at ~20 Hz (50ms interval)
sleep_time = max(0.05 - elapsed, 0.001)  # Change 0.05 to adjust
```

### Speed Calibration

In `kld2_manager.py`, _get_speed_from_detection_string():

```python
# Adjust conversion factor based on sensor calibration
speed_mph = raw_value * 0.1  # ← Adjust this factor
```

**TODO:** Calibrate this value by comparing K-LD2 readings with known speeds.

## Testing

### Test K-LD2 Connection

Run the ASCII reader to verify K-LD2 is working:

```bash
python3 kld2_ascii_reader.py
```

Expected output:
```
K-LD2 connected - Firmware: 012E
Detection register: 00 (no detection)
```

### Test Integration

1. Start the main application
2. Go to camera capture mode
3. Click "Start Capture"
4. Check console for K-LD2 status:
   ```
   K-LD2 connected - Firmware: 012E
   K-LD2 polling started
   Ball locked - Waiting for K-LD2 detection...
   ```
5. Take a swing
6. Watch for detection:
   ```
   K-LD2 DETECTION TRIGGERED
   IMPACT DETECTED
   Capturing impact sequence...
   ```

## Troubleshooting

### K-LD2 Not Detected

**Check serial connection:**
```bash
ls -l /dev/serial0
# Should show: /dev/serial0 -> ttyAMA0
```

**Test serial port:**
```bash
python3 -c "import serial; s=serial.Serial('/dev/serial0', 38400); print('OK')"
```

**Check permissions:**
```bash
sudo usermod -a -G dialout $USER
# Log out and back in
```

### No Speed Readings

1. Check detection register:
   ```bash
   python3 kld2_ascii_reader.py
   ```
2. Verify K-LD2 is in RUN mode (state=02)
3. Check sensor is pointed at swing area
4. Adjust sensitivity settings

### Detection Not Triggering

1. Verify K-LD2 is detecting:
   - Console should show "K-LD2: X.X mph (approaching, high)"
2. Check detection register bit 0 is set (01, 03, 05, etc.)
3. Increase sensor sensitivity if needed
4. Ensure sensor is aimed correctly

## K-LD2 ASCII Protocol Reference

### Read Commands

| Command | Description | Response |
|---------|-------------|----------|
| `$F00`  | Firmware version | `@F00012E` |
| `$F01`  | Device type | `@F010001` (K-LD2) |
| `$R00`  | Detection register | `@R00XX` (hex) |
| `$R03`  | Noise level | `@R03XX` |
| `$R04`  | Operation state | `@R0402` (run mode) |
| `$C00`  | Detection string | `XXX;XXX;XXX;` |

### Detection Register Bits

```
Bit 0: Detection (0=no, 1=yes)
Bit 1: Direction (0=receding, 1=approaching)
Bit 2: Speed range (0=low, 1=high)
Bit 3: Micro detection
```

**Examples:**
- `00` = No detection
- `01` = Detection, receding, low speed
- `03` = Detection, approaching, low speed
- `07` = Detection, approaching, high speed

## Future Improvements

1. **Calibrate speed conversion factor**
   - Compare K-LD2 readings with known club speeds
   - Adjust conversion formula in `_get_speed_from_detection_string()`

2. **Add ball speed calculation**
   - Use club speed + smash factor to estimate ball speed
   - Or add second K-LD2 sensor for direct ball speed

3. **Add swing tempo analysis**
   - Track speed changes during backswing/downswing
   - Calculate tempo and transition timing

4. **Improve detection reliability**
   - Add minimum speed threshold to avoid false triggers
   - Implement detection debouncing

## Related Files

- `kld2_manager.py` - K-LD2 sensor manager
- `kld2_ascii_reader.py` - Test tool for K-LD2 ASCII protocol
- `main.py` - Main application with integration
- `main.qml` - UI with speed display

## Support

For K-LD2 datasheet and technical documentation, refer to:
- Kaise K-LD2 manual
- ASCII protocol specification
- Modbus register map (reference only)
