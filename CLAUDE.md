# PRGR Launch Monitor

## Project Overview
DIY golf launch monitor on Raspberry Pi 5 (8GB) with OV9281 impact camera, OPS243-A + 2x K-LD7 radar, and Qt 6 / QML touchscreen UI. Single-camera architecture focused on spin detection (impact cam) + triple-radar sensor fusion (speed, angle, spin backup).

## Tech Stack
- **C++17 backend**: camera pipeline, ball detection, sensor fusion, UI managers
- **Qt 6 / QML frontend**: touch-first 800x480 UI
- **OpenCV 4**: calibration, ball detection, tracking
- **Python 3.10+**: radar drivers (OPS243-A, K-LD7), vendored from OpenFlight
- **Camera**: libcamera via rpicam-vid (OV9281 sensor)
- **Build**: CMake (Pi primary, Windows staging via MSVC or MinGW)
- **Binary**: `./build/PRGR_LaunchMonitor`

## Repo Structure
```
src/              C++ source files
include/          C++ headers
screens/          QML UI screens
radar/            Python radar subsystem (ops243, kld7, bridge)
  openflight/     Vendored OpenFlight radar drivers (AGPL-3.0)
scripts/
  setup/          Pi setup scripts (apt, udev, systemd)
  hardware-test/  Standalone hardware validation scripts
tests/            Unit tests (Python radar)
docs/             Documentation and guides
plans/            Feature plans and PRDs
.agents/skills/   Claude agent skills (review, planning, expert checks)
.github/          PR template, CODEOWNERS, CI workflows
```

## Hardware Architecture
- **Impact Camera**: OV9281 + 8mm F1.2 IR-corrected M12 lens, 90° CW portrait, 5ft from ball
  - Preview: 640x480 @ 180 FPS | Capture: 640x400 @ 240 FPS
- **OPS243-A radar**: ball speed, club speed, I/Q rolling buffer (Python driver)
- **K-LD7 vertical**: launch angle (Python driver, 3 Mbaud)
- **K-LD7 horizontal**: club path (Python driver, 3 Mbaud)
- **Display**: 800x480 touchscreen

## Python ↔ C++ Integration
- Python radar runs as a child process launched by C++ app
- Communication: Unix domain socket (`/tmp/prgr_radar.sock`), newline-delimited JSON
- Message types: heartbeat, status, shot_data, error
- C++ RadarBridge class connects, reads messages, exposes to QML
- Heartbeat: every 2s from Python, C++ flags "offline" after 3 missed

## Key Constants (include/HardcodedConstants.h)
- Device distance: 5 ft from ball
- Golf ball: 42.67mm diameter
- OV9281: 1280x800 native, 3.0µm pixel pitch
- Ball pixel diameter at 5ft with 8mm lens: ~75px
- NEVER modify HardcodedConstants.h without explicit user approval

## Development Mode
- Runtime toggle in Settings, persisted across restarts
- Simulated camera feed (synthetic ball with fiducial dots, or user placeholder image)
- Radar simulation planned (OPS243-A + K-LD7 Python bridge)
- Windows builds default to Development Mode ON
- Every QML screen must work in Development Mode

## Development Rules
- Primary platform: Raspberry Pi 5. Windows staging build supported (dev mode only).
- Camera 0 is always portrait (90° CW rotation). Account for this in all coordinate transforms.
- Q_PROPERTY bindings must have matching NOTIFY signals or QML bindings silently fail.
- POSIX calls (mkfifo, open, read, unlink) guarded with `#ifndef _WIN32`
- OpenCV for all vision work in C++. Python only for radar drivers.
- All radar serial I/O on dedicated threads, never main thread.
- No allocations in frame-processing hot loops.
- Touch targets >= 48px on all buttons.
- Theme colors: bg #F5F7FA, card #FFFFFF, text #1A1D23, accent #3A86FF, success #34C759, danger #DA3633, warning #FF9500

## Common Commands (Makefile)
- `make build` — compile C++ app on Pi
- `make run` — launch the app
- `make radar-start` — start Python radar bridge
- `make radar-test` — run Python radar tests
- `make hardware-test-ops243` — test OPS243-A standalone
- `make hardware-test-kld7` — test K-LD7 standalone
- `make setup` — first-time Pi setup

## Active Branch
Development on `claude/` prefixed branches. Never push to main without permission.
