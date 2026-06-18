# PRGR Launch Monitor - Calibration Roadmap

## ✅ STEP 1 COMPLETE: Camera Alignment & Hardcoded Constants

### What We've Built

#### 1. **CameraAlignmentScreen.qml** - Physical Alignment Tool
Located: `screens/CameraAlignmentScreen.qml`

**Features:**
- ✓ Live camera preview with real-time FPS counter
- ✓ GREEN crosshair (vertical + horizontal) for precise alignment
- ✓ Optional grid overlay (rule of thirds)
- ✓ Optional hitbox guide (shows 1ft × 1ft target zone)
- ✓ Toggle buttons to show/hide each guide
- ✓ Accessible from Calibration Screen → "🎯 Alignment" button

**How to Use:**
1. Place camera in approximate position
2. Open Calibration Screen
3. Click "🎯 Alignment" button
4. Adjust camera physically until:
   - **Spin camera**: Ball center aligns with crosshair
   - **Trajectory camera**: Target line (ball → target) aligns with vertical crosshair
5. Lock camera in place (tighten mounts)
6. Click "Alignment Complete →"

#### 2. **HardcodedConstants.py** - Python Constants
Located: `HardcodedConstants.py`

**Never-Changing Values:**
- Golf ball diameter: 42.67mm (1.68")
- OV9281 sensor specs: 1280×800, 3µm pixel size
- Camera focal lengths: 12mm (spin), 2.8mm (trajectory)
- **Hitbox: 7ft to 8ft, 1ft × 1ft** (304.8mm × 304.8mm × 304.8mm)
- World coordinate origin: Ball at address position

**Key Insights from Constants:**
```
Ball Size in Pixels:
  Spin camera @ 1.6ft - 5ft:  341px - 114px (excellent for pattern detection)
  Traj camera @ 7-8ft:        19px - 16px   (small but detectable)

Hitbox Volume: 1 cubic foot (7-8ft range, 1ft × 1ft cross-section)
```

**Usage:**
```python
from HardcodedConstants import *

# Check if ball is in hitbox
in_box = is_ball_in_hitbox(x_mm, y_mm, z_mm)

# Get expected ball size
expected_px = ball_pixel_diameter_at_distance(distance_mm, focal_length_mm)
```

#### 3. **HardcodedConstants.h** - C++ Constants
Located: `include/HardcodedConstants.h`

Same constants as Python version, for C++ modules:
```cpp
#include "HardcodedConstants.h"

// Check hitbox
bool inBox = isBallInHitbox(x_mm, y_mm, z_mm);

// Expected ball size
double expectedPx = ballPixelDiameterAtDistance(distance_mm, focal_length_mm);
```

---

## 🔄 NEXT STEPS: Complete Calibration Flow

### Step 2: Physical Measurements (TODO)

**What:** Record camera positions in 3D space (extrinsic parameters)

**Measurements Needed:**
- Trajectory camera height above ground
- Trajectory camera distance behind ball
- Trajectory camera horizontal offset from target line
- Trajectory camera tilt angle (pitch/yaw/roll)
- Spin camera height, distance, offset, tilt

**Storage:** Create `CalibrationData.json` or extend `SettingsManager`

**UI:** Create setup wizard screen with:
- Visual diagrams showing what to measure
- Input fields for each measurement
- Validation (check against min/max constraints from constants)
- Save permanently (only re-run if camera moves)

### Step 3: Intrinsic Camera Calibration (Partially Exists)

**What:** Checkerboard calibration to get:
- Focal length (pixels) - exact value, not manufacturer nominal
- Principal point (optical center) - may not be image center
- Distortion coefficients - correct barrel/pincushion distortion

**Status:** `CalibrationScreen.qml` already exists, needs:
- Integration with alignment workflow
- Save/load calibration results
- Validation that calibration is accurate

**When:** After alignment + physical measurements (camera in final position)

### Step 4: Hitbox Visualization & Validation (TODO)

**What:** Project 3D hitbox onto 2D camera view using:
- Hardcoded hitbox dimensions (from constants)
- Calibrated camera intrinsics (focal length, distortion)
- Measured camera extrinsics (position, rotation)

**Result:** User sees exact hitbox overlay on live camera feed

**Validation:** Place ball at known distances (7ft, 7.5ft, 8ft) and verify overlay matches

### Step 5: Ball Detection Tuning (Partially Exists)

**What:** Adjust detection thresholds while watching hitbox overlay

**Tools Needed:**
- Live detection overlay (circles around detected balls)
- Sliders for brightness, sensitivity, Hough parameters
- "Good detection" indicator when ball in hitbox

**Status:** `ball_tracker.py` exists, needs UI integration

---

## 🎯 Professional MLM2 Pro-Style Workflow

### First-Time Setup Wizard (Recommended Flow)

```
┌─────────────────────────────────────────┐
│  Welcome to PRGR Launch Monitor Setup  │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  Step 1: Camera Alignment               │
│  - Shows live view with crosshairs      │
│  - Instructs user to align physically   │
│  ✓ IMPLEMENTED                          │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  Step 2: Physical Measurements          │
│  - Height, distance, angle inputs       │
│  - Visual diagrams                      │
│  ⚠ TODO                                  │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  Step 3: Checkerboard Calibration       │
│  - Print checkerboard instructions      │
│  - Capture 20 frames at angles          │
│  - Shows progress: 12/20 captured       │
│  🔧 EXISTS, needs integration            │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  Step 4: Hitbox Verification            │
│  - Live view with hitbox overlay        │
│  - Place ball at 7ft / 8ft markers      │
│  - Validate detection                   │
│  ⚠ TODO                                  │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  Step 5: Detection Tuning (Optional)    │
│  - Adjust sensitivity sliders           │
│  - Test ball detection                  │
│  ⚠ TODO                                  │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  ✓ Setup Complete - Ready to Hit Shots │
└─────────────────────────────────────────┘
```

### Re-Calibration Options (After Initial Setup)

Users should be able to re-run:
- **Environment calibration** (lighting changed): Detection tuning only
- **Camera moved**: Alignment + measurements + checkerboard
- **Full recalibration**: All steps (nuclear option)

---

## 📁 Files Created Today

```
PRGR_Project/
├── screens/
│   ├── CameraAlignmentScreen.qml       ← NEW (Step 1 alignment UI)
│   └── CalibrationScreen.qml           ← MODIFIED (added alignment button)
├── include/
│   └── HardcodedConstants.h            ← NEW (C++ constants)
├── HardcodedConstants.py               ← NEW (Python constants)
└── CALIBRATION_ROADMAP.md              ← NEW (this file)
```

---

## 🔧 Integration TODOs

### High Priority
1. **Create SetupWizard.qml** - Multi-page first-run setup
2. **Physical measurements UI** - Input fields + diagrams
3. **Hitbox projection math** - 3D → 2D transformation
4. **Save/load calibration data** - Persist extrinsics + intrinsics

### Medium Priority
5. **Dual camera support** - Switch between spin/traj cameras in alignment
6. **Validation checks** - Warn if measurements outside valid ranges
7. **Reset calibration** - Factory reset option

### Nice to Have
8. **Calibration quality score** - "Good" / "Needs improvement"
9. **Troubleshooting guide** - Automated diagnosis
10. **Video tutorials** - Built-in help screens

---

## 🚨 CRITICAL QUESTIONS STILL NEEDED

Before continuing to Step 2, confirm:

1. **Hitbox origin:** Is 7ft measured from:
   - ❓ Ball position at address (currently assumed)
   - ❓ Front of the device housing
   - ❓ Trajectory camera lens position

2. **Camera identification:** Which camera watches the hitbox?
   - ✓ Assumed: USB OV9281 (2.8mm, 240fps) = trajectory camera
   - ✓ Assumed: CSI OV9281 (12mm, 180fps) = spin camera
   - ❓ Confirm this is correct?

3. **Coordinate handedness:**
   - ✓ Assumed: Right-handed (X=right, Y=up, Z=forward)
   - ❓ Or should Z be negative toward target?

**Once answered, we can finalize Step 2 (measurements UI).**

---

## 🎓 Key Learnings

### Why This Architecture Works

**Hardcoded Layer (Constants):**
- Defines the "ideal world" - physics, golf rules, hardware specs
- Never changes unless you rebuild the system
- Enables consistent calculations across all modules

**Calibration Layer (User Data):**
- Maps real-world cameras to ideal world
- Can be re-run when environment changes
- Stored in JSON, easy to backup/restore

**Detection Layer (Runtime):**
- Uses hardcoded + calibrated data to find balls
- Adjustable thresholds for lighting
- Falls back gracefully if calibration missing

### Benefits of This Design

✓ **Portable:** Copy calibration JSON to new device
✓ **Debuggable:** Constants file shows expected vs actual
✓ **Professional:** Clear separation like MLM2 Pro
✓ **Maintainable:** Changing one constant updates all code
✓ **Testable:** Can validate calibration against hardcoded expectations

---

## 📝 Test the Alignment Screen

```bash
# From PRGR_Project directory
python3 main.py

# In the app:
1. Go to Settings
2. Click Calibration
3. Click "🎯 Alignment" button
4. You should see live camera with green crosshair
5. Toggle Crosshair / Grid / Hitbox guides
```

---

**Next meeting: Answer the 3 critical questions, then build Step 2 (measurements UI).**
