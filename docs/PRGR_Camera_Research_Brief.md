# PRGR DIY Golf Launch Monitor - Camera & Spin Research Brief

## Purpose
This document provides full context for researching camera module options and golf ball
spin detection strategies for a DIY golf launch monitor. The goal is to determine:
(1) whether proposed replacement camera modules are suitable, (2) what golf balls can be
used for spin measurement, and (3) whether spin can be measured on ANY ball without
special markings.

> **Architecture note (updated 2026-07-01):** This project has moved from a
> **two-camera** design to a **single impact/spin camera + triple-radar** design. The
> trajectory/speed/angle job that a second wide-angle camera used to do is now handled by
> the radar array (OPS243-A + 2× K-LD7). The old two-camera material is retained at the
> bottom of this brief (Appendix) for reference, since some research questions and the
> pixel-budget math still draw on it. **The camera-to-ball distance is not yet fixed** —
> see the sequencing note below.

---

## 1. Current System Architecture

### Hardware
- **Platform**: Raspberry Pi 5 (aarch64, 8 GB)
- **Display**: Waveshare 5" DSI LCD, 800×480, 5-point capacitive touch
- **One camera** (impact/spin) behind the ball
- **Three Doppler radars** (OPS243-A + 2× K-LD7) for speed, launch angle, and club path
- Modeled after the Rapsodo MLM2 Pro (camera "Impact Vision" + radar sensor fusion)

