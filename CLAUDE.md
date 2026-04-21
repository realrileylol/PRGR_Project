# PRGR Launch Monitor

## Project Overview
DIY golf launch monitor running on Raspberry Pi 5 with dual OV9281 global shutter cameras and K-LD2 24GHz Doppler radar. Architecture modeled after the Rapsodo MLM2 Pro (see `Rapsodo MLM2PRO Camera Hardware Deep Dive.pdf` in repo root).

## Tech Stack
- **Language**: C++ with Qt 6 / QML frontend
- **Vision**: OpenCV 4 (calibration, ball detection, tracking)
- **Camera**: libcamera via rpicam-vid (OV9281 sensors)
- **Build**: CMake, targets Raspberry Pi 5 (aarch64)
- **Binary**: `./PRGR_Launchmonitor`

## Hardware Architecture (MLM2 Pro-style)
- **Camera 0 (Impact Cam)**: OV9281 + 12mm F1.2 M12 lens, rotated 90 degrees CW (portrait mode), captures ball spin/impact at high FPS. CSI connection.
- **Camera 1 (Trajectory Cam)**: OV9281 + 2.8mm wide-angle lens, captures full hitbox volume for trajectory tracking. USB connection.
- **Both cameras**: co-located 7-8 ft behind the ball (hitbox distance). The 12mm telephoto provides optical zoom; no camera is physically close to the swing path.
- **Radar**: K-LD2 24GHz Doppler for ball/club velocity (serial UART, 38400 baud). Currently not in active use.

## Key Constants (include/HardcodedConstants.h)
- Hitbox: 7-8 ft from ball, 1ft x 1ft volume
- Both cameras at hitbox distance (SPIN_CAM and TRAJ_CAM distances = HITBOX_NEAR/FAR)
- Golf ball: 42.67mm diameter
- OV9281: 1280x800 native, 3.0um pixel pitch

## Camera Modes (src/CameraManager.cpp)
- Camera 0: 640x480 @ 180 FPS (VGA mode), rotated 90 CW to 480x640 portrait display
- Camera 1: 640x400, landscape
- Future: Camera 0 should move to 1280x800 @ 120 FPS for spin dot resolution

## Calibration Pipeline (src/CameraCalibration.cpp)
- **Phase 1 (Intrinsic)**: Checkerboard-based, cv::calibrateCamera. UI in screens/CalibrationScreen.qml. Fully implemented.
- **Phase 2 (Extrinsic)**: Currently click-to-mark via setGroundPlanePoints + cv::solvePnP. Planned upgrade to ArUco auto-detection.
- **Ball Zone**: Defines 12x12 inch tracking zone. State machine: NO_BALL -> BALL_IN_ZONE -> STABLE -> READY -> IMPACT_DETECTED.

## QML Screens (screens/)
- AppWindow.qml: Main navigation
- CalibrationScreen.qml: Phase 1 + Phase 2 calibration UI
- CameraAlignmentScreen.qml: View alignment (like MLM2 Pro)
- CameraScreen.qml: Live camera preview
- BallZoneCalibration.qml: Ball zone setup

## Reference Documents (in repo root)
- `Rapsodo MLM2PRO Camera Hardware Deep Dive.pdf`: Architecture reference
- `K-LD2-RFB-00H-02_datasheet.pdf`: Radar module datasheet (not currently in use)
- `CALIBRATION_ROADMAP.md`: Calibration implementation plan

## Development Rules
- Target platform is Raspberry Pi 5 only. Cannot build or run on Windows/Mac.
- Never modify HardcodedConstants.h without explicit user approval (physical world values).
- Camera 0 is always portrait (90 CW rotation). Account for this in all coordinate transforms.
- Q_PROPERTY bindings must have matching NOTIFY signals or QML bindings silently fail.
- Prefer OpenCV for all vision work. No Python anywhere in the project.

## Active Branch
Development happens on branches prefixed with `claude/`. Always push to the designated feature branch, never to main without permission.
