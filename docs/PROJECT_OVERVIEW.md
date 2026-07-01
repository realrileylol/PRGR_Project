# PRGR Launch Monitor — Project Overview

## What This Is

The PRGR Launch Monitor is a DIY golf launch monitor — a device that measures what
happens to a golf ball (and the club) at the moment of impact and for the first few
feet of ball flight, then uses that data to calculate the full shot: carry distance,
total distance, launch angle, spin, ball speed, club speed, and smash factor.

It is built entirely on a **Raspberry Pi 5**, using a high-speed camera to see the
ball leave the tee and a set of Doppler radars to measure speed and angles. All
processing happens on the device — there is no phone app, no cloud service, and no
subscription. You hit a ball, and the numbers appear on the touchscreen.

The architecture is modeled after commercial units like the **Rapsodo MLM2 Pro**
(camera "Impact Vision" + radar sensor fusion), but assembled from off-the-shelf
sensors and open hardware at a fraction of the retail cost.

## What We're Trying to Achieve

### Primary goal
Produce **accurate, repeatable shot data** for a golfer practicing indoors or at a
range, using a device that:

1. **Detects the moment of impact** reliably (camera + radar + sound trigger)
2. **Measures ball speed and club speed** (Doppler radar)
3. **Measures launch angle and club path** (twin radars at different orientations)
4. **Detects ball spin** (high-FPS camera watching fiducial-marked balls leave the tee)
5. **Fuses all sensor inputs** into a single confident shot reading
6. **Calculates carry and total distance** via a ballistics model
7. **Presents it all** on a fast, touch-first 800×480 screen

### Design principles
- **On-device only** — no external dependencies at runtime. The Pi does everything.
- **Sensor fusion over any single source** — the camera, the three radars, and the
  sound trigger cross-check each other. Speed from radar, spin from the camera, angle
  from the vertical radar; each sensor covers another's weakness.
- **Touch-first UI** — designed for a golfer standing at a mat, glancing at the screen
  between shots. Big numbers, minimal taps, works with gloves.
- **Development Mode everywhere** — every screen and feature works with simulated data
  so the UI can be built and tested without any hardware attached.

### Current phase
The project is in the **impact-camera + calibration** phase. The camera capture
pipeline runs at high FPS, the ball-zone state machine detects when a ball is present
and when it leaves, and intrinsic camera calibration (checkerboard) is implemented.
Radar integration (OPS243-A + 2× K-LD7) is the next major hardware milestone, with the
Python drivers vendored from the OpenFlight project.

---

## Hardware

### Compute & Display

