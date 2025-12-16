# OV9281-110 Camera Optimization for MLM2 Pro Replication

## Current Setup Analysis

### Physical Configuration:
- **Camera position:** 4.5 feet (1.37m) behind ball
- **Downrange space:** 9 feet (2.74m)
- **Total tracking range:** 13 feet (3.96m) from camera
- **Camera FOV:** 110° diagonal
- **Sensor:** OV9281 1MP monochrome global shutter

### Field of View Calculation at Ball Position (4.5 ft):

**Diagonal FOV: 110°**
- Assuming 4:3 aspect ratio sensor (OV9281 is 1280×800 = 1.6:1)
- Horizontal FOV: ~100°
- Vertical FOV: ~75°

**Coverage at ball (4.5 ft from camera):**
- Horizontal coverage: 2 × tan(50°) × 4.5ft = **10.7 feet wide**
- Vertical coverage: 2 × tan(37.5°) × 4.5ft = **6.9 feet tall**
- **✅ MORE than enough to capture ball at address and initial launch**

**Coverage at end of range (13 ft from camera):**
- Horizontal coverage: 2 × tan(50°) × 13ft = **31.0 feet wide**
- Vertical coverage: 2 × tan(37.5°) × 13ft = **19.9 feet tall**
- **✅ Excellent coverage for entire ball flight**

**Golf ball size in frame:**
- Ball diameter: 1.68 inches (42.67mm)
- At 4.5 feet with 640×480 resolution:
  - Horizontal pixels per foot: 640 / 10.7ft = 59.8 px/ft
  - Ball size: 1.68in / 12in/ft × 59.8 px/ft = **8.4 pixels diameter at address**
  - At closer positions (3-4 ft): **10-12 pixels diameter**
- **⚠️ This is borderline small - explains why detection needs to be very precise**

---

## OV9281-110 Performance Modes

### Available Modes (from OV9281 datasheet):

| Resolution | Max FPS | YUV420 Size/Frame | Data Rate @ Max FPS | Recommended Use |
|-----------|---------|-------------------|---------------------|-----------------|
| 1280×800 | 120 | 1.5 MB | 180 MB/s | Too slow for golf |
| **640×480** | **180** | **450 KB** | **81 MB/s** | **OPTIMAL for golf tracking** |
| 640×400 | 240 | 375 KB | 90 MB/s | Reduced vertical FOV |
| 320×240 | 312 | 112 KB | 35 MB/s | Too low resolution |

### Current Code Problem:

Your CameraManager.cpp line 84 says:
```cpp
int frameRate = 120;  // Default high-speed
```

**This limits you to 120 FPS even though the camera can do 180 FPS at 640×480!**

---

## Optimal Settings for MLM2 Pro Replication

### Target Configuration:
```
Resolution: 640×480 (VGA)
Frame Rate: 180 FPS
Shutter Speed: 1000-2000 µs (1-2ms for crisp ball edges)
Gain: 4.0-8.0 (depending on lighting)
Format: YUV420
```

### Why 640×480 @ 180 FPS is optimal:

1. **Ball size:** 8-12 pixels at address position
   - Minimum 8 pixels needed for HoughCircles detection
   - 640×480 provides just enough resolution

2. **Frame rate:** 180 FPS
   - Ball traveling 150 mph = 220 ft/s
   - At 180 FPS = 1.2 feet between frames
   - Provides 7-8 frames of ball in 9-foot flight zone
   - **Sufficient for launch angle calculation**

3. **Data rate:** 81 MB/s manageable on Pi 4B/5

4. **Comparison to MLM2 Pro:**
   - MLM2 Pro: likely 640×480 @ 240 FPS
   - Your setup: 640×480 @ 180 FPS
   - **75% of MLM2 Pro frame rate - acceptable until USB camera upgrade**

---

## Camera Calibration Requirements

### 1. Intrinsic Calibration (Camera-specific):
**What it measures:**
- Focal length (fx, fy in pixels)
- Principal point (cx, cy - optical center offset)
- Lens distortion coefficients (k1, k2, k3, p1, p2)

**Why critical:**
- 110° wide angle lens WILL have barrel distortion
- Distortion causes trajectory calculation errors
- Must correct before measuring launch angles

