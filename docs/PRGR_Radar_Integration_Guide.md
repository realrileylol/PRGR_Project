# PRGR Launch Monitor — Radar Integration Guide
## From OpenFlight Radars to Your C++ Project (Start to Finish)

---

## Table of Contents
1. Parts List & What to Order
2. 3D Printed Enclosure — Bottom Half (Radar Mounts)
3. Wiring Everything Up
4. Testing Each Radar in Python (OpenFlight's Way)
5. Porting to C++ (Your Way) — Terminal Tests
6. Qt Integration — Radar Data in Your QML GUI
7. Spin Detection — FFT Signal Processing
8. Sensor Fusion — Camera + Radar
9. Replay Recording

---

## 1. Parts List & What to Order

| Part | Purpose | Approx Cost | Where to Buy | Notes |
|------|---------|-------------|--------------|-------|
| OPS243-A Doppler Radar | Ball speed, club speed, spin via I/Q | ~$249 | OmniPreSense website | **Do NOT buy the OPS243-A-W (WiFi version)** — its serial baud rate is too slow for I/Q data |
| K-LD7 Radar Module #1 | Vertical launch angle | ~$60 | RFbeam / Mouser / Digikey | K-LD7 EVAL board version |
| K-LD7 Radar Module #2 | Horizontal club path | ~$60 | Same as above | Second identical unit |
| 3.3V FTDI USB-Serial Adapter x2 | Connect K-LD7s to Pi | ~$20 total | Amazon / SparkFun | **MUST be 3.3V, not 5V** — 5V will damage the K-LD7 |
| SparkFun SEN-14262 Sound Detector | Impact trigger for rolling buffer | ~$12 | SparkFun | Requires soldering a 47kΩ resistor (R17) before use |
| 47kΩ Through-Hole Resistor | Reduces preamp gain on SEN-14262 for 3.3V operation | ~$1 | Any electronics supplier | If GATE LED stays lit without sound, try a lower value |
| USB cable for OPS243-A | Connect OPS243 to Pi USB port | ~$5 | Amazon | Standard USB-A to Micro-B |
| Jumper wires | Connect sound trigger to Pi GPIO + OPS243 HOST_INT | ~$5 | Amazon / SparkFun | Female-to-female recommended |
| **Total** | | **~$412** | | You already have: Pi 5, touchscreen, impact camera |

### What You Already Have (from your PRGR build)
- Raspberry Pi 5 (4GB+)
- 7" touchscreen display
- OV9281 impact camera (CSI, with 8mm F1.4 lens incoming)
- Power supply
- MicroSD card with your existing PRGR project

---

## 2. 3D Printed Enclosure — Bottom Half (Radar Mounts Only)

### CAD Files from OpenFlight
The printable enclosure files are in the OpenFlight repo at:
```
cad/printable-enclosure/launchmonitorbox.zip
```

Download this ZIP. It contains the full enclosure. **You only need to print the bottom half** — the base plate and radar mounting brackets.

Additionally, the repo has STEP files for the radar modules themselves (for reference/fitment):
- `cad/OPS243.stp` — OPS243 radar 3D model
- `cad/K-LD7-RFB.step` — K-LD7 radar 3D model
- `cad/OPS243 Design Drawing.pdf` — Dimensions reference

### What to Print (Bottom Half Only)
From the ZIP, identify and print:
1. **Base plate** — the flat bottom that everything mounts to
2. **OPS243 mount bracket** — holds the main radar centered
3. **K-LD7 mount brackets (x2)** — one for vertical (launch angle), one for horizontal (club path)

### Your Modifications
You'll need to modify the center section to add a **taller tower/post** for your impact camera. The camera needs to be:
- Centered between the radars
- Rotated 90° CW (portrait orientation)
- At the same height as the radars (pointing down the target line)
- The OV9281 module is small (~38mm x 38mm) so the mount can be compact

**Skip printing for now:**
- Top half / screen enclosure (you'll design your own later)
- Any branding/logo pieces
- Lid or cover pieces

### Radar Positioning
All sensors point at the same target — the ball/hitting zone:
- **OPS243-A**: Center, pointing straight down the target line
- **K-LD7 #1 (vertical)**: Mounted to measure vertical angle (launch angle). Position 3-5 feet behind the tee.
- **K-LD7 #2 (horizontal)**: Mounted to measure horizontal angle (club path/aim). Same distance.
- **Impact camera**: Center, same direction as OPS243

---

## 3. Wiring Everything Up

### 3A. OPS243-A Radar
**Connection: USB cable to Pi**

This is the simplest — just plug the USB cable from the OPS243-A into any USB port on the Pi 5. It shows up as a serial device at `/dev/ttyACM0` (or similar).

Verify it's detected:
```bash
ls /dev/ttyACM*
# Should show: /dev/ttyACM0
```

### 3B. K-LD7 Radars (via FTDI Adapters)
**Connection: 3.3V FTDI adapter → USB 3.0 ports on Pi**

Each K-LD7 connects to a separate FTDI adapter. Critical rules:

1. **Use USB 3.0 ports only** — USB 2.0 causes packet errors at 3Mbaud
2. **Use DIFFERENT USB controllers** — The Pi 5 has two xHCI controllers. Plug one FTDI into each. If both are on the same controller, one radar will drop frames.
3. **Set different frequencies** — Vertical uses RBFR=0 (24.05 GHz), horizontal uses RBFR=2 (24.25 GHz) to avoid interference

Check which USB controller each is on:
```bash
ls -l /dev/serial/by-path/
# Look for platform-xhci-hcd.0 and platform-xhci-hcd.1
# The two K-LD7s should have DIFFERENT numbers
```

### Create Stable Device Names (udev Rules)
Without this, the K-LD7s could swap ports after a reboot.

Find each FTDI adapter's serial number:
```bash
udevadm info -a -n /dev/ttyUSB0 | grep serial
udevadm info -a -n /dev/ttyUSB1 | grep serial
```

Create udev rules:
```bash
sudo nano /etc/udev/rules.d/99-kld7.rules
```

Add (replace SERIAL_NUMBER_1 and SERIAL_NUMBER_2 with your actual serial numbers):
```
SUBSYSTEM=="tty", ATTRS{serial}=="SERIAL_NUMBER_1", SYMLINK+="kld7_vertical"
SUBSYSTEM=="tty", ATTRS{serial}=="SERIAL_NUMBER_2", SYMLINK+="kld7_horizontal"
```

Reload:
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
ls /dev/kld7_*
# Should show: /dev/kld7_vertical  /dev/kld7_horizontal
```

### 3C. Sound Trigger (SEN-14262)
**Connection: 3 wires — Power, Ground, Signal**

**BEFORE WIRING — Solder R17:**
The SEN-14262 needs a 47kΩ resistor soldered onto the R17 pad on the board. This reduces the preamp gain so it works properly at 3.3V instead of 5V. Without this, the GATE output will be stuck HIGH all the time.

**Wiring (3 connections):**

| SEN-14262 Pin | Connects To | Wire Color |
|---------------|-------------|------------|
| VCC | Pi GPIO Pin 1 (3.3V) | Red |
| GND | Pi GPIO Pin 6 (Ground) | Black |
| GATE | OPS243-A J3 Pin 3 (HOST_INT) | Yellow/White |

**Also connect grounds together:**
- Pi GND, SEN-14262 GND, and OPS243-A GND must all be connected (common ground)

**How it works:**
When the microphone hears the impact "click," the GATE pin goes HIGH for a brief moment. This signal goes directly to the OPS243-A's HOST_INT pin, which triggers the radar to dump its rolling buffer. Near-zero latency (~10 microseconds).

---

## 4. Testing Each Radar in Python (OpenFlight's Way)

This step confirms your wiring works BEFORE you write any C++ code. You'll use OpenFlight's Python scripts temporarily.

### 4A. Install OpenFlight's Python Environment

```bash
# Clone OpenFlight repo (temporary, just for testing)
cd ~
git clone https://github.com/jewbetcha/openflight.git
cd openflight

# Install Python dependencies
pip install uv  # if not installed
uv sync

# Or manually:
python3 -m venv .venv
source .venv/bin/activate
pip install pyserial numpy
```

### 4B. Test OPS243-A (Ball Speed)

**Step 1: Verify serial connection**
```bash
ls /dev/ttyACM*
# Should show your OPS243-A
```

**Step 2: Run basic speed test**
```bash
# From the openflight directory
source .venv/bin/activate
python -c "
import serial, json
ser = serial.Serial('/dev/ttyACM0', 115200, timeout=1)
ser.write(b'OF\r')  # Enable JSON output
ser.write(b'US\r')  # Units: mph
print('Wave your hand in front of the radar...')
while True:
    line = ser.readline().decode('utf-8', errors='ignore').strip()
    if line and '{' in line:
        try:
            data = json.loads(line)
            if 'speed' in data:
                print(f'Speed: {data[\"speed\"]} mph')
        except json.JSONDecodeError:
            pass
"
```

**What to expect:** Wave your hand in front of the radar. You should see speed readings in the terminal (probably 1-5 mph for a hand wave). If you see numbers, the radar works.

**Step 3: Test rolling buffer mode (for spin)**
```bash
cd ~/openflight
source .venv/bin/activate

# First time setup (saves rolling buffer config to radar's persistent memory)
uv run python scripts/hardware-test/test_rolling_buffer_persist.py --setup

# IMPORTANT: Unplug and replug the OPS243-A (power cycle)

# Then verify it works
uv run python scripts/hardware-test/test_rolling_buffer_persist.py --test
```

**What to expect:** When you clap near the sound trigger, you should see "Buffer captured: 4096 I samples, 4096 Q samples" in the terminal.

### 4C. Test K-LD7 #1 (Vertical / Launch Angle)

```bash
# Verify device exists
ls /dev/kld7_vertical
# Should exist from your udev rules

# Quick serial test
python -c "
import serial
ser = serial.Serial('/dev/kld7_vertical', 115200, timeout=2)
ser.write(b'GNFD\r\n')  # Query firmware version
response = ser.readline()
print(f'K-LD7 vertical response: {response}')
"
```

**What to expect:** You should get a firmware version string back. If you get nothing or garbage, check your FTDI adapter and wiring.

### 4D. Test K-LD7 #2 (Horizontal / Club Path)

```bash
# Same test for horizontal
python -c "
import serial
ser = serial.Serial('/dev/kld7_horizontal', 115200, timeout=2)
ser.write(b'GNFD\r\n')
response = ser.readline()
print(f'K-LD7 horizontal response: {response}')
"
```

### 4E. Test Sound Trigger

```bash
# Visual test first:
# Clap your hands near the SEN-14262
# The GATE LED on the board should flash briefly
# If the LED is always ON: your R17 resistor value is too high, try 33kΩ or 22kΩ
# If the LED never lights: check your 3.3V power and ground connections

# Software test (if OpenFlight has the script):
cd ~/openflight
source .venv/bin/activate
uv run python scripts/hardware-test/test_sound_trigger.py
```

**What to expect:** Clap → LED flashes → terminal shows "Trigger detected"

### 4F. Full Integration Test (Python)

Run OpenFlight's server in mock-free mode to test all hardware together:
```bash
cd ~/openflight
source .venv/bin/activate
./scripts/start-kiosk.sh
```

Hit a ball (or clap + wave hand). You should see shot data on their React UI at `http://localhost:8080`. This confirms ALL hardware works together before you touch any C++ code.

**Once all tests pass, you're done with Python. You can delete the OpenFlight clone if you want — from here on, everything is C++.**

---

## 5. Porting to C++ — Terminal Tests

Now you build C++ drivers for each radar that integrate into your PRGR project. Each one starts as a standalone terminal test program, then gets wrapped into a Qt class.

### 5A. OPS243-A Driver (Ball Speed)

**File: `src/OPS243Driver.cpp` + `include/OPS243Driver.h`**

The OPS243-A communicates over serial at 115200 baud and sends JSON lines. The C++ driver needs to:
1. Open `/dev/ttyACM0` as a serial port
2. Send configuration commands (`OF` for JSON, `US` for mph units)
3. Read lines, parse JSON for speed readings
4. Detect ball speed vs club speed (ball is faster, comes after club)

**Terminal test program: `tests/test_ops243.cpp`**
```cpp
// Pseudocode structure — I'll write the real code when your hardware arrives

#include <iostream>
#include <string>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>

// 1. Open serial port /dev/ttyACM0 at 115200 baud
// 2. Send "OF\r" to enable JSON output
// 3. Send "US\r" to set units to mph
// 4. Loop: read lines, parse JSON, print speed

int main() {
    // Open serial port
    int fd = open("/dev/ttyACM0", O_RDWR | O_NOCTTY);
    // Configure: 115200 baud, 8N1
    struct termios tty;
    tcgetattr(fd, &tty);
    cfsetospeed(&tty, B115200);
    cfsetispeed(&tty, B115200);
    // ... standard serial config ...
    tcsetattr(fd, TCSANOW, &tty);

    // Send config commands
    write(fd, "OF\r", 3);  // JSON output
    write(fd, "US\r", 3);  // mph units

    // Read loop
    char buf[256];
    while (true) {
        int n = read(fd, buf, sizeof(buf) - 1);
        if (n > 0) {
            buf[n] = '\0';
            // Parse JSON, extract "speed" field
            // Print: "Ball speed: 142.3 mph"
            std::cout << "Raw: " << buf << std::endl;
        }
    }

    close(fd);
    return 0;
}
```

**Build and test:**
```bash
cd ~/PRGR_Project/build
g++ -o test_ops243 ../tests/test_ops243.cpp -std=c++17
./test_ops243
# Wave hand → see speed readings
```

**What to expect:** Same numbers you saw in the Python test, but now from your C++ code.

### 5B. K-LD7 Driver (Launch Angle)

**File: `src/KLD7Driver.cpp` + `include/KLD7Driver.h`**

The K-LD7 communicates via FTDI at high baud (3Mbaud for RADC streaming). The driver needs to:
1. Open `/dev/kld7_vertical` (and `/dev/kld7_horizontal`)
2. Configure radar parameters (frequency band, detection mode)
3. Stream RADC frames and parse target data (distance, speed, angle, magnitude)
4. Apply the burst detection algorithm (find the ball among body/club/net returns)

**Terminal test: `tests/test_kld7.cpp`**
```cpp
// Pseudocode — real implementation when hardware arrives

// 1. Open /dev/kld7_vertical at 3000000 baud (3Mbaud)
// 2. Send initialization commands
// 3. Read RADC frames
// 4. Parse target data (PDAT: distance, speed, angle, magnitude)
// 5. Print targets as they arrive

int main() {
    // Open serial at 3Mbaud
    // Configure K-LD7
    // Stream and print target data
    // "Target: dist=4.2m, speed=45km/h, angle=16.3°, mag=0.72"
}
```

**Build and test:**
```bash
g++ -o test_kld7 ../tests/test_kld7.cpp -std=c++17
./test_kld7
# Wave hand or swing club → see angle/distance readings
```

### 5C. Sound Trigger (GPIO)

If using the direct hardware trigger (SEN-14262 → OPS243 HOST_INT), the Pi doesn't need to do anything for the trigger itself — it's a direct electrical connection. The Pi just needs to know when the OPS243 has data ready.

However, if you want the Pi to also know about the trigger event (for timing the impact camera), you can read the GATE signal on a GPIO pin:

**File: `src/SoundTrigger.cpp` + `include/SoundTrigger.h`**
```cpp
// Read GPIO pin for impact timestamp
// This tells your CaptureManager "impact happened NOW, save the replay buffer"
```

---

## 6. Qt Integration — Radar Data in Your QML GUI

Once the terminal tests work, wrap each driver in a QObject class.

### 6A. OPS243 Qt Wrapper

**File: `include/OPS243Manager.h`**
```cpp
class OPS243Manager : public QObject {
    Q_OBJECT
    Q_PROPERTY(double ballSpeed READ ballSpeed NOTIFY ballSpeedChanged)
    Q_PROPERTY(double clubSpeed READ clubSpeed NOTIFY clubSpeedChanged)
    Q_PROPERTY(double spinRpm READ spinRpm NOTIFY spinRpmChanged)
    Q_PROPERTY(double spinConfidence READ spinConfidence NOTIFY spinConfidenceChanged)

public:
    explicit OPS243Manager(QObject *parent = nullptr);

    double ballSpeed() const;
    double clubSpeed() const;
    double spinRpm() const;
    double spinConfidence() const;

    Q_INVOKABLE void startListening();
    Q_INVOKABLE void stopListening();

signals:
    void ballSpeedChanged();
    void clubSpeedChanged();
    void spinRpmChanged();
    void spinConfidenceChanged();
    void shotDetected();  // Fires when a complete shot is captured

private:
    // Serial port reading on a background thread
    // JSON parsing
    // Rolling buffer processing for spin
};
```

### 6B. K-LD7 Qt Wrapper

**File: `include/KLD7Manager.h`**
```cpp
class KLD7Manager : public QObject {
    Q_OBJECT
    Q_PROPERTY(double launchAngle READ launchAngle NOTIFY launchAngleChanged)
    Q_PROPERTY(double clubPath READ clubPath NOTIFY clubPathChanged)
    Q_PROPERTY(double angleConfidence READ angleConfidence NOTIFY angleConfidenceChanged)

public:
    // ... same pattern as OPS243Manager
};
```

### 6C. Register with QML (in main.cpp)

```cpp
// In your main.cpp, alongside existing registrations:
OPS243Manager ops243Manager;
KLD7Manager kld7Manager;

engine.rootContext()->setContextProperty("radarManager", &ops243Manager);
engine.rootContext()->setContextProperty("angleManager", &kld7Manager);
```

### 6D. Your QML Metrics Just Work

Your existing `AppWindow.qml` metrics already display club speed, ball speed, spin, launch angle. Instead of simulated values, they now read from the radar:

```qml
// In orderedMetrics, the getValue functions change from:
{ id: "clubSpeed", getValue: function() { return win.clubSpeed.toFixed(1) } }

// The win.clubSpeed property gets set by the radar manager
// instead of the simulate button — everything else stays the same
```

The SIMULATE SHOT button can remain as a fallback for testing without hardware.

---

## 7. Spin Detection — FFT Signal Processing (C++ Port)

This is the most complex part. Here's how OpenFlight's spin detection works, translated to C++:

### How Radar Spin Detection Works (The Theory)

1. The OPS243-A captures 4096 raw I/Q samples (~136ms of data at 30ksps)
2. Standard FFT on 128-sample blocks gives you **ball speed** over time
3. The ball's dimpled surface causes tiny speed oscillations as it spins
4. A SECOND FFT on those speed oscillations extracts the **spin frequency**
5. Spin RPM = frequency × 60

### The Signal Processing Pipeline in C++

```cpp
// Step 1: Parse the I/Q buffer (4096 samples each)
std::vector<double> iData(4096), qData(4096);
// ... parse from OPS243 serial response ...

// Step 2: Overlapping FFT for high-resolution speed timeline
const int WINDOW_SIZE = 128;
const int FFT_SIZE = 4096;
const int STEP_SIZE = 32;  // 4x overlap for ~937 Hz speed sampling
const double SAMPLE_RATE = 30000.0;

std::vector<double> speedTimeline;

for (int start = 0; start + WINDOW_SIZE <= 4096; start += STEP_SIZE) {
    // Extract window
    std::vector<double> iBlock(iData.begin() + start, iData.begin() + start + WINDOW_SIZE);
    std::vector<double> qBlock(qData.begin() + start, qData.begin() + start + WINDOW_SIZE);

    // Remove DC offset
    double iMean = accumulate(iBlock) / WINDOW_SIZE;
    double qMean = accumulate(qBlock) / WINDOW_SIZE;
    for (auto& v : iBlock) v -= iMean;
    for (auto& v : qBlock) v -= qMean;

    // Apply Hanning window
    for (int i = 0; i < WINDOW_SIZE; i++) {
        double w = 0.5 * (1.0 - cos(2.0 * M_PI * i / WINDOW_SIZE));
        iBlock[i] *= w;
        qBlock[i] *= w;
    }

    // FFT (using OpenCV's cv::dft or FFTW)
    // Find peak bin → convert to speed in mph
    double speed = peakBinToSpeed(iBlock, qBlock, FFT_SIZE, SAMPLE_RATE);
    speedTimeline.push_back(speed);
}

// Step 3: Extract spin from speed oscillations
// Remove the average speed (DC component)
double avgSpeed = mean(speedTimeline);
std::vector<double> detrended(speedTimeline.size());
for (size_t i = 0; i < speedTimeline.size(); i++)
    detrended[i] = speedTimeline[i] - avgSpeed;

// FFT on the detrended speed signal
// The timeline sample rate is ~937.5 Hz (30000 / 32)
double timelineSampleRate = SAMPLE_RATE / STEP_SIZE;

// Find peak frequency in the spin range (30-200 Hz = 1800-12000 RPM)
// cv::dft(detrended, spinSpectrum);
double spinHz = findPeakInRange(spinSpectrum, 30.0, 200.0, timelineSampleRate);
double spinRpm = spinHz * 60.0;

// Step 4: Quality assessment
double snr = peakMagnitude / noiseFloor;
bool isReliable = (snr > 3.0) && (spinRpm > 1000) && (spinRpm < 10000);
```

### Expected Results
- **50-60% of shots** will produce a clear spin signal
- Good shots: clean sinusoidal pattern in the detrended speed, SNR > 3.0
- Bad shots: noisy/sloppy signal, low SNR, spin value unreliable
- This is the same success rate OpenFlight reports — it's a hardware limitation of the OPS243-A

---

## 8. Sensor Fusion — Camera + Radar

### The Priority Chain

```
Spin source priority:
1. Camera spin (high confidence) → USE THIS
2. Camera spin (low confidence) + Radar spin → CROSS-VALIDATE
3. Radar spin only (high SNR) → USE THIS
4. Radar spin only (low SNR) → SHOW WITH WARNING
5. Neither → ESTIMATE from club type + ball speed (TrackMan tables)

Launch angle priority:
1. K-LD7 radar (high confidence) → USE THIS
2. Camera trajectory (if trajectory cam exists) → USE THIS
3. K-LD7 radar (low confidence) → SHOW WITH WARNING
4. Neither → ESTIMATE from club type + ball speed

Ball speed:
1. OPS243-A radar → ALWAYS USE (most accurate sensor for speed)
```

### Implementation

**File: `src/SensorFusion.cpp`**
```cpp
struct FusedShot {
    double ballSpeedMph;       // From OPS243 (always)
    double clubSpeedMph;       // From OPS243
    double smashFactor;        // Calculated
    double launchAngleDeg;     // From K-LD7 or estimate
    double clubPathDeg;        // From K-LD7 or estimate
    double spinRpm;            // From camera, radar, or estimate
    double spinConfidence;     // 0.0 to 1.0
    std::string spinSource;    // "camera", "radar", "fused", "estimated"
    double carryYards;         // Calculated from all the above
    double totalYards;         // Carry + roll estimate
};
```

---

## 9. Replay Recording

When the sound trigger fires (impact detected):

1. **Impact cam**: Save the last 2-3 seconds of frames from your rolling frame buffer as an MP4
2. Store in `shot_replays/shot_XXX/impact.mp4`
3. Link the replay to the shot in HistoryManager
4. In your History screen, add a "Replay" button for each shot

Your CaptureManager already has frame buffering infrastructure. The trigger just changes from the ball-zone state machine to the sound trigger GPIO signal.

---

## Build Order Summary

| Step | What You Do | What It Gives You |
|------|-------------|-------------------|
| 1 | Order parts | Hardware on the way |
| 2 | Print bottom half enclosure | Radar mounts ready |
| 3 | Wire OPS243-A (USB) | Simplest connection |
| 4 | Test OPS243 in Python | Confirm ball speed works |
| 5 | Write OPS243Driver.cpp | Ball speed in C++ terminal |
| 6 | Wire K-LD7s (FTDI + udev) | Angle radars connected |
| 7 | Test K-LD7s in Python | Confirm angle readings |
| 8 | Write KLD7Driver.cpp | Angles in C++ terminal |
| 9 | Wire sound trigger | Impact detection ready |
| 10 | Test sound trigger | Confirm trigger fires |
| 11 | Wrap OPS243 in Qt class | Ball speed in your QML GUI |
| 12 | Wrap K-LD7 in Qt class | Launch angle in your QML GUI |
| 13 | Add rolling buffer spin | Spin detection from radar |
| 14 | Add camera spin detection | Spin detection from impact cam |
| 15 | Implement sensor fusion | Best-of-both spin + angles |
| 16 | Add replay recording | Impact replays saved per shot |

**When hardware arrives, bring it to a session here. I'll write the actual C++ driver code — not pseudocode — that compiles and integrates with your existing PRGR project, CMakeLists.txt and all.**