| Component | Spec | Role |
|---|---|---|
| **[Raspberry Pi 5](https://www.raspberrypi.com/products/raspberry-pi-5/)** | 8 GB RAM, quad-core Arm Cortex-A76 @ 2.4 GHz, aarch64 | All processing on-device: camera pipeline, ball detection, sensor fusion, UI |
| **[Waveshare 5" DSI LCD](https://www.waveshare.com/5inch-dsi-lcd.htm)** | 800 × 480 IPS, DSI interface @ 60 Hz, 5-point capacitive touch, 6H tempered glass, ~1.2 W | The entire user interface (Qt 6 / QML) |
| **microSD / storage** | Raspberry Pi OS Bookworm (64-bit) | OS, application binary, shot history, calibration data |

**Display details.** The [Waveshare 5inch DSI LCD](https://www.waveshare.com/5inch-dsi-lcd.htm)
is a driver-free plug-and-play panel with a native **800 × 480** resolution — which the
entire PRGR UI targets exactly, so there is **no scaling** and every pixel maps 1:1. It
connects over the **DSI ribbon** (not HDMI), supports **5-point capacitive touch** through
a tempered-glass surface, and draws only ~1.2 W. Software backlight brightness control is
supported. See the [Waveshare wiki](https://www.waveshare.com/wiki/5inch_DSI_LCD) for setup.

> ⚠️ **Pi 5 cable gotcha:** the Raspberry Pi 5 changed its DSI/CSI connector to the smaller
> 22-pin FPC. This panel needs the correct adapter cable for the Pi 5 — the
> **[Waveshare Pi5-Display-Cable-200mm](https://www.waveshare.com/pi5-display-cable-200mm.htm)**
> (or the official Raspberry Pi DSI cable for Pi 5). The cable that ships in the box is for
> older Pi models with the 15-pin connector.

**Related display variants** (same 800 × 480, if you ever swap panels):
- [5inch Capacitive IPS Touch Display (Type B)](https://www.waveshare.com/5inch-dsi-lcd-b.htm) — lower power consumption variant
- [5inch DSI Display, IPS, touch optional](https://www.waveshare.com/50h-800480-ips.htm) — thin/light design
- [5inch Display, DPI Interface, IPS, No Touch](https://www.waveshare.com/5inch-lcd-for-pi.htm) — non-touch DPI variant

### Impact Camera

The single most important sensor for spin detection. It watches the ball for the first
few feet of departure at very high frame rates.

| Attribute | Spec |
|---|---|
| **Sensor** | OmniVision **[OV9281](https://www.arducam.com/product/arducam-ov9281-1mp-global-shutter-mipi-camera-modules-for-raspberry-pi/)** — global shutter, monochrome, 1 MP |
| **Native resolution** | 1280 × 800 |
| **Pixel pitch** | 3.0 µm |
| **Sensor size** | 3.84 mm × 2.40 mm |
| **Lens** | 8 mm F1.2 IR-corrected M12 |
| **Interface** | CSI (camera serial interface) via libcamera / rpicam-vid |
| **Orientation** | Rotated **90° clockwise (portrait)** to maximize vertical coverage of the ball's departure path |
| **Distance from ball** | ~5 ft |
| **Preview mode** | 640 × 480 @ 180 FPS |
| **Capture mode** | 640 × 400 @ 240 FPS |
| **Expected ball size** | ~75 px diameter at 5 ft with the 8 mm lens |

**Why global shutter?** A global-shutter sensor exposes every pixel at the same instant.
A rolling shutter (found in most cheap cameras) exposes row by row, which smears and
skews a fast-moving ball. For measuring spin and speed at impact, global shutter is
non-negotiable.

**Why monochrome + IR?** Mono sensors have no color filter, so every pixel collects
light — critical for fast, short exposures that freeze motion. The IR-corrected lens
keeps the image sharp under infrared illumination.

### Radar (planned integration)

Three Doppler radar modules provide speed and angle data, cross-checking the camera.
Drivers are vendored from the OpenFlight project (Python), then bridged to the C++ app.

| Module | Spec | Role |
|---|---|---|
| **[OPS243-A Doppler radar](https://omnipresense.com/product/ops243-doppler-radar-sensor/)** | OmniPreSense, USB serial, exposes raw I/Q data | **Ball speed, club speed**, and spin backup via I/Q rolling buffer |
| **[K-LD7 radar #1 (vertical)](https://www.rfbeam.ch/product?id=36)** | RFbeam, 3.3 V serial @ 3 Mbaud | **Launch angle** (vertical) |
| **[K-LD7 radar #2 (horizontal)](https://www.rfbeam.ch/product?id=36)** | RFbeam, 3.3 V serial @ 3 Mbaud | **Club path / aim** (horizontal) |

> ⚠️ **Hardware notes for radar:**
> - Buy the **OPS243-A**, *not* the OPS243-A-W (WiFi) — the WiFi version's baud rate is
>   too slow to stream I/Q data.
> - The K-LD7 modules require **3.3 V** FTDI USB-serial adapters. A 5 V adapter will
>   **damage** the module.

### Impact Trigger (planned)

| Component | Spec | Role |
|---|---|---|
| **[SparkFun SEN-14262 Sound Detector](https://www.sparkfun.com/products/14262)** | Requires a 47 kΩ resistor (R17) mod for 3.3 V | Detects the *sound* of impact to trigger the radar's rolling I/Q buffer capture |

### Approximate cost of the radar add-on

~$412 for the OPS243-A, two K-LD7 modules, two 3.3 V FTDI adapters, the sound detector,
and wiring — assuming you already have the Pi 5, touchscreen, and impact camera.

---

## How the Pieces Talk to Each Other

```
  ┌──────────────┐  CSI   ┌───────────────────────────────────┐
  │ Impact Cam   ├───────►│  Raspberry Pi 5 (aarch64)         │
  │ OV9281 + 8mm │        │                                   │
  │ 90° portrait │        │  ┌─────────────────────────────┐  │   ┌──────────────┐
  └──────────────┘        │  │ C++17 backend               │  │   │ 800×480      │
                          │  │  • Camera pipeline          │  ├──►│ Touchscreen  │
  ┌──────────────┐  USB   │  │  • Ball detection (OpenCV)  │  │   │ Qt 6 / QML   │
  │ OPS243-A     ├───────►│  │  • Calibration              │  │   └──────────────┘
  └──────────────┘        │  │  • Sensor fusion            │  │
                          │  └──────────────┬──────────────┘  │
  ┌──────────────┐ 3.3V   │                 │ Unix socket      │
  │ 2× K-LD7     ├───────►│  ┌──────────────▼──────────────┐  │
  │ (FTDI 3Mbaud)│  UART  │  │ Python radar subsystem      │  │
  └──────────────┘        │  │  (OPS243 + K-LD7 drivers)   │  │
                          │  └─────────────────────────────┘  │
                          └───────────────────────────────────┘
```

- **C++17 backend** — camera control, ball detection (OpenCV 4), tracking, calibration,
  sensor fusion, and the UI managers. This is the core of the app.
- **Python radar subsystem** — runs as a **child process** launched by the C++ app.
  The radar drivers are Python (vendored from OpenFlight), so they stay in Python.
- **The bridge** — C++ and Python talk over a **Unix domain socket**
  (`/tmp/prgr_radar.sock`) using newline-delimited JSON. Message types: `heartbeat`,
  `status`, `shot_data`, `error`. Python sends a heartbeat every 2 s; C++ flags the
  radar "offline" after 3 missed beats.
- **Qt 6 / QML frontend** — the touchscreen UI. It reads state from the C++ managers via
  `Q_PROPERTY` bindings and calls `Q_INVOKABLE` methods for user actions.

---

## Software Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Backend** | C++17 | Camera pipeline, ball detection, sensor fusion, UI managers |
| **Frontend** | Qt 6 / QML | Touch-first 800×480 UI |
| **Vision** | OpenCV 4 | Ball detection (Hough, blob, contour, MOG2), Kalman tracking, calibration |
| **Radar drivers** | Python 3.10+ | OPS243-A and K-LD7 serial drivers (vendored from OpenFlight, AGPL-3.0) |
| **Camera capture** | libcamera / rpicam-vid | High-FPS YUV420 capture, Y-channel extraction for mono processing |
| **Build** | CMake | Pi is the primary target; Windows desktop staging build supported (Development Mode only) |

---

## Key Physical Constants

These are fixed in `include/HardcodedConstants.h` and define the physical world. They
are **never** changed by user calibration.

| Constant | Value | Source |
|---|---|---|
| Golf ball diameter | 42.67 mm (1.68 in) | USGA / R&A rules (official minimum) |
| Golf ball weight | 45.93 g | USGA / R&A rules (maximum) |
| OV9281 native resolution | 1280 × 800 | Sensor datasheet |
| OV9281 pixel pitch | 3.0 µm | Sensor datasheet |

---

---

## Appendix A — Legacy / Experimental: Two-Camera Design

> ⚠️ _This section documents an **earlier, abandoned** architecture. It is kept for
> reference only — it is **not** the current direction. The current design is
> **single-camera** (impact camera only), as described above. Some values from this
> old design still linger in `include/HardcodedConstants.h` (see the note at the end)
> and have not yet been reconciled. Treat everything in this appendix as **unverified,
> experimental, and possibly revisited later — or possibly dropped entirely.**_

_The original concept used **two** cameras instead of one, mirroring the Rapsodo MLM2
Pro's "Impact Vision + Shot Vision" split, with both cameras co-located behind the ball:_

| _Camera_ | _Sensor_ | _Lens_ | _Role_ | _Distance_ | _Capture_ |
|---|---|---|---|---|---|
| _Spin cam_ | _OV9281 (CSI)_ | _12 mm telephoto_ | _Close-up spin detection (zoomed in on the ball)_ | _7–8 ft_ | _640 × 480 @ 180 FPS_ |
| _Trajectory cam_ | _OV9281 (USB)_ | _2.8 mm wide-angle_ | _Trajectory tracking over the full hitbox volume_ | _7–8 ft_ | _640 × 400 @ 240 FPS_ |

_In that design a **3D "hitbox"** was defined as the detection zone the trajectory camera
had to cover — a 1 ft × 1 ft × 1 ft volume located **7–8 ft** from the ball at address:_

- _Near face: 7 ft (2133.6 mm) from the ball_
- _Far face: 8 ft (2438.4 mm) from the ball_
- _Width / height: 1 ft (304.8 mm) each_
- _Origin: ball position at address (tee)_

_**Why it was set aside:** the current experimental repo moved to a single impact camera
with an **8 mm lens at ~5 ft**, focused on spin detection, with the trajectory/speed/angle
job handed to the triple-radar array (OPS243-A + 2× K-LD7) instead of a second camera.
This simplifies the build, the wiring, and the calibration._

> 📌 _**Unreconciled constants:** `include/HardcodedConstants.h` still contains the
> two-camera values — `SPIN_CAM_FOCAL_LENGTH_MM = 12.0`, `TRAJ_CAM_FOCAL_LENGTH_MM = 2.8`,
> and the `HITBOX_NEAR_FT = 7.0` / `HITBOX_FAR_FT = 8.0` hitbox — which conflict with the
> current single-camera, 8 mm, ~5 ft design. Per project rules, `HardcodedConstants.h` is
> **not** modified without explicit approval, so this mismatch is flagged here rather than
> silently changed. Decide later whether to (a) update the constants to the single-camera
> 5 ft design, or (b) keep them if the two-camera idea is revived._

---

## Development Mode

The app includes a runtime **Development Mode** (Settings → Development Mode) that swaps
real hardware for simulated data sources — no camera or radar required. This is how the
UI is built and demoed on a laptop or any machine without the Pi hardware.

- **Simulated camera feed** — a synthetic ball with fiducial markers, or a user-supplied
  placeholder image
- **Radar simulation** — planned, mirroring the OPS243-A + K-LD7 bridge
- **Real data paths** — profiles, club bag, shot history, and settings all use the real
  storage paths even in Development Mode
- **Windows staging builds** default to Development Mode ON

Every QML screen must function in Development Mode. This is a hard rule — it's what lets
UI work happen away from the hardware.

---

## Project Status

- ✅ Impact camera capture pipeline (OV9281, up to 240 FPS)
- ✅ Touch UI: profiles, club bags, shot history, metrics, settings
- ✅ Phase 1 intrinsic calibration (checkerboard)
- ✅ Ball-zone state machine (NO_BALL → STABLE → READY → IMPACT_DETECTED)
- ✅ Development Mode (simulated camera; works on Windows)
- ✅ Windows desktop staging build
- 🔄 Impact camera calibration at working distance
- 🔄 Radar integration (OPS243-A + 2× K-LD7, Python drivers from OpenFlight)
- 📋 Sensor fusion (camera spin + radar speed/angle)
- 📋 Spin measurement from fiducial-marked balls
- 📋 Ballistics / carry distance calculation

---

## Related Documentation

| Document | Contents |
|---|---|
| [Optics & Capture Guide](PRGR_Optics_and_Capture_Guide.md) | Ball pixel diameter, FPS, exposure, gain, IR lenses, ROI cropping |
| [Radar Integration Guide](PRGR_Radar_Integration_Guide.md) | Full OPS243-A + K-LD7 integration: parts, wiring, Python validation, C++ port |
| [Camera Research Brief](PRGR_Camera_Research_Brief.md) | Camera module evaluation and spin detection research |
| [Windows Build Guide](WINDOWS_BUILD.md) | Desktop staging build for UI development |
| [Calibration Roadmap](CALIBRATION_ROADMAP.md) | Calibration implementation plan |
