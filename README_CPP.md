# PRGR Launch Monitor - C++ Implementation

## Architecture Overview

Complete C++ rewrite using Qt 6 + QML for maximum performance on Raspberry Pi.

### Technology Stack
- **Qt 6**: Core, Quick, QML, Multimedia, SerialPort
- **OpenCV 4**: Computer vision (ball detection, tracking)
- **libcamera**: Direct camera API for 120+ FPS capture
- **CMake**: Build system with optimization flags

### Completed Components ✅

#### 1. SettingsManager.cpp (157 lines)
**Purpose**: Persistent configuration storage

**Features**:
- QSettings JSON-based storage (`~/.local/share/PRGR/settings.json`)
- Camera settings: shutter speed, gain, FPS, resolution, format
- Q_PROPERTY bindings for QML access
- Type-safe getters/setters: `getString()`, `getNumber()`, `getDouble()`, `getBool()`
- Auto-sync on value changes

**QML Usage**:
```qml
Text {
    text: settingsManager.cameraResolution  // Q_PROPERTY binding
}

Button {
    onClicked: settingsManager.setString("cameraFormat", "RAW")  // Q_INVOKABLE
}
```

#### 2. KLD2Manager.cpp (238 lines)
**Purpose**: K-LD2 Doppler radar integration

**Features**:
- QSerialPort integration (38400 baud, `/dev/serial0`)
- ASCII protocol: `$S0405` (sampling), `$C01` (speed query)
- Swing state machine: `in_swing` → `max_club_speed` → impact detection
- 20 Hz polling rate (50ms intervals via QTimer)

**Signals**:
- `clubApproaching(double speed)`: Swing starting (fills circular buffer)
- `impactDetected()`: Club passed through (speed dropped)
- `clubSpeedUpdated(double)`: Real-time club speed
- `ballSpeedUpdated(double)`: Real-time ball speed

**State Machine**:
```
IDLE → (speed > threshold) → IN_SWING → (peak speed) → (speed drops) → IMPACT → IDLE
```

#### 3. FrameProvider.cpp (60 lines)
**Purpose**: Thread-safe QML image provider

**Features**:
- QQuickImageProvider for `Image { source: "image://frameprovider" }`
- QMutex-protected frame updates
- OpenCV Mat → QImage conversion (grayscale, RGB, RGBA)
- 120 FPS real-time preview capability

**Thread Safety**:
```cpp
void updateFrame(const cv::Mat &frame) {
    QMutexLocker locker(&m_mutex);  // Thread-safe
    m_currentFrame = cvMatToQImage(frame);
    emit frameUpdated();  // Signal QML to refresh
}
```

#### 4. main.cpp (62 lines)
**Purpose**: Qt application entry point

**Features**:
- QQmlApplicationEngine initialization
- Context property exposure to QML
- Image provider registration
- Material design style

**Managers Exposed to QML**:
- `settingsManager` → Settings access
- `kld2Manager` → Radar control
- `cameraManager` → Preview/recording (TODO)
- `captureManager` → Ball tracking (TODO)

### In-Progress Components 🚧

#### 5. CameraManager.cpp (Partial)
**Purpose**: Camera preview and recording

**Planned Features**:
- libcamera C++ API integration
- 120 FPS capture at 320x240 using lores stream
- YUV420 Y-channel extraction for grayscale
- rpicam-vid integration for MP4 recording
- Thread-safe preview loop

**Challenges**:
- libcamera Request/FrameBuffer API complexity
- Event loop integration with Qt
- Buffer memory management (mmap)

**Alternative Approach** (recommended):
- Use Picamera2 Python bindings via pybind11
- Or use rpicam-vid/rpicam-raw with named pipes
- Focus C++ effort on CaptureManager (ball detection)

#### 6. CaptureManager.cpp (TODO - Critical)
**Purpose**: High-speed ball capture and impact detection

**Required Features**:
- **200 FPS ball tracking** at 320x240
- **Circular buffer**: Store last 40 frames continuously
- **Hybrid detection**: K-LD2 radar + camera verification
- **Ball detection**: HoughCircles + template matching
- **Kalman filter**: Smooth ball tracking
- **Practice swing elimination**: Radar says impact, camera confirms ball moved
- **Replay generation**: MP4 video + GIF creation

**Detection Flow**:
```
1. Lock on stationary ball (HoughCircles)
2. Monitor K-LD2 for club approach → Start buffering
3. K-LD2 detects impact timing (speed drop)
4. Camera verifies ball actually moved (pixel threshold)
5. If both confirm → Save 40 before + 20 after frames
6. If mismatch → Practice swing, discard and reset
```

**Key Algorithms**:
- **Ball detection**: `cv::HoughCircles()` with radius constraints
- **Template matching**: `cv::matchTemplate()` for tracking
- **Kalman filter**: `cv::KalmanFilter` for prediction
- **Impact detection**: Directional movement threshold (Y-axis)

**Circular Buffer**:
```cpp
std::deque<cv::Mat> m_frameBuffer;
static constexpr int BUFFER_SIZE = 40;

// In capture loop:
m_frameBuffer.push_back(frame.clone());
if (m_frameBuffer.size() > BUFFER_SIZE) {
    m_frameBuffer.pop_front();
}
```

