# KLD2 Doppler Radar Sensor Setup for Golf Swing Monitoring

This guide explains how to use GNU Radio Companion to monitor your KLD2 Doppler radar sensor connected to Raspberry Pi GPIO pins for golf club swing detection.

## 📋 Table of Contents

- [Hardware Setup](#hardware-setup)
- [Software Installation](#software-installation)
- [Quick Start](#quick-start)
- [Usage Options](#usage-options)
- [Understanding the Display](#understanding-the-display)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

---

## 🔌 Hardware Setup

### KLD2 Sensor Wiring

The KLD2 sensor typically outputs an analog signal. To read it on the Raspberry Pi, you'll need an ADC (Analog-to-Digital Converter) like the MCP3008.

#### MCP3008 ADC Pinout to Raspberry Pi:

```
MCP3008 Pin  →  Raspberry Pi Pin
─────────────────────────────────
VDD          →  3.3V (Pin 1)
VREF         →  3.3V (Pin 1)
AGND         →  GND (Pin 6)
DGND         →  GND (Pin 6)
CLK          →  GPIO 11 (SCLK, Pin 23)
DOUT         →  GPIO 9 (MISO, Pin 21)
DIN          →  GPIO 10 (MOSI, Pin 19)
CS/SHDN      →  GPIO 8 (CE0, Pin 24)
```

#### KLD2 Sensor to MCP3008:

```
KLD2 Output  →  MCP3008 CH0 (Pin 1)
KLD2 GND     →  AGND (Pin 9)
KLD2 VCC     →  3.3V or 5V (check sensor specs)
```

### Enable SPI on Raspberry Pi

```bash
sudo raspi-config
# Navigate to: Interface Options → SPI → Enable
# Reboot: sudo reboot
```

Verify SPI is enabled:
```bash
ls /dev/spi*
# Should show: /dev/spidev0.0  /dev/spidev0.1
```

---

## 💻 Software Installation

### 1. Install System Dependencies

```bash
# Update package list
sudo apt-get update

# Install GNU Radio and dependencies
sudo apt-get install -y gnuradio \
    python3-gnuradio \
    python3-scipy \
    python3-matplotlib \
    python3-numpy \
    python3-spidev \
    python3-rpi.gpio \
    python3-pyqt5

# Install GNU Radio Qt GUI components
sudo apt-get install -y gr-qtgui
```

### 2. Install Python Packages

```bash
# Install additional Python packages
pip3 install --break-system-packages \
    spidev \
    RPi.GPIO \
    numpy \
    scipy \
    matplotlib
```

### 3. Verify Installation

```bash
# Check GNU Radio version
gnuradio-config-info --version

# Check Python imports
python3 << EOF
import gnuradio
import spidev
import RPi.GPIO as GPIO
import numpy as np
import matplotlib
print("✅ All dependencies installed successfully!")
EOF
```

---

## 🚀 Quick Start

### Test Sensor Connection (Simulation Mode)

First, test the software with simulated data:

```bash
cd /home/user/PRGR_Project

# Test the sensor module
python3 kld2_sensor.py

# Test simple monitor (matplotlib visualization)
python3 simple_kld2_monitor.py --sim

# Test GNU Radio monitor
python3 gnuradio_kld2_monitor.py --simulation
```

### Connect Real Sensor

Once hardware is connected:

```bash
# Simple monitor (easiest to use)
python3 simple_kld2_monitor.py

# GNU Radio monitor (more advanced)
python3 gnuradio_kld2_monitor.py

# Or open in GNU Radio Companion
gnuradio-companion kld2_monitor.grc
```

---

## 📊 Usage Options

### Option 1: Simple Monitor (Recommended for Beginners)

**Best for:** Quick testing and basic visualization

```bash
python3 simple_kld2_monitor.py [options]

Options:
  --sim              Use simulated data (no sensor required)
  --rate=RATE        Sample rate in Hz (default: 1000)
  --buffer=SIZE      Buffer size in samples (default: 2000)
```

**Example:**
```bash
# Monitor with 2000 Hz sample rate
python3 simple_kld2_monitor.py --rate=2000

# Simulation mode with large buffer
python3 simple_kld2_monitor.py --sim --buffer=5000
```

**Features:**
- ✅ Real-time time domain plot
- ✅ Real-time frequency domain (FFT) plot
- ✅ Automatic swing detection
- ✅ Swing speed indicators
- ✅ Easy to use

---

### Option 2: GNU Radio Monitor (Advanced)

**Best for:** Advanced signal processing and analysis

```bash
python3 gnuradio_kld2_monitor.py [options]

Options:
  --sim              Use simulated data
  --rate=RATE        Sample rate in Hz (default: 10000)
```

**Example:**
```bash
# Monitor with 5000 Hz sample rate
python3 gnuradio_kld2_monitor.py --rate=5000

# Simulation mode
python3 gnuradio_kld2_monitor.py --simulation
```

**Features:**
- ✅ Full GNU Radio signal processing capabilities
- ✅ Low-pass filtering for noise reduction
- ✅ Professional FFT visualization
- ✅ Data recording to file
- ✅ Customizable signal processing chain

---

### Option 3: GNU Radio Companion GUI

**Best for:** Custom flowgraph design and experimentation

```bash
gnuradio-companion kld2_monitor.grc
```

**Steps:**
1. Open the `.grc` file in GNU Radio Companion
2. Review the flowgraph
3. Modify blocks as needed (sample rate, filters, displays)
4. Click "Execute" (F6) to run
5. Adjust parameters in real-time

**To add real sensor source:**
1. In GNU Radio Companion, replace the "Signal Source" block
2. Add a custom Python block using `KLD2SourceBlock` from `kld2_sensor.py`
3. Connect to processing chain

---

## 📈 Understanding the Display

### Time Domain Plot

Shows the raw sensor signal over time:

- **X-axis:** Time in seconds
- **Y-axis:** Voltage (0-3.3V for Raspberry Pi)
- **Red dashed line:** Swing detection threshold

**What to look for:**
- Flat signal (~1.65V): No movement
- Oscillating signal: Club moving
- High amplitude: Fast swing

### Frequency Domain Plot (FFT)

Shows Doppler frequency components:

- **X-axis:** Frequency in Hz
- **Y-axis:** Signal magnitude/power

**What to look for:**
- **0-50 Hz:** Slow movements, body motion
- **50-200 Hz:** Club swing frequencies
- **Peak frequency:** Indicates club head speed

### Doppler Frequency to Speed Conversion

For a Doppler radar operating at frequency `f_radar`:

```
Club Speed (m/s) = (Doppler Frequency × c) / (2 × f_radar)

Where:
  c = speed of light (3×10^8 m/s)
  f_radar = KLD2 operating frequency (typically 24 GHz)
```

For KLD2 at 24 GHz:
- 100 Hz Doppler → ~0.625 m/s → ~2.25 km/h
- 1 kHz Doppler → ~6.25 m/s → ~22.5 km/h
- 10 kHz Doppler → ~62.5 m/s → ~225 km/h

---

## 🔧 Troubleshooting

### Issue: "No SPI device found"

**Solution:**
```bash
# Enable SPI
sudo raspi-config
# Interface Options → SPI → Yes

# Verify
ls /dev/spi*
```

### Issue: "Permission denied" when accessing SPI

**Solution:**
```bash
# Add user to spi group
sudo usermod -a -G spi,gpio $USER

# Or run with sudo (not recommended)
sudo python3 simple_kld2_monitor.py
```

### Issue: "No signal detected"

**Checklist:**
1. ✅ Verify sensor wiring (check connections)
2. ✅ Check sensor power (LED should be on)
3. ✅ Test with multimeter (CH0 should show ~1.65V at rest)
4. ✅ Move hand in front of sensor to test
5. ✅ Check sample rate (try lower rate like 1000 Hz)

### Issue: "Qt platform plugin error"

**Solution:**
```bash
export QT_QPA_PLATFORM=xcb
python3 gnuradio_kld2_monitor.py
```

### Issue: "GNU Radio not found"

**Solution:**
```bash
# Install GNU Radio
sudo apt-get update
sudo apt-get install -y gnuradio python3-gnuradio

# Verify
gnuradio-config-info --version
```

### Issue: Noisy signal

**Solutions:**
1. **Add shielding:** Use shielded cables for sensor
2. **Increase filtering:** Modify low-pass filter cutoff in code
3. **Add averaging:** Increase buffer size
4. **Check grounding:** Ensure all grounds connected
5. **Reduce sample rate:** Try 500-1000 Hz instead of 10000 Hz

---

## ⚙️ Advanced Configuration

### Adjust Sample Rate

Edit the Python files or pass command-line arguments:

```python
# In kld2_sensor.py
sensor = KLD2Sensor(sample_rate=5000)  # 5 kHz

# Or command line
python3 simple_kld2_monitor.py --rate=5000
```

### Adjust Swing Detection Threshold

Edit `simple_kld2_monitor.py`:

```python
# Line ~32
self.swing_threshold = 0.5  # Increase for less sensitive, decrease for more
```

### Change ADC Channel

If your sensor is on a different ADC channel:

```python
# In kld2_sensor.py, change default channel
sensor.read_voltage(channel=1)  # Use CH1 instead of CH0
```

### Record Data for Later Analysis

```bash
# GNU Radio monitor saves to file automatically
python3 gnuradio_kld2_monitor.py

# Data saved to: /tmp/kld2_sensor_data.bin

# Read back the data
python3 << EOF
import numpy as np
data = np.fromfile('/tmp/kld2_sensor_data.bin', dtype=np.float32)
print(f"Recorded {len(data)} samples")
EOF
```

### Integrate with Main App

To add KLD2 monitoring to your main Qt application:

```python
# In main.py
from kld2_sensor import KLD2Sensor

class SwingMonitor(QObject):
    swingDetected = Signal(float)  # Emit swing speed

    def __init__(self):
        super().__init__()
        self.sensor = KLD2Sensor(sample_rate=1000, simulation=False)
        # ... add monitoring logic
```

---

## 📚 Additional Resources

### KLD2 Sensor Documentation
- Operating frequency: 24 GHz (typical)
- Detection range: 5-30 meters
- Output: Analog Doppler frequency
- Power: 3.3V or 5V (check your model)

### GNU Radio Resources
- [GNU Radio Official Site](https://www.gnuradio.org/)
- [GNU Radio Tutorials](https://wiki.gnuradio.org/index.php/Tutorials)
- [GNU Radio Python API](https://www.gnuradio.org/doc/doxygen/)

### Raspberry Pi GPIO
- [GPIO Pinout](https://pinout.xyz/)
- [SPI Interface Guide](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#serial-peripheral-interface-spi)

---

## 🎯 Next Steps

1. **Calibrate sensor:**
   - Test with known swing speeds
   - Adjust thresholds and filters

2. **Integrate with main app:**
   - Add swing detection to `main.py`
   - Display club head speed in UI
   - Save swing data to history

3. **Optimize performance:**
   - Tune sample rate for accuracy vs. CPU usage
   - Add signal averaging for stability
   - Implement peak detection for max speed

4. **Add features:**
   - Club type detection (different swing patterns)
   - Tempo analysis (backswing vs. downswing)
   - Consistency tracking across swings

---

## 🆘 Getting Help

If you encounter issues:

1. Check the troubleshooting section above
2. Verify hardware connections
3. Test in simulation mode first
4. Check system logs: `dmesg | grep spi`
5. Test ADC directly with simple script

---

**Happy monitoring! 🏌️⛳**
