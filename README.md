# PRGR Golf Launch Monitor
## IGNORE AS OF DEC 25

DIY golf launch monitor using Raspberry Pi and OV9281 camera.

## Quick Start

### Install Fast C++ Detection (Recommended)

```bash
./INSTALL_FAST_DETECTION.sh
```

### Run the App

```bash
python3 main.py
```

### Configure for 100 FPS

1. Open **Camera Settings**
2. Select **100 FPS** or choose **"Spin Detection"** preset
3. Click **Save**

## Project Structure

```
PRGR_Project/
├── main.py                        # Main application
├── main.qml                       # UI definition
├── INSTALL_FAST_DETECTION.sh      # One-command installer
├── screens/                       # UI screens
│   ├── CameraSettings.qml         # Camera configuration (includes 100 FPS)
│   └── ...
├── cpp_module/                    # C++ ball detection (3-5x faster)
│   ├── fast_detection.cpp
│   ├── CMakeLists.txt
│   ├── setup.py
│   └── build.sh
├── docs/                          # Documentation
│   ├── QUICK_START.md             # Installation guide
│   ├── FAST_DETECTION_README.md   # C++ module documentation
│   └── IMPLEMENTATION_SUMMARY.md  # Technical details
└── tools/                         # Utilities
    └── benchmark_detection.py     # Performance testing
```

## Features

- ✅ **100 FPS capture** with OV9281 global shutter camera
- ✅ **Optimized C++ detection** (3-5x faster than Python)
- ✅ **Automatic fallback** to Python if C++ not built
- ✅ **False trigger prevention** via temporal analysis
- ✅ **Shot history tracking** with CSV export
- ✅ **Multi-profile support** for different players
- ✅ **Adjustable camera settings** for different lighting

## Performance

| Frame Rate | Python | C++ | Status |
|------------|--------|-----|--------|
| 30 FPS | ✅ Works | ✅ Works | Basic |
| 60 FPS | ✅ Works | ✅ Works | Better |
| 100 FPS | ⚠️ Marginal | ✅ Works | **Optimal** |
| 120 FPS | ❌ Too slow | ✅ Works | Advanced |

**Recommended: 100 FPS with C++ module**

## Documentation

- **[Quick Start Guide](docs/QUICK_START.md)** - Installation and setup
- **[C++ Detection README](docs/FAST_DETECTION_README.md)** - Technical details
- **[Implementation Summary](docs/IMPLEMENTATION_SUMMARY.md)** - Complete overview

## Requirements

### Hardware
- Raspberry Pi 4/5
- OV9281 global shutter camera module
- 7" touchscreen (800x480)

### Software
- Raspberry Pi OS
- Python 3.7+
- PySide6
- picamera2
- OpenCV
- (Optional) C++ compiler for fast detection

## Testing

### Benchmark Performance

```bash
./tools/benchmark_detection.py
```

Shows actual FPS and processing times on your hardware.

## Troubleshooting

See [docs/QUICK_START.md](docs/QUICK_START.md) for detailed troubleshooting.

**Common issues:**
- "Fast C++ detection not available" → Run `./INSTALL_FAST_DETECTION.sh`
- Camera not starting → Check camera settings and permissions
- False triggers → Use 100 FPS and ensure proper lighting

## License

DIY Project - Use freely

## Credits

Built for the PRGR launch monitor project using professional techniques from commercial systems like Rapsodo, SkyTrak, and TrackMan.
