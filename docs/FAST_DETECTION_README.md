# Fast C++ Ball Detection Module

This module provides **3-5x speedup** for ball detection at 100 FPS using optimized C++ code with pybind11 bindings.

## Features

- **Fast ball detection** using OpenCV in C++ (3-5x faster than Python)
- **Automatic fallback** to Python if C++ module not available
- **Zero-copy** numpy array integration
- **Optimized for Raspberry Pi** with ARM NEON instructions

## Installation

### Prerequisites

```bash
# Install dependencies
sudo apt-get update
sudo apt-get install cmake build-essential

# Install Python packages
pip3 install pybind11 opencv-python numpy
```

### Build the Module

```bash
# Option 1: Use the build script (recommended)
./build_fast_detection.sh

# Option 2: Manual build
pip3 install -e .
```

### Verify Installation

```bash
python3 -c "import fast_detection; print('✅ Fast detection loaded!')"
```

## Usage

The module is **automatically used** by `main.py` when available. No code changes needed!

When you run `main.py`:
- ✅ If fast_detection is available: "Fast C++ detection loaded - using optimized ball detection"
- ⚠️ If not available: "Fast C++ detection not available - using Python fallback"

## Performance

**At 100 FPS (OV9281 camera):**

| Method | Processing Time | Can Keep Up? |
|--------|----------------|--------------|
| Python (current) | ~12-15ms/frame | ⚠️ Barely (10ms target) |
| C++ (optimized) | ~3-5ms/frame | ✅ Yes, with headroom |

**At 120 FPS:**

| Method | Processing Time | Can Keep Up? |
|--------|----------------|--------------|
| Python | ~12-15ms/frame | ❌ No (8.3ms target) |
| C++ | ~3-5ms/frame | ✅ Yes |

## API Reference

### `detect_ball(frame)`
Detect golf ball in RGB frame.

**Parameters:**
- `frame`: numpy array (height, width, 3) - RGB image

**Returns:**
- `(x, y, radius)` tuple if ball detected
- `None` if no ball detected

**Example:**
```python
import fast_detection
import numpy as np

frame = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
result = fast_detection.detect_ball(frame)

if result is not None:
    x, y, radius = result
    print(f"Ball at ({x}, {y}) with radius {radius}px")
```

### `get_scene_brightness(frame)`
Calculate mean brightness of scene (for hand-covering detection).

**Parameters:**
- `frame`: numpy array (height, width, 3) - RGB image

**Returns:**
- `float`: mean brightness (0-255)

**Example:**
```python
brightness = fast_detection.get_scene_brightness(frame)
if brightness < 40:
    print("Camera is covered!")
```

### `calculate_velocity(position_history)`
Calculate velocity from position history (for false trigger detection).

**Parameters:**
- `position_history`: list of (x, y) tuples or None values

**Returns:**
- `float`: average velocity in pixels per frame

**Example:**
```python
positions = [(100, 200), (102, 201), (103, 202)]
velocity = fast_detection.calculate_velocity(positions)
print(f"Ball moving at {velocity:.2f} px/frame")
```

## Troubleshooting

### Build fails with "pybind11 not found"
```bash
pip3 install pybind11
```

### Build fails with "OpenCV not found"
```bash
pip3 install opencv-python
# or on Raspberry Pi:
sudo apt-get install python3-opencv
```

### Module imports but crashes
Make sure OpenCV version matches between Python and C++:
```bash
python3 -c "import cv2; print(cv2.__version__)"
```

### Performance not improving
Check if module is actually being used:
```bash
python3 main.py 2>&1 | grep "Fast C++ detection"
```

You should see: "✅ Fast C++ detection loaded - using optimized ball detection"

## Rebuilding

If you make changes to `fast_detection.cpp`:

```bash
# Clean build
rm -rf build/
./build_fast_detection.sh
```

## Uninstalling

```bash
pip3 uninstall fast_detection
```

The system will automatically fall back to Python detection.
