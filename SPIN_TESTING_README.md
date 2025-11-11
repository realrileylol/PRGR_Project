# Golf Ball Spin Detection Testing Guide

## 🎯 Overview
Test spin detection by capturing ball rotation using marked golf balls and computer vision.

## 📋 Prerequisites

### Install Dependencies:
```bash
sudo apt update
sudo apt install python3-opencv python3-picamera2 python3-numpy
```

### Verify Installation:
```bash
python3 -c "import cv2; import picamera2; print('✅ Ready!')"
```

## 🏌️ Phase 1: Ball Preparation

### Mark Your Ball:
1. **Use a black Sharpie marker**
2. **Draw 3-4 large dots** (5-8mm diameter)
3. **Space evenly** around the ball's equator
4. **High contrast** = better tracking

**Good pattern:**
```
    ●
●       ●
    ●
```

## 🎥 Phase 2: Camera Setup Test

### Set Camera Settings First:
1. Open ProfilerV1 app
2. Go to **Settings → Camera Settings**
3. Select **"Spin Detection"** preset
4. Or manually set:
   - Shutter: **1-2ms** (freeze the dots)
   - Gain: **6-8x** (bright enough to see dots)
   - Frame Rate: **60 fps** (capture more rotation)
5. Click **"Save"**

### Test Frame Capture:
```bash
cd /home/user/PRGR_Project
python3 test_camera_capture.py
```

**What this does:**
- Captures 10 frames rapidly
- Saves as `test_frame_000.jpg` through `test_frame_009.jpg`
- You can check if dots are visible and crisp

**Check the images:**
```bash
ls -lh test_frame_*.jpg
```

**If dots are blurry:**
- Add more light (bright lamp on ball)
- Decrease shutter speed to 1ms
- Increase gain to 10x

## 🔄 Phase 3: Spin Detection Test

### Run Live Spin Detection:
```bash
python3 test_spin_detection.py
```

**What this does:**
- Opens live camera feed
- Detects the ball (green circle)
- Finds dots on ball (blue circles)
- Tracks dot movement between frames
- Calculates RPM from rotation

### Testing Procedure:
1. **Position ball:** 4-5 feet from camera, dots visible
2. **Run script:** `python3 test_spin_detection.py`
3. **Verify detection:**
   - Green circle around ball? ✅
   - Blue circles on dots? ✅
4. **Test spin:**
   - Gently roll ball toward camera
   - OR tap ball to make it spin in place
   - Watch terminal for "🔄 Detected spin: XXX RPM"

5. **Check debug images:**
   - Script saves `spin_debug_*.jpg` every 30 frames
   - Shows what the algorithm sees

### Press Ctrl+C to stop

## 🐛 Troubleshooting

### "No ball detected"
- Make sure ball fills at least 1/4 of frame
- Ensure good contrast (white ball, dark background)
- Check lighting

### "No dots found"
- Dots might be too small - make them BIGGER
- Increase contrast (darker marker)
- Check exposure (not too bright, not too dark)

### Spin seems wrong
- Normal golf shots: 2000-8000 RPM
- Gentle toss: 500-2000 RPM
- If you see 50,000 RPM - algorithm error, needs tuning

## 🚀 Phase 4: Moving to C++ (Later)

### Why C++?
- **Python is fine for testing!** Start here.
- Move to C++ only if:
  - Python is too slow (< 30 fps processing)
  - You need real-time performance
  - Battery life is critical

### C++ Approach (when ready):
1. Use **OpenCV C++** (same algorithms)
2. Create Python binding with **pybind11**
3. Call C++ from your PySide6 app
4. Keep UI in Python, move heavy math to C++

### Typical Performance:
- Python + OpenCV: 20-60 fps (usually enough!)
- C++ + OpenCV: 60-120 fps (overkill for golf)

## 📊 Next Steps

### Once Spin Detection Works:

1. **Integrate into ProfilerV1:**
   - Add spin calculation to shot metrics
   - Display live spin during shot
   - Save to history

2. **Calibration:**
   - Test with known spin (put ball on drill at known RPM)
   - Tune algorithm parameters
   - Validate against commercial launch monitor

3. **Optimization:**
   - Only move to C++ if Python is too slow
   - Profile your code first!

## 💡 Pro Tips

### Lighting is CRITICAL:
- Bright, even lighting on ball
- LED light panel or bright desk lamp
- Point light at ball from behind/above camera

### Ball Position:
- Behind-ball view (camera looking down target line)
- Ball 4-5 ft away
- Ball centered in frame
- Dots clearly visible

### Frame Rate Sweet Spot:
- 60 fps: Good for most shots
- 90-120 fps: Better for high-speed shots
- 30 fps: Too slow for accurate spin

### Start Simple:
1. ✅ Test: Can you see the ball? (green circle)
2. ✅ Test: Can you see the dots? (blue circles)
3. ✅ Test: Roll ball - does RPM change?
4. ✅ Test: Gentle tap - realistic RPM (~500-2000)?
5. 🎯 Then: Try actual light shots

## 🎬 Example Test Session

```bash
# 1. Set camera settings in app (Spin Detection preset)

# 2. Test capture
python3 test_camera_capture.py
# Check: Are dots visible in test_frame_*.jpg?

# 3. Test spin detection
python3 test_spin_detection.py
# Position ball, watch for detection

# 4. Gentle test
# Roll ball slowly toward camera
# Should see RPM in terminal

# 5. Light shot test
# Hit gentle punch shot
# Watch for spin calculation

# Press Ctrl+C when done
```

Good luck! 🏌️⛳