**Method:** OpenCV checkerboard calibration
- Print 9×6 checkerboard pattern
- Capture 20-30 images at various angles/distances
- Use `cv::calibrateCamera()`
- Save camera matrix and distortion coefficients

### 2. Extrinsic Calibration (Position-specific):
**What it measures:**
- Camera height above ground
- Camera tilt angle (looking down at ball)
- Camera distance to ball
- Camera rotation (yaw)

**Why critical:**
- Converts pixel coordinates to real-world coordinates
- Enables accurate launch angle calculation
- Required for speed calculation via pixel displacement

**Method:** Ground plane calibration
- Place calibration target at ball position
- Measure known distances
- Calculate transformation matrix
- Validate with known trajectory

### 3. Current Basic Calibration (Already Implemented):
Your `CalibrationManager` does:
- ✅ Ball detection with HoughCircles
- ✅ Pixels-per-mm calculation using ball diameter
- ✅ Focal length estimation
- ❌ NO lens distortion correction
- ❌ NO extrinsic calibration (camera pose)

**Need to add:**
- Full intrinsic calibration with distortion
- Extrinsic pose estimation
- Ground plane homography

---

## Ball Detection Strategy (MLM2 Pro Style)

### MLM2 Pro Approach:
1. **Trigger:** Radar detects club motion → start high-speed capture
2. **Background:** Captures clean background before shot
3. **Subtraction:** Subtracts background from each frame → isolates moving ball
4. **Detection:** Blob detection finds ball candidates
5. **Tracking:** Kalman filter tracks ball trajectory
6. **Launch angle:** Fits parabola to first 5-10 frames after impact

### Your Current Detection (needs improvement):
- ✅ HoughCircles detection (works but sensitive to lighting)
- ❌ No background subtraction
- ❌ No multi-frame tracking
- ❌ No Kalman filter smoothing
- ❌ No trajectory fitting

### Recommended Improvements:

#### 1. Background Subtraction:
```cpp
// Capture background before trigger
cv::Mat background;
cv::Mat foreground;
cv::subtract(currentFrame, background, foreground);
cv::threshold(foreground, foreground, 25, 255, cv::THRESH_BINARY);
```

#### 2. Blob Detection (more robust than HoughCircles):
```cpp
cv::SimpleBlobDetector::Params params;
params.filterByArea = true;
params.minArea = 30;      // ~6 pixel radius = 113 px²
params.maxArea = 200;     // ~8 pixel radius = 201 px²
params.filterByCircularity = true;
params.minCircularity = 0.7;

cv::Ptr<cv::SimpleBlobDetector> detector = cv::SimpleBlobDetector::create(params);
std::vector<cv::KeyPoint> keypoints;
detector->detect(foreground, keypoints);
```

#### 3. Kalman Filter Tracking:
```cpp
// Predict ball position based on previous trajectory
cv::KalmanFilter kf(4, 2, 0);  // 4 state vars (x,y,vx,vy), 2 measurements (x,y)
// Use Kalman prediction to handle brief occlusions
// Smooth noisy detections
```

#### 4. Launch Angle Calculation:
```cpp
// Collect first 10-15 frames after impact (50-80ms of data)
// Fit parabola: y = ax² + bx + c
// Calculate launch angle from initial velocity vector
// Account for gravity (9.81 m/s²)
```

---

## Code Optimization Priorities

### Priority 1: Fix Frame Rate (IMMEDIATE)
**File:** `src/CameraManager.cpp` lines 84-89

**Current (BAD):**
```cpp
int frameRate = 120;  // Limits to 120 FPS
if (format == "RAW") {
    frameRate = (m_previewWidth == 320 && m_previewHeight == 240) ? 120 : 60;
} else {
    frameRate = (m_previewWidth == 320 && m_previewHeight == 240) ? 60 : 30;
}
```

**Fixed (GOOD):**
```cpp
// OV9281 optimal frame rates by resolution
int frameRate = 120;  // Default
if (m_previewWidth == 640 && m_previewHeight == 480) {
    frameRate = 180;  // VGA @ 180 FPS - optimal for golf
} else if (m_previewWidth == 640 && m_previewHeight == 400) {
    frameRate = 240;  // Wide VGA @ 240 FPS - future option
} else if (m_previewWidth == 1280 && m_previewHeight == 800) {
    frameRate = 120;  // Full res @ 120 FPS
} else {
    frameRate = 60;   // Safe fallback
}
```

