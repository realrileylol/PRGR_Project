# PRGR DIY Golf Launch Monitor - Camera & Spin Research Brief

## Purpose
This document provides full context for researching camera module options and golf ball spin detection strategies for a DIY golf launch monitor. The goal is to determine: (1) whether proposed replacement camera modules are suitable, (2) what golf balls can be used for spin measurement, and (3) whether spin can be measured on ANY ball without special markings.

---

## 1. Current System Architecture

### Hardware
- **Platform**: Raspberry Pi 5 (aarch64)
- **Display**: 800x480 touchscreen
- **Two cameras co-located 7-8 feet (2133-2438mm) behind the ball**
- Modeled after the Rapsodo MLM2 Pro (Impact Vision + Shot Vision architecture)

### Camera 0 - Impact/Spin Camera (current)
- **Sensor**: OV9281 (1/4" format, global shutter)
- **Native resolution**: 1280x800
- **Pixel pitch**: 3.0 um
- **Sensor dimensions**: 3.84mm x 2.40mm
- **Current operating mode**: 640x480 @ 180 FPS (sensor outputs 640x480, rotated 90° CW → **480x640 portrait display**)
- **Planned upgrade**: 1280x800 @ 120 FPS (rotated 90° CW → **800x1280 portrait display**)
- **Lens**: 12mm F1.2 M12 telephoto (ordered 8mm F1.4 IR-corrected replacement)
- **Connection**: CSI (MIPI) — both cameras are CSI-connected to the Raspberry Pi 5
- **Orientation**: Physically rotated 90 degrees clockwise (portrait mode). The sensor captures in landscape, software rotates to portrait. All coordinates must account for this rotation.
- **Purpose**: Capture ball spin/impact via telephoto optical zoom from 7-8 feet
- **Distance from ball**: 7-8 feet (co-located with trajectory cam)

### Camera 1 - Trajectory Camera (current)
- **Sensor**: OV9281 (identical sensor to Camera 0)
- **Current operating mode**: 640x400 @ 240 FPS in capture mode, 640x480 @ 180 FPS in preview mode
- **Display orientation**: Landscape (no rotation) — **640x400 as-is**
- **Lens**: 2.8mm wide-angle
- **Connection**: CSI (MIPI) — both cameras are CSI-connected to the Raspberry Pi 5
- **Purpose**: Track ball trajectory through the hitbox volume (1ft x 1ft x 1ft at 7-8ft distance)

### Ball Size at Camera Distance (Pinhole Camera Model)
Formula: `pixel_diameter = (ball_diameter_mm * focal_length_mm) / (distance_mm * pixel_pitch_mm)`

- Golf ball diameter: 42.67mm
- Pixel pitch: 3.0um = 0.003mm

**Impact cam with current 12mm lens @ 640x480 (rotated to 480x640 portrait):**
- At 7ft (2133mm): ~80 pixels diameter
- At 8ft (2438mm): ~70 pixels diameter

**Impact cam with incoming 8mm lens @ 1280x800 (rotated to 800x1280 portrait, planned upgrade):**
- At 7ft: ~53 pixels diameter  
- At 8ft: ~46 pixels diameter

**Trajectory cam (2.8mm lens) @ 640x400 landscape:**
- At 7ft: ~19 pixels diameter
- At 8ft: ~16 pixels diameter

---

## 2. Proposed Replacement Camera Modules (from vendor)

Both modules are manufactured by **ShenZhen HongJia Precision Imaging Co., Ltd.** (cammodule.com.cn)

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
| **Notes** | This is a FISHEYE lens module (210 degree FOV). The lens would need to be replaced with an M12 telephoto for spin use. Sensor is larger (1/2.6") than OV9281 (1/4"). |

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
| **Notes** | This is essentially an OV9281-equivalent (same resolution, same pixel size, same 1/4" sensor). The lens is a 2.88mm wide-angle, very close to our current 2.8mm trajectory cam lens. This would be a direct trajectory camera replacement. Achieves 210fps at lower resolutions (640x400) which beats our current 180fps. |

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

### Trajectory Tracking
- Kalman filter with 4-state model (x, y, velocity_x, velocity_y)
- Ball zone state machine: NO_BALL -> BALL_IN_ZONE -> STABLE -> READY -> IMPACT_DETECTED

### Spin Detection Status
- **NOT YET IMPLEMENTED** as actual spin measurement
- Camera 0 captures high-FPS frames of the ball at impact
- Y-channel (luma) extraction exists but spin analysis (RPM, axis) is not coded
- Spin value in the UI is currently simulated (random 5800-6700 rpm for testing)
- The system stores spin RPM in shot history but it's placeholder data

### Current Ball Size Thresholds
- Detector min radius: 4-5 pixels
- Detector max radius: 15-50 pixels (configurable)
- These are tuned for the trajectory camera (small ball at distance with wide-angle lens)
- Impact camera would see a much larger ball image (50-80 pixels with telephoto)

---

## 4. Key Questions for Research

### Camera Module Selection
1. Is the QQSJ-1356 (1/2.6" sensor, 1920x1200, 120fps) worth using as the impact/spin camera? Its larger sensor gives more pixels on target, but would require an M12 lens swap (the stock 210-degree fisheye is useless for this).
2. Is the QQSJ-8967 (1/4" sensor, 1280x800, 210fps at 640x400) a good trajectory camera replacement? It matches the OV9281 specs almost exactly but achieves higher FPS at lower resolutions.
3. What would the ball pixel diameter be with the QQSJ-1356 sensor + an 8mm or 12mm M12 lens at 7-8 feet? (Need to know the actual pixel pitch and sensor format to calculate.)
4. Does the QQSJ-1356 use the same OV9281 sensor or a different one (like SC2210 or similar)? The 1/2.6" format and 1920x1200 resolution suggest it may be a different sensor entirely.

### Ball & Spin Detection Strategy
5. **Can spin be measured on ANY golf ball (no stickers, no special markings)?** What methods exist?
   - Logo tracking (Titleist logo, number, alignment line)
   - Dimple pattern matching / optical flow
   - Machine learning approaches
6. **TaylorMade TP5/TP5x Pix pattern balls** - are the built-in geometric patterns on Pix balls sufficient for spin tracking? How many pixels of ball diameter are needed to resolve them?
7. **Callaway Triple Track** - are the alignment lines sufficient for spin axis detection?
8. **RPT (Rapsodo) dotted balls** - these are specifically designed for launch monitors. Are they the gold standard? Can we replicate the dot pattern with stickers?
9. **DIY sticker approach** - what size, color, and pattern of stickers would work? How many are needed? Where on the ball?
10. **Minimum pixel requirements** - how many pixels of ball diameter are needed for reliable spin measurement using:
    - Logo tracking only
    - Dimple pattern matching
    - Custom dot/sticker markers
    - High-contrast geometric patterns (Pix-style)

### Physics & Constraints
- Camera distance: fixed at 7-8 feet (2133-2438mm) behind the ball
- Exposure time: 100-300 microseconds (need F1.2-F1.4 for indoor lighting)
- The spin camera sees the ball BEFORE impact (at address) and for a few frames DURING/AFTER impact
- Ball speed after impact: 100-170 mph for a typical iron shot
- At 130 mph ball speed and 180 FPS, the ball moves approximately 1.2 inches per frame — very limited frames to capture post-impact spin
- Higher FPS = more frames during the critical spin-visible window

### Ideal Specs Wish List (for the spin/impact camera)
- Global shutter (mandatory — no rolling shutter artifacts at high speed)
- 1280x800 or higher resolution
- 120+ FPS at full resolution (ideally 180+)
- 3.0um or larger pixel pitch (better low-light sensitivity)
- Compatible with M12 lens mount (so we can use telephoto lenses)
- USB or CSI interface to Raspberry Pi 5
- F1.2-F1.4 lens aperture for microsecond exposures under indoor lighting

---

## 5. Reference Architecture (Rapsodo MLM2 Pro)

The MLM2 Pro uses a similar dual-camera + radar design:
- **Impact Vision camera**: Telephoto lens (estimated 6-8mm), captures ball at impact for spin
- **Shot Vision camera**: Wide-angle lens, captures trajectory through detection volume
- Both cameras co-located at approximately 6.5-8.5 feet from the ball
- Uses **RPT (Rapsodo Precision Technology) dotted balls** for spin measurement
- Likely uses OV9281 or similar global shutter sensor
- NIR (850-940nm) illumination suspected for consistent lighting
- Sensor fusion with 24GHz Doppler radar for velocity

The MLM2 Pro REQUIRES RPT-dotted balls for spin data. Without them, it reports "N/A" for spin metrics. This suggests that even Rapsodo couldn't reliably measure spin from unmarked balls at this price point.

---

## 6. Summary of What I Need From This Research

1. **Camera decision**: Should I buy the QQSJ-1356, the QQSJ-8967, or something else entirely? Or stick with my current OV9281 + new 8mm lens?
2. **Ball strategy**: Can I realistically measure spin on unmarked balls, or do I need special balls/stickers? What's the minimum viable approach?
3. **Pixel budget**: Given my camera distance (7-8ft) and lens options (8mm or 12mm), how many pixels do I need on the ball for each spin detection method?
4. **Frame rate vs resolution tradeoff**: Is it better to have 1920x1200 @ 120fps or 1280x800 @ 180fps for spin detection?
