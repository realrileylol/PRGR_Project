# Ball Tracking Setup Guide

**Step-by-step pipeline for configuring ball detection and tracking**

---

## Overview

This guide walks through the complete setup process for accurate ball position tracking using camera + background subtraction. The goal is to reliably detect and track the golf ball within the calibrated hitting zone.

---

## Camera Configuration

**Current Settings:**
- **Resolution:** 640×480 @ 180fps
- **Orientation:** Rotated 90° clockwise (portrait mode) → 480×640 final
- **Shutter:** 4000µs (4ms)
- **Gain:** 12.0x
- **Result:** Bright, high-speed capture with good FOV

**Why Portrait Mode?**
- More vertical FOV for tracking ball height and spin
- Better coverage of ball trajectory up/down range

---

## Setup Pipeline (In Order)

### Step 1: Navigate to Ball Zone Calibration

1. Launch app: `./PRGR_LaunchMonitor`
2. Go to **Calibration** → **Ball Zone Calibration**
3. Verify camera preview is active and bright

**What to check:**
- ✓ White vertical centerline visible (alignment guide)
- ✓ Image is bright and clear
- ✓ Camera shows "640×480 @ 180fps, portrait mode"

---

### Step 2: Calibrate Ball Position

**Purpose:** Teach the system the exact size/position of a stationary golf ball.

**Steps:**
1. Place ball in center of mat (aligned with white vertical line)
2. Click **"Click Ball Edge"** button
3. Click 3-4 points around the ball's edge on the preview
4. Click **"Confirm"**

**Expected result:**
- Green circle appears around ball showing calibrated size
- Status shows: "Ball Calibrated ✓"

---

### Step 3: Define Hit Zone Boundaries

**Purpose:** Mark the 12"×12" hitting zone where ball must be placed.

**Steps:**
1. Place physical markers at 4 corners of hitting zone (optional)
2. Click **"Click Zone Corners"** button
3. Click 4 corners in order: **FL → FR → BR → BL**
   - FL = Front Left
   - FR = Front Right
   - BR = Back Right
   - BL = Back Left
4. Click **"Confirm"**

**Expected result:**
- Orange dotted box appears on screen
- Box should be centered with white vertical line
- Status shows: "Zone Defined ✓"

---

### Step 4: Capture Baseline (Background Subtraction)

**Purpose:** Eliminate false detections from mat texture, dimples, or patterns.

**Steps:**
1. **Remove the ball completely** from the hitting zone
2. Click **📷 BASE** button (turns green when captured)
3. Verify: Button now shows "✓ BASE Captured"

**What this does:**
- Captures a "clean" frame with no ball
- System will subtract this from live frames to isolate ball movement
- Eliminates static circles (textures, dimples) from detection

---

### Step 5: Test Ball Tracking

**Purpose:** Verify ball is detected reliably within zone.

**Steps:**
1. Place ball in center of orange dotted zone
2. Observe **Ready State Indicator** (top-left of preview):
   - Should show: **"● READY"** in green
   - Ball should have green circle around it
   - Status: **"TRACKING - IN ZONE"** (green text at top)

3. Move ball slightly left/right:
   - Green circle should follow smoothly (no jumping)
   - Confidence stays at 10/10

4. Move ball outside zone:
   - Circle turns RED
   - Status: **"TRACKING - OUT OF ZONE"** (green text changes)

**If ball tracking is jumpy or unreliable, proceed to Step 6.**

---

### Step 6: Debug Ball Detection (Troubleshooting)

**Purpose:** Diagnose why ball tracking is jumping or unreliable.

#### A. Enable Debug Mode

1. Click **🐛 OFF** → turns to **🐛 ON** (purple)
2. Debug visualization shows:
   - **Blue circles** = all detected circles
   - **Green circle** = selected ball (larger)
   - Radius values for each detection

#### B. Capture Debug Screenshot

1. Place ball in zone
2. Click **📸 CAP** button
3. Screenshot saved to: `/home/riley/prgr/PRGR_Project/screenshots/debug_*.png`