**Hybrid Verification Logic**:
```cpp
// K-LD2 detected impact timing
if (m_kld2ImpactDetected) {
    // Check if camera detected ball movement
    bool ballMoved = detectImpact(originalBall, currentBall, threshold, axis, direction);

    if (ballMoved) {
        // ✅ CONFIRMED IMPACT: Save replay
        std::vector<cv::Mat> frames(m_frameBuffer.begin(), m_frameBuffer.end());
        capturePostImpactFrames(frames, 20);
        createReplayVideo(frames, filePath, fps, speedMultiplier);
    } else {
        // ⚠️ PRACTICE SWING: Discard
        qDebug() << "Practice swing detected - ball didn't move";
        resetForNextShot();
    }
}
```

### Build Instructions

```bash
# Install dependencies (Raspberry Pi OS)
sudo apt install qt6-base-dev qt6-declarative-dev qt6-multimedia-dev \
                 qt6-serialport-dev libopencv-dev libcamera-dev \
                 cmake build-essential pkg-config

# Build
mkdir build && cd build
cmake ..
make -j4

# Run
./PRGR_LaunchMonitor
```

### CMake Configuration

**Optimizations**:
- `-O3`: Maximum optimization
- `-march=native`: Raspberry Pi specific CPU instructions
- `-Wall -Wextra`: All warnings enabled

**Libraries**:
- Qt6::Core, Qt6::Quick, Qt6::Qml, Qt6::SerialPort
- OpenCV (cv::Mat, HoughCircles, matchTemplate, KalmanFilter)
- libcamera (Camera, FrameBuffer, Request)

### Performance Targets

| Metric | Python (Current) | C++ (Target) |
|--------|------------------|--------------|
| Camera capture | 120 FPS | 120 FPS |
| Ball detection | ~100 FPS | 200+ FPS |
| YUV420 extraction | 8ms/frame | <1ms/frame |
| Memory usage | ~150MB | ~40MB |
| Startup time | 3-5 seconds | <1 second |
| Binary size | N/A (Python) | ~2MB (stripped) |

### Project Structure

```
PRGR_Project/
├── CMakeLists.txt          # Build configuration
├── qml.qrc                 # QML resources
├── include/                # C++ headers
│   ├── SettingsManager.h   ✅
│   ├── KLD2Manager.h       ✅
│   ├── FrameProvider.h     ✅
│   ├── CameraManager.h     🚧
│   └── CaptureManager.h    ⏳
├── src/                    # C++ sources
│   ├── main.cpp            ✅
│   ├── SettingsManager.cpp ✅
│   ├── KLD2Manager.cpp     ✅
│   ├── FrameProvider.cpp   ✅
│   ├── CameraManager.cpp   🚧 (partial)
│   └── CaptureManager.cpp  ⏳ (TODO - critical)
└── screens/                # QML UI (unchanged)
    ├── AppWindow.qml
    ├── CameraScreen.qml
    ├── CameraSettings.qml
    └── Components/
```

### Next Steps (Priority Order)

1. **Complete CaptureManager.cpp** ⭐ **CRITICAL**
   - 200 FPS ball tracking loop
   - Hybrid radar + camera verification
   - Circular buffer management
   - Replay generation

2. **Finalize CameraManager.cpp**
   - Either: Complete libcamera integration
   - Or: Use rpicam-vid with named pipes
   - Or: Keep Python Picamera2 with pybind11 wrapper

3. **Integration Testing**
   - Build and test on Raspberry Pi
   - Verify 120 FPS preview
   - Test K-LD2 radar detection
   - Validate hybrid impact detection

4. **Optimization**
   - Profile with perf/gprof
   - SIMD optimizations for ball detection
   - Multi-threading for parallel processing

### Known Issues

1. **CameraManager.cpp incomplete**:
   - libcamera::CameraManager name conflict with class name
   - Request completion handling not implemented
   - Event loop integration with Qt pending

2. **CaptureManager.cpp not started**:
   - Most critical component
   - Requires ~600 lines of implementation
   - Ball detection algorithms need porting from Python

3. **QML bindings**:
   - Some managers not yet exposed to QML
   - Signal/slot connections incomplete

### Migration Notes (Python → C++)

**What Changed**:
- Python `def` → C++ `void methodName()`
- Python signals → Qt `signals:` section
- Python `@Slot()` → Qt `public slots:`
- Python threading → `QThread` or `std::thread`
- NumPy arrays → `cv::Mat`
- Picamera2 → libcamera C++ API

**What Stayed**:
- QML UI files (100% compatible)
- Settings format (QSettings JSON)
- K-LD2 protocol (serial communication)
- Ball detection algorithms (OpenCV)

### Contributing

When implementing remaining features:
1. Follow Qt coding style (camelCase methods, m_ member prefix)
2. Use `qDebug()` for logging (not `std::cout`)
3. Prefer Qt types (`QString`, `QVector`) over STL when interfacing with QML
4. Document complex algorithms with comments
5. Use `Q_PROPERTY` for QML-accessible properties
6. Use `Q_INVOKABLE` for QML-callable methods

### License

Same as original project (specify license here).