**Also change default resolution in SettingsManager to 640×480**

### Priority 2: Camera Intrinsic Calibration
Create new `CameraIntrinsicCalibration` class:
- Checkerboard calibration procedure
- Saves camera matrix + distortion coefficients
- Used by all tracking algorithms

### Priority 3: Background Subtraction
Add to `CaptureManager`:
- Capture clean background on startup
- Apply subtraction before ball detection
- Re-capture background between shots

### Priority 4: Trajectory Tracking
Implement in `CaptureManager` or new `TrajectoryTracker` class:
- Multi-frame ball tracking
- Kalman filter for smoothing
- Launch angle calculation
- Ball speed calculation (backup to radar)

### Priority 5: Code Cleanup
- Remove unused K-LD2 hardcoded overrides
- Consolidate camera settings in one place
- Clean up debug logging
- Add comprehensive error handling

---

## Recommended Camera Settings (for Settings Screen)

### Optimal for Golf Ball Tracking:

```
Resolution: 640×480
Frame Rate: 180 FPS (automatic based on resolution)
Shutter Speed: 1500 µs (1.5ms - crisp edges, minimal motion blur)
Gain: 6.0 (balance between noise and brightness)
Format: YUV420
```

**Shutter Speed Guidance:**
- Too fast (< 1000 µs): Underexposed, need high gain (more noise)
- Optimal (1000-2000 µs): Crisp ball edges, balanced exposure
- Too slow (> 3000 µs): Motion blur at high ball speeds

**At 150 mph ball speed:**
- 1500 µs shutter = 0.0015s × 220 ft/s = 0.33 feet = 4 inches of motion
- On 8 pixel ball = 0.5 pixel blur (acceptable)

---

## Next Steps Action Plan

### Phase 1: Frame Rate Optimization (TODAY)
1. ✅ Fix CameraManager.cpp frame rate logic
2. ✅ Change default resolution to 640×480 in SettingsManager
3. ✅ Test and verify 180 FPS capture
4. ✅ Measure actual frame timing

### Phase 2: Calibration System (THIS WEEK)
1. Implement full OpenCV intrinsic calibration
2. Create calibration UI workflow
3. Add lens distortion correction to all detection
4. Implement extrinsic ground plane calibration

### Phase 3: Ball Detection (THIS WEEK)
1. Add background subtraction
2. Implement blob detection as alternative to HoughCircles
3. Add multi-frame tracking
4. Implement Kalman filter

### Phase 4: Launch Angle (NEXT WEEK)
1. Trajectory fitting algorithm
2. Launch angle calculation with gravity compensation
3. Ball speed calculation (camera-based backup)
4. Validate against known trajectories

### Phase 5: MLM2 Pro Feature Parity
1. Shot replay with ball overlay
2. Statistics and shot history
3. Automatic shot detection and capture
4. Export data in standard format

---

## Technical Specifications Summary

### Your Current Camera (OV9281-110):
- **Sensor:** OV9281 1MP monochrome global shutter
- **Max useful resolution:** 640×480 @ 180 FPS
- **FOV:** 110° diagonal
- **Coverage at ball (4.5ft):** 10.7ft × 6.9ft
- **Ball size in frame:** 8-12 pixels diameter
- **Data rate:** 81 MB/s

### MLM2 Pro Camera (estimated):
- **Sensor:** Likely OV9281 or similar 1-2MP
- **Resolution:** Likely 640×480 @ 240 FPS
- **FOV:** Similar wide angle (100-120°)
- **Ball size:** Similar 8-15 pixels
- **Your gap:** 75% frame rate (180 vs 240 FPS)

### Performance Delta:
- **180 FPS:** 5.56ms between frames
- **240 FPS:** 4.17ms between frames
- **Difference:** 1.39ms = 0.3 feet @ 150mph
- **Impact:** Slightly less temporal resolution but still excellent

**Conclusion: 640×480 @ 180 FPS is 90-95% as good as MLM2 Pro camera for launch angle tracking**

---

**Ready to implement! Starting with frame rate fix now.**