**What to look for in screenshot:**
- ✅ **One green circle on ball** = Good!
- ❌ **Multiple blue circles** = Background texture competing with ball
- ❌ **Ball has blue circle, not green** = Ball not being selected (wrong size or brightness)

#### C. View Background Subtraction

1. Ball still in zone
2. Click **🔍 DIFF** button (purple)
3. Screenshot saved showing difference image

**What to look for:**
- ✅ **Ball shows bright white, background is black** = Good subtraction!
- ❌ **Background has white spots/circles** = Baseline needs recapture or mat moved

---

## Common Issues & Fixes

### Issue: Ball tracking jumps around

**Cause:** Multiple circles detected (texture, dimples, shadows)

**Fix:**
1. Recapture baseline (📷 BASE) with ball removed
2. Check debug screenshot - should see only one green circle
3. Adjust lighting if needed (brighter = better)

---

### Issue: Ball not detected at all

**Cause:** Ball size outside detection range or too dark

**Fix:**
1. Check ball calibration - green circle should match ball edge
2. Verify brightness - image should be bright (gain 12.0, shutter 4000µs)
3. Re-calibrate ball position if needed

---

### Issue: Zone box off-center in screenshots (debug OFF)

**Cause:** C++ screenshot rendering uses different coordinate system

**Status:** Known issue - live preview is correct, screenshot rendering needs fix

**Workaround:** Use live preview (not screenshots) to verify zone alignment

---

## Data Flow Summary

```
Camera (640×480 @ 180fps)
    ↓
Rotate 90° clockwise
    ↓
Frame (480×640 portrait)
    ↓
Background Subtraction (if baseline captured)
    ↓
Ball Detection (HoughCircles + size filter)
    ↓
Zone Check (is ball in orange zone?)
    ↓
Tracking State Machine
    ↓
Ready State: "● READY" (green) or "○ NO BALL" (gray)
```

---

## What the System Measures vs Calculates

### Camera CALCULATES:
- ✅ Ball position (X, Y coordinates)
- ✅ Ball trajectory (position change over time)
- ✅ Launch angle (from trajectory curve)
- ✅ Launch direction (from position tracking)
- ✅ Spin rate (from mark rotation - if visible marks on ball)
- ✅ Spin axis (from trajectory deviation)

### K-LD2 Radar MEASURES:
- ✅ Ball speed (direct Doppler measurement)

**Hybrid system = Best of both worlds!**

---

## Next Steps After Setup

Once ball tracking is stable and reliable:

1. **Test with actual swings**
   - System should detect ball at rest ("READY")
   - Capture impact when ball moves
   - Track trajectory after impact

2. **Fine-tune detection parameters** (if needed)
   - Ball size range (currently 4-15px radius)
   - Tracking confidence thresholds
   - Zone boundary adjustments

3. **Add spin tracking** (future enhancement)
   - Requires visible marks on ball (alignment lines)
   - Tracks mark rotation between frames
   - Works best with bright lighting

---

## File Locations

**Screenshots saved to:**
- Debug mode: `/home/riley/prgr/PRGR_Project/screenshots/debug_*.png`
- Normal mode: `/home/riley/prgr/PRGR_Project/screenshots/screenshot_*.jpg`
- Background subtraction: `/home/riley/prgr/PRGR_Project/screenshots/background_subtraction_*.jpg`

**Settings saved to:**
- `/home/riley/.local/share/PRGR/Launch Monitor/settings.json`
- `/home/riley/.local/share/PRGR/Launch Monitor/calibration.json`

---

## Quick Reference: Button Functions

| Button | Function |
|--------|----------|
| 🔄 **Reset Track** | Reset ball tracking state (if stuck) |
| 📷 **BASE** | Capture baseline for background subtraction |
| 🔍 **DIFF** | Save background subtraction view screenshot |
| 🐛 **ON/OFF** | Toggle debug visualization (blue circles) |
| 📸 **CAP** | Capture screenshot of current view |
| ⏺ **REC** | Start/stop video recording |

---

**Last Updated:** 2025-12-18
**System:** OV9281 Camera @ 180fps + K-LD2 Radar
**Mode:** Portrait (90° rotated), Background Subtraction Enabled