### The impact/spin camera
- **Sensor**: OV9281 (1/4" format, global shutter, monochrome, 1 MP)
- **Native resolution**: 1280×800
- **Pixel pitch**: 3.0 µm
- **Sensor dimensions**: 3.84 mm × 2.40 mm
- **Operating modes**: preview 640×480 sensor → **480×640 portrait** @ 180 FPS; capture
  640×400 sensor → **400×640 portrait** @ 240 FPS. The sensor reads out in landscape;
  software rotates 90° CW to portrait. Portrait puts the **long (640 px) axis vertical**, so
  it covers more of the ball's climbing departure path — the ball stays in frame for more
  frames (a few extra ms of tracking) than a landscape orientation would allow.
- **Goal**: 240 FPS at the highest resolution that sustains it, in portrait orientation.
- **Lens**: 8 mm F1.2 IR-corrected M12 (replacing the earlier 12 mm telephoto). Confirmed
  specs: FOV **50° × 41° × 31°** (D×H×V), minimum object distance **0.2 m**, BFL 6.58 mm,
  7 elements / 6 groups, fixed iris, manual focus, −20 °C to +80 °C. The 31° vertical FOV
  and 0.2 m minimum focus bound how close the camera can sit and how much departure path it
  sees.
- **Connection**: CSI (MIPI) to the Raspberry Pi 5
- **Orientation**: physically rotated **90° clockwise** (portrait). The sensor captures in
  landscape; software rotates to portrait. All coordinates must account for this rotation.
- **Purpose**: capture ball spin/impact via the camera; radars handle speed/angle
- **Distance from ball**: **TBD — not yet validated (see below)**

### Why the distance is TBD (development sequence)
The physical geometry is being established **empirically, radar-first**, not guessed:

1. **Get the radars working** (OPS243-A + 2× K-LD7) and prove speed/angle/path readout.
2. **Establish the radars' maximum accurate range** — this becomes the anchor constraint.
3. **Introduce the impact camera** and work out how far the ball must be so that the ball's
   **pixel diameter** is large enough for spin detection, the FOV covers the departure
   path, and the distance is compatible with the radar's accurate range.
4. **Calibrate and measure** with real, fixed geometry.

> The **~5 ft** distance and **8 mm lens** pairing are the *starting hypothesis* for step 3,
> not a settled fact. The pixel-diameter numbers below are theoretical (pinhole model) and
> must be confirmed on hardware once the real distance is chosen.

### Ball size at camera distance (pinhole camera model)
Formula: `pixel_diameter = (ball_diameter_mm × focal_length_mm) / (distance_mm × pixel_pitch_mm)`

- Golf ball diameter: 42.67 mm
- Pixel pitch: 3.0 µm = 0.003 mm

**Impact cam with 8 mm lens (theoretical, OV9281 @ 3.0 µm):**

| Distance | Ball pixel diameter |
|---|---|
| 5 ft (1524 mm) | ~75 px |
| 6 ft (1829 mm) | ~62 px |
| 7 ft (2133 mm) | ~53 px |
| 8 ft (2438 mm) | ~47 px |

**Impact cam with 12 mm lens (earlier telephoto, for comparison):**

| Distance | Ball pixel diameter |
|---|---|
| 7 ft (2133 mm) | ~80 px |
| 8 ft (2438 mm) | ~70 px |

The closer the camera / longer the lens, the more pixels on the ball — but the smaller the
covered volume. This trade-off is exactly what step 3 above resolves.

---

## 2. Proposed Replacement Camera Modules (from vendor)

Both modules are manufactured by **ShenZhen HongJia Precision Imaging Co., Ltd.**
(cammodule.com.cn). These were evaluated during the two-camera era; the QQSJ-8967 was
originally a *trajectory-camera* candidate, which is now moot (radar does trajectory).
The QQSJ-1356 remains interesting as a potential **higher-resolution spin-camera upgrade**.

### Module A: QQSJ-1356

| Spec | Value |
|------|-------|
| **Sensor** | 1/2.6 inch CMOS, 2MP, Global Shutter |
| **Max Resolution** | 1920 x 1200 |
| **Pixel Size** | 3.0um x 3.0um |
| **Signal-to-Noise Ratio** | 37.71 dB |
| **Dynamic Range** | Linear: 62.65 dB, HDR: 92.65 dB |
| **Shutter Type** | Global Shutter |
| **Exposure** | Auto Exposure |
| **Frame Rates (MJPG)** | 640x480 @ 30fps, 1280x720 @ 120fps, 1920x1080 @ 120fps |
| **Frame Rates (YUY2/raw)** | 640x480 @ 30fps, 800x600 @ 20fps, 1280x720 @ 10fps, 1920x1080 @ 5fps |
| **Interface** | USB 2.0 (480 Mbps), 5-pin 1.25mm connector |
| **Operating Temp** | 0-50 C |
| **Dimensions** | 38mm x 38mm x 15.6mm |
| **Power** | 5.02V x 0.16A at 1080p/120fps MJPG |
| **Built-in Lens** | Focal length 1.47mm, FOV D:210 H:210 degrees, Distortion <15%, F/NO not specified, 650nm IR-cut filter |
| **Notes** | FISHEYE lens module (210 degree FOV). Lens would need replacing with an M12 telephoto for spin use. Sensor is larger (1/2.6") than OV9281 (1/4"). More pixels on target = potential spin-camera upgrade, but it is **USB, not CSI** — a consideration for the Pi 5 pipeline. |

### Module B: QQSJ-8967

| Spec | Value |
|------|-------|
| **Sensor** | 1/4 inch CMOS, Global Shutter |
| **Max Resolution** | 1280 x 800 |
| **Pixel Size** | 3.0um x 3.0um |
| **Shutter Type** | Global Shutter |
| **Exposure** | Auto Exposure |
| **Frame Rates (MJPG)** | 160x120 @ 210fps, 320x240 @ 210fps, 352x288 @ 210fps, 640x400 @ 210fps, 640x480 @ 210fps, 800x600 @ 120fps, 1024x768 @ 120fps, 1280x720 @ 120fps, 1280x800 @ 120fps |
| **Interface** | USB 2.0 (480 Mbps), 5-pin 1.0mm connector |
| **Operating Temp** | 0-50 C |
| **Dimensions** | 38mm x 38mm x 17.81mm |
| **Power** | 5.11V x 0.17A at 1280x800/120fps MJPG |
| **Built-in Lens** | Focal length 2.88mm, FOV D:74 H:65 V:45 degrees, Distortion <0.2%, F/2.2, 650nm IR-cut filter |
| **Notes** | Essentially an OV9281-equivalent. Was a trajectory-cam candidate — **no longer needed** now that radar handles trajectory. Kept here for completeness. |

---

## 3. Current Ball Detection Code Summary

### Detection Methods Implemented (C++ with OpenCV 4)
The system uses multi-method detection with confidence scoring:

1. **Hough Circle Transform** (`cv::HoughCircles` with HOUGH_GRADIENT)
   - Canny threshold: 100, Accumulator: 15
   - Searches for circles matching expected ball radius range

2. **Blob Detection** (`cv::SimpleBlobDetector`)
   - Circularity filter: minimum 0.7
   - Convexity filter: minimum 0.8
   - Inertia ratio: minimum 0.6
   - Area filtered to expected ball size range

3. **Contour Finding** (`cv::findContours` + `cv::minEnclosingCircle`)
   - Otsu auto-thresholding
   - Circularity check: `4 * pi * area / perimeter^2`

4. **Background Subtraction** (MOG2)
   - `cv::createBackgroundSubtractorMOG2(500, 16, true)`
   - Frame differencing with threshold of 25
   - Morphological cleanup (open/close)

5. **Auto Mode**: Tries all three primary methods and picks highest confidence

### Trajectory Tracking (in-frame, camera-side)
- Kalman filter with 4-state model (x, y, velocity_x, velocity_y)
- Ball zone state machine: NO_BALL -> BALL_IN_ZONE -> STABLE -> READY -> IMPACT_DETECTED
- Note: full **shot** trajectory/speed/angle now comes from radar; the camera's tracking is
  for in-frame ball detection and the impact trigger, not the flight solution.

### Spin Detection Status
- **NOT YET IMPLEMENTED** as actual spin measurement
- The impact camera captures high-FPS frames of the ball at impact
- Y-channel (luma) extraction exists but spin analysis (RPM, axis) is not coded
- Spin value in the UI is currently simulated (random rpm for testing)
- The system stores spin RPM in shot history but it's placeholder data

### Current Ball Size Thresholds
- Detector min radius: 4-5 pixels
- Detector max radius: 15-50 pixels (configurable)
- These were tuned for a small ball at distance; the impact camera at close range with the
  8 mm lens will see a much larger ball (~47–75 px depending on final distance), so these
  thresholds will need re-tuning once the working distance is set.

---

## 4. Key Questions for Research

### Camera Module Selection
1. Is the QQSJ-1356 (1/2.6" sensor, 1920x1200, 120fps) worth using as the impact/spin
   camera upgrade? Its larger sensor gives more pixels on target, but it's USB (not CSI)
   and would require an M12 lens swap (the stock 210° fisheye is useless for this).
2. What would the ball pixel diameter be with the QQSJ-1356 sensor + an 8 mm or 12 mm M12
   lens at the eventual working distance?
3. Does the QQSJ-1356 use the same OV9281 sensor or a different one (e.g. SC2210)? The
   1/2.6" format and 1920x1200 resolution suggest a different sensor entirely.
4. Is there a **CSI** global-shutter module with more resolution than the OV9281 that can
   still hit 240 FPS in a windowed mode? (CSI is preferred to keep the existing pipeline.)

### Ball & Spin Detection Strategy
5. **Can spin be measured on ANY golf ball (no stickers, no special markings)?** What
   methods exist? (Logo tracking, dimple-pattern optical flow, ML approaches.)
6. **TaylorMade TP5/TP5x Pix pattern balls** — are the built-in geometric patterns
   sufficient for spin tracking? How many pixels of ball diameter are needed to resolve
   them?
7. **Callaway Triple Track** — are the alignment lines sufficient for spin axis detection?
8. **RPT (Rapsodo) dotted balls** — the gold standard for launch monitors? Can we replicate
   the dot pattern with stickers?
9. **DIY sticker approach** — what size, color, and pattern of stickers would work? How many
   are needed and where on the ball?
10. **Minimum pixel requirements** — how many pixels of ball diameter are needed for
    reliable spin measurement via logo tracking, dimple matching, custom dots, or Pix-style
    high-contrast patterns?

### Physics & Constraints
- **Camera distance**: TBD — determined empirically after radar range is known (not the
  old fixed 7–8 ft assumption).
- Exposure time: ~100–300 µs (need F1.2–F1.4 for indoor lighting)
- The spin camera sees the ball BEFORE impact (at address) and for a few frames
  DURING/AFTER impact
- Ball speed after impact: ~100–170 mph for a typical iron shot
- At 130 mph ball speed and 240 FPS, the ball moves ~0.9 inches per frame — more frames in
  the spin-visible window than at 180 FPS
- Higher FPS = more frames during the critical spin-visible window (**240 FPS is the target**)

### Ideal Specs Wish List (for the spin/impact camera)
- Global shutter (mandatory — no rolling shutter artifacts at high speed)
- Highest resolution possible while sustaining 240 FPS (portrait orientation)
- **240 FPS is the target frame rate** — non-negotiable for spin capture
- 3.0 µm or larger pixel pitch (better low-light sensitivity)
- M12 lens mount compatibility (for telephoto lenses)
- CSI (MIPI) interface to the Raspberry Pi 5 preferred
- F1.2–F1.4 lens aperture for microsecond exposures under indoor lighting

---

## 5. Reference Architecture (Rapsodo MLM2 Pro)

The MLM2 Pro uses a camera + radar design:
- **Impact Vision camera**: telephoto lens (est. 6–8 mm), captures ball at impact for spin
- **Shot Vision camera**: wide-angle lens, captures trajectory through the detection volume
- Both cameras co-located ~6.5–8.5 ft from the ball
- Uses **RPT (Rapsodo Precision Technology) dotted balls** for spin measurement
- Likely uses OV9281 or similar global-shutter sensor
- NIR (850–940 nm) illumination suspected for consistent lighting
- Sensor fusion with 24 GHz Doppler radar for velocity

The MLM2 Pro REQUIRES RPT-dotted balls for spin data; without them it reports "N/A" for
spin. This suggests even Rapsodo couldn't reliably measure spin from unmarked balls at this
price point — a key data point for our own ball strategy.

> **PRGR difference:** the MLM2 Pro uses *two* cameras and *one* radar. PRGR flips the
> emphasis — *one* camera (spin) and *three* radars (speed + vertical angle + horizontal
> path) — so more of the flight solution comes from radar and the single camera can focus
> entirely on spin.

---

## 6. Summary of What I Need From This Research

1. **Camera decision**: stick with the current OV9281 + 8 mm lens, or upgrade to the
   QQSJ-1356 (or another higher-res global-shutter module) for the spin camera?
2. **Ball strategy**: can I realistically measure spin on unmarked balls, or do I need
   special balls/stickers? What's the minimum viable approach?
3. **Pixel budget**: given the eventual camera distance and lens, how many pixels do I need
   on the ball for each spin-detection method?
4. **Frame rate vs resolution tradeoff**: 240 FPS is the target. What's the highest
   resolution achievable at 240 FPS for spin detection? Is 640×480 @ 240 fps enough, or is a
   different sensor needed for more resolution at that frame rate?

---

## Appendix — Legacy Two-Camera Design (reference only)

> ⚠️ _Superseded. Retained because some pixel-budget math and module notes above reference
> it. This is **not** the current architecture._

_The original design used **two co-located cameras 7–8 ft (2133–2438 mm) behind the ball**,
mirroring the MLM2 Pro's Impact Vision + Shot Vision split:_

- _**Camera 0 — Impact/Spin:** OV9281, 12 mm F1.2 M12 telephoto, 90° CW portrait, 640×480 @
  180 FPS (→ 480×640 portrait). Captured spin via optical zoom from 7–8 ft._
- _**Camera 1 — Trajectory:** OV9281, 2.8 mm wide-angle, landscape, 640×400 @ 240 FPS.
  Tracked the ball through a **1 ft × 1 ft × 1 ft hitbox** at 7–8 ft._

_This was replaced by the single-camera + triple-radar design because the radar array
covers speed and angles more directly than a second camera, simplifying the build, wiring,
and calibration._

_In that design a **3D "hitbox"** — a 1 ft × 1 ft × 1 ft volume located **7–8 ft** from the
ball (near face 7 ft / 2133.6 mm, far face 8 ft / 2438.4 mm, origin at the ball at address)
— was the detection zone the trajectory camera had to cover._

> 📌 _**Unreconciled constants:** `include/HardcodedConstants.h` still contains the
> two-camera values — `SPIN_CAM_FOCAL_LENGTH_MM = 12.0`, `TRAJ_CAM_FOCAL_LENGTH_MM = 2.8`,
> and the `HITBOX_NEAR_FT = 7.0` / `HITBOX_FAR_FT = 8.0` hitbox — which conflict with the
> current single-camera, 8 mm, ~5 ft design. Per project rules, `HardcodedConstants.h` is
> **not** modified without explicit approval, so this mismatch is flagged here rather than
> silently changed. Decide later whether to (a) update the constants to the single-camera
> 5 ft design, or (b) keep them if the two-camera idea is revived._
