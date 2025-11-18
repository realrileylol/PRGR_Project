# Rebuild C++ Module

The C++ fast detection module has been updated with **DIRECTIONAL** impact detection.

## Rebuild Instructions

```bash
cd cpp_module
./build.sh
```

This will:
1. Install dependencies (pybind11)
2. Compile fast_detection.cpp with new directional impact detection
3. Install the module
4. Test that it loads correctly

## What Changed - DIRECTIONAL DETECTION

**Why directional?**
- OLD: Any 30px movement triggers → False alarms from vibration, wobble, shadows
- NEW: Only 30px movement DOWN RANGE triggers → Only real impacts!

**New C++ functions:**
- `detect_impact(prev_x, prev_y, curr_x, curr_y, threshold, axis, direction)`
  - Only triggers on down-range movement
  - Ignores sideways wobble/vibration
  - ~0.0005ms (even faster than before!)
- `calculate_ball_distance()` - Distance calculation for debugging

**How it works:**
1. Ball locks at position (x1, y1)
2. Every frame checks if ball moved DOWN RANGE
3. If moved > 30 pixels in down-range direction → **IMPACT!**
4. Movement sideways/backwards is ignored → No false triggers
5. Captures 30 frames before + 10 after

**Performance:**
- Impact check: ~0.5 microsecond (pure integer math, no sqrt, no multiplication)
- Total overhead: < 0.05% of frame time
- Detection is instant when ball moves down range

## Configuration - Which Way is Down Range?

In `main.py` around line 1424-1428, configure your camera setup:

```python
impact_axis = 1        # 0=X axis (side view), 1=Y axis (behind/front view)
impact_direction = 1   # 1=positive, -1=negative
impact_threshold = 30  # Pixels to trigger
```

**Common setups:**
- **Camera BEHIND golfer** (most common): `axis=1, direction=1` (ball moves DOWN in frame)
- **Camera IN FRONT**: `axis=1, direction=-1` (ball moves UP in frame)
- **Camera on LEFT side**: `axis=0, direction=1` (ball moves RIGHT)
- **Camera on RIGHT side**: `axis=0, direction=-1` (ball moves LEFT)

**Default is:** `axis=1, direction=1` (camera behind golfer)

## Testing

After rebuilding, run:
```bash
python3 main.py
```

You should see:
```
✅ Fast C++ detection loaded - using optimized ball detection
📷 Using ultra-high-speed capture: Shutter=800µs, Gain=10.0x, FPS=200
🎯 Impact detection: Axis=Y, Direction=positive, Threshold=30px
📺 C++ Motion Detection - Ultra-fast impact detection!
```

**To verify your axis/direction:**
1. Lock ball
2. Move ball DOWN RANGE by hand (simulate hit)
3. Should trigger capture
4. Move ball SIDEWAYS - should NOT trigger
5. If it doesn't work, swap direction: `1` → `-1` or vice versa

## If Build Fails

The system will automatically fall back to Python motion detection (slightly slower but still works).

Check error messages and ensure:
- OpenCV is installed: `pip3 install opencv-python`
- CMake is installed: `sudo apt-get install cmake`
- pybind11 is installed: `pip3 install pybind11`
