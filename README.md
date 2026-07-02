# PRGR Launch Monitor

A DIY golf launch monitor built on Raspberry Pi 5 with dual OV9281 global shutter cameras, Doppler radar, and a Qt 6 / QML touchscreen interface. Architecture modeled after the Rapsodo MLM2 Pro (Impact Vision + Shot Vision + radar sensor fusion).

![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi%205-c51a4a)
![Language](https://img.shields.io/badge/language-C%2B%2B17-blue)
![UI](https://img.shields.io/badge/UI-Qt%206%20%2F%20QML-41cd52)
![Vision](https://img.shields.io/badge/vision-OpenCV%204-5c3ee8)

## System Overview

```
                        ┌─────────────────────────────┐
                        │     Raspberry Pi 5 (aarch64) │
                        │                             │
  ┌──────────────┐ CSI  │  ┌────────────────────────┐ │
  │ Impact Cam   ├──────┼─►│  CameraManager         │ │
  │ OV9281+8mm   │      │  │  (rpicam-vid, YUV420)  │ │
  │ F1.2 IR lens │      │  └──────────┬─────────────┘ │
  └──────────────┘      │             ▼               │
                        │  ┌────────────────────────┐ │   ┌──────────────┐
  ┌──────────────┐ CSI  │  │  Ball Detection        │ │   │ 800x480      │
  │ Shot Cam     ├──────┼─►│  (OpenCV: Hough, blob, │ ├──►│ Touchscreen  │
  │ OV9281+2.8mm │      │  │  contour, MOG2, Kalman)│ │   │ Qt6/QML UI   │
  │ (on hold)    │      │  └──────────┬─────────────┘ │   └──────────────┘
  └──────────────┘      │             ▼               │
                        │  ┌────────────────────────┐ │
  ┌──────────────┐ UART │  │  Sensor Fusion         │ │
  │ Radar        ├──────┼─►│  (camera + radar)      │ │
  │ OPS243-A +   │      │  └────────────────────────┘ │
  │ 2x K-LD7     │      │                             │
  │ (planned)    │      └─────────────────────────────┘
  └──────────────┘
```

## Hardware

| Component | Spec | Role |
|---|---|---|
| **Compute** | Raspberry Pi 5 | All processing on-device |
| **Impact Camera** | OV9281 (global shutter, mono, 1MP) + 8mm F1.2 IR-corrected M12 lens | Ball spin / impact capture at high FPS, portrait orientation |
| **Shot Camera** | OV9281 + 2.8mm wide-angle | Trajectory tracking (currently on hold) |
| **Radar (planned)** | OPS243-A + 2x K-LD7 | Ball speed, launch angle, club path |
| **Radar (planned)** | OPS243-A + 2x K-LD7 | Ball speed, spin backup, launch angle, club path (OpenFlight-style) |
| **Display** | 800x480 touchscreen | QML touch UI |

Device sits ~5 ft behind a 1x1 ft hitting zone. The impact camera is physically rotated 90° CW (portrait) to maximize vertical coverage of the ball departure path.

## Software Architecture

- **C++17 backend** — camera control, ball detection, tracking, calibration, radar I/O
- **Qt 6 / QML frontend** — touch-first UI with swipeable Controls and Metrics pages
- **OpenCV 4** — multi-method ball detection (Hough circles, blob, contour, MOG2 background subtraction) with confidence scoring and Kalman trajectory tracking
- **rpicam-vid via named pipes** — high-FPS YUV420 capture, Y-channel extraction for monochrome processing

### Key Modules

| Module | Purpose |
|---|---|
| `CameraManager` | Live preview, recording, snapshots, auto-exposure (rpicam-vid) |
| `CaptureManager` | High-speed shot capture (640x400 @ 240 FPS), camera-based impact detection, replay GIF |
| `BallDetector` | Multi-method detection with confidence scoring |
| `TrajectoryTracker` | Kalman filter, launch angle, ball speed |
| `CameraCalibration` | Intrinsic (checkerboard) + extrinsic (ground plane) + ball zone state machine |
| `ProfileManager` / `HistoryManager` | Player profiles, club bags, shot history with CSV export |
| `FrameProvider` | Thread-safe QML image provider for live camera frames |

## Development Mode

The app includes a runtime **Development Mode** (Settings → Development Mode) that swaps the camera and radar for simulated data sources — no hardware required. Useful for UI development, testing, and demos.

- Simulated camera feed (synthetic ball with fiducial markers, or drop your own capture at `~/Pictures/PRGR_DevFrames/cam0.png`)
- Radar simulation planned (OPS243-A + K-LD7 Python bridge)
- Profiles, bag, history, and settings all use real data paths

## Building

Primary target is **Raspberry Pi 5** (live capture depends on rpicam-vid / libcamera). A Windows desktop staging build is also supported for UI work — it runs entirely in Development Mode (auto-enabled). See [docs/WINDOWS_BUILD.md](docs/WINDOWS_BUILD.md).

```bash
# Dependencies (Raspberry Pi OS Bookworm)
sudo apt install qt6-base-dev qt6-declarative-dev qt6-multimedia-dev \
                 libqt6serialport6-dev qml6-module-qtquick-controls \
                 libopencv-dev cmake build-essential

# Build
mkdir build && cd build
cmake ..
make -j4

# Run
./PRGR_LaunchMonitor
```

## Documentation

**Start here:** [Complete Project Briefing](docs/PRGR_Complete_Briefing.md) — the single
self-contained overview (what it is, full hardware specs, wiring, power, status). Shareable
[PDF](docs/exports/PRGR_Complete_Briefing.pdf) / [HTML](docs/exports/PRGR_Complete_Briefing.html) exports are in [`docs/exports/`](docs/exports/).

| Document | Contents |
|---|---|
| [Complete Project Briefing](docs/PRGR_Complete_Briefing.md) | **Canonical overview** — hardware, power, wiring, development plan, status |
| [Optics & Capture Guide](docs/PRGR_Optics_and_Capture_Guide.md) | Plain-language reference: ball pixel diameter, FPS, exposure, gain, IR lenses, ROI cropping, ideal spec sheets |
| [Radar Integration Guide](docs/PRGR_Radar_Integration_Guide.md) | Start-to-finish OPS243-A + K-LD7 integration: parts, wiring, Python validation, C++ port |
| [Camera Research Brief](docs/PRGR_Camera_Research_Brief.md) | Camera module evaluation and spin detection research |
| [Calibration Roadmap](docs/CALIBRATION_ROADMAP.md) | Calibration implementation plan |
| [Windows Build Guide](docs/WINDOWS_BUILD.md) | Desktop staging build for UI development (Development Mode, no Pi needed) |
| [Radar Subsystem](radar/README.md) | Python radar drivers (OPS243-A + K-LD7), bridge to C++ |

Generated PDF/HTML exports of the briefing and optics guide live in
[`docs/exports/`](docs/exports/) — do not hand-edit them; they are rebuilt from the markdown.

## Project Status

- ✅ Impact camera capture pipeline (OV9281, 240 FPS)
- ✅ Touch UI: profiles, club bags, shot history, metrics, settings
- ✅ Phase 1 intrinsic calibration (checkerboard)
- ✅ Ball zone state machine (NO_BALL → STABLE → READY → IMPACT_DETECTED)
- ✅ Development Mode (simulated camera, works on Windows)
- ✅ Windows desktop staging build
- ✅ Agent skills (code review, planning, expert engineer checks)
- 🔄 Radar integration (OPS243-A + 2x K-LD7, Python drivers from OpenFlight) — current priority
- 📋 Establish radar accurate range, then set impact-camera distance (see the briefing)
- 📋 Sensor fusion (camera spin + radar speed/angle)
- 📋 Spin measurement from fiducial-marked balls
- 📋 Ballistics / carry distance calculation

## License

Personal DIY project. Radar drivers in `radar/openflight/` are vendored from
[OpenFlight](https://github.com/jewbetcha/openflight) under AGPL-3.0.
