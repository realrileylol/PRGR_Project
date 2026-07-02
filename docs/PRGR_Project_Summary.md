# PRGR Launch Monitor — Project Summary

*A one-page-ish overview for sharing. For deep detail see
[PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md), the
[Radar Integration Guide](PRGR_Radar_Integration_Guide.md), and the
[Camera Research Brief](PRGR_Camera_Research_Brief.md).*

---

## What it is

A **DIY golf launch monitor** — a device that measures what happens to a golf ball and club
at impact, then calculates the full shot: **carry, total distance, ball speed, club speed,
launch angle, spin, smash factor**. Everything runs on a **Raspberry Pi 5** with a
touchscreen. No phone app, no cloud, no subscription — you hit a ball and the numbers appear
on the screen.

It's built from off-the-shelf sensors and modeled after the commercial **Rapsodo MLM2 Pro**
(a high-speed camera for spin + Doppler radar for speed/angle, fused together), at a
fraction of the retail cost.

## What we're trying to achieve

Accurate, repeatable shot data for a golfer practicing indoors or at the range, from a
device that:
- detects the moment of impact,
- measures ball and club speed (radar),
- measures launch angle and club path (radar),
- detects ball spin (high-speed camera),
- fuses it all into one confident reading, and
- calculates carry/total distance.

---

## The parts

| Component | What it is | Role | Reference |
|---|---|---|---|
| **Raspberry Pi 5** (8 GB) | Quad-core Arm SBC | Runs everything — camera, vision, radar fusion, UI | [link](https://www.raspberrypi.com/products/raspberry-pi-5/) |
| **Waveshare 5" DSI LCD** | 800×480 IPS, 5-pt capacitive touch | The entire touchscreen UI | [link](https://www.waveshare.com/5inch-dsi-lcd.htm) |
| **OV9281 impact camera** | 1 MP global-shutter mono, 8 mm IR lens | High-speed spin/impact capture (up to 240 FPS) | [link](https://www.arducam.com/product/arducam-ov9281-1mp-global-shutter-mipi-camera-modules-for-raspberry-pi/) |
| **OPS243-A radar** | 24 GHz Doppler, I/Q output | Ball speed, club speed, spin backup | [product](https://omnipresense.com/product/ops243-doppler-radar-sensor/) · [API](https://omnipresense.com/wp-content/uploads/2025/10/AN-010-AD_API_Interface.pdf) |
| **K-LD7 radar ×2** | 24 GHz digital radar w/ angle | Launch angle (vertical) + club path (horizontal) | [product](https://rfbeam.ch/product/k-ld7-radar-transceiver/) · [datasheet](https://www.mouser.com/datasheet/2/1565/K_LD7_Datasheet-3446777.pdf) |
| **SparkFun sound detector** | Acoustic trigger (SEN-14262) | Detects impact "click" to trigger radar capture | [product](https://www.sparkfun.com/products/14262) · [guide](https://learn.sparkfun.com/tutorials/sound-detector-hookup-guide/all) |

**Key hardware gotchas:**
- Buy the **OPS243-A**, *not* the WiFi version (baud rate too slow for I/Q data).
- K-LD7 radars need **3.3 V** serial adapters — a 5 V adapter will **damage** them.
- The Pi 5 needs the correct **DSI cable** for the display (its connector changed from
  older Pis).

Approx. cost of the radar add-on (if you already have the Pi, screen, and camera): **~$412**.

---

## How it connects

```
  ┌──────────────┐  CSI   ┌───────────────────────────────────┐
  │ Impact Cam   ├───────►│  Raspberry Pi 5                   │
  │ OV9281 + 8mm │        │                                   │
  │ 90° portrait │        │  ┌─────────────────────────────┐  │   ┌──────────────┐
  └──────────────┘        │  │ C++17 backend               │  ├──►│ 800×480      │
                          │  │  camera • OpenCV vision •   │  │   │ Touchscreen  │
  ┌──────────────┐  USB   │  │  calibration • fusion • UI  │  │   │ Qt 6 / QML   │
  │ OPS243-A     ├───────►│  └──────────────┬──────────────┘  │   └──────────────┘
  └──────────────┘        │                 │ Unix socket      │
  ┌──────────────┐ 3.3V   │  ┌──────────────▼──────────────┐  │
  │ 2× K-LD7     ├───────►│  │ Python radar drivers        │  │
  │  (UART)      │  UART  │  │  (OPS243 + K-LD7)           │  │
  └──────────────┘        │  └─────────────────────────────┘  │
                          └───────────────────────────────────┘
```

- **C++17 backend** does the heavy lifting: camera control, ball detection (OpenCV 4),
  calibration, sensor fusion, and the UI logic.
- **Python** runs the radar drivers (vendored from the open-source *OpenFlight* project) as
  a child process. C++ and Python talk over a **Unix socket** using newline-delimited JSON
  (heartbeat, status, shot data, errors).
- **Qt 6 / QML** is the touchscreen front-end — a fast, finger-first UI at exactly 800×480
  (matches the display 1:1, no scaling).

**Software stack:** C++17 · Qt 6 / QML · OpenCV 4 · Python 3.10+ · libcamera/rpicam-vid ·
CMake build.

---

## Where we are (as of 2026-07-01)

**Done:**
- ✅ Impact camera capture pipeline (OV9281, up to 240 FPS)
- ✅ Full touch UI — profiles, club bags, shot history, metrics, settings
- ✅ Intrinsic camera calibration (checkerboard)
- ✅ Ball-zone state machine (detects ball present → ready → impact)
- ✅ Development Mode (runs on a laptop with simulated data — no hardware needed)
- ✅ Windows desktop staging build for UI work

**Next, in order:**
1. 🔄 **Get the radars working** (OPS243-A + 2× K-LD7) — *current priority*
2. 📋 Establish the radars' **maximum accurate range** (this defines the physical geometry)
3. 📋 Introduce the impact camera; derive the ball distance from **pixel-size needs +
   radar range** (the "5 ft" figure is a starting hypothesis, not yet validated)
4. 📋 Calibrate the real geometry
5. 📋 Sensor fusion (camera spin + radar speed/angle)
6. 📋 Spin measurement from the camera
7. 📋 Ballistics / carry-distance calculation

**Key open question:** whether spin can be measured on unmarked balls, or whether special
marked/dotted balls are required (even the commercial MLM2 Pro requires dotted balls for
spin). This is the biggest research unknown — see the
[Camera Research Brief](PRGR_Camera_Research_Brief.md).

---

## The short version

> A Raspberry Pi 5 with a high-speed camera (spin) and three Doppler radars (speed, launch
> angle, club path) measures a golf shot and shows the numbers on a touchscreen. The
> software foundation and UI are built and working in simulation; the immediate focus is
> getting the radars operational, then fitting the camera geometry around the radars' real
> accurate range.
