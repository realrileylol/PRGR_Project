# Quick Start Guide - 100 FPS + C++ Detection

## 🚀 One-Command Installation

On your Raspberry Pi, run:

```bash
cd ~/PRGR_Project
./INSTALL_FAST_DETECTION.sh
```

**This installs everything automatically!**

---

## 📋 Manual Installation (if you prefer step-by-step)

### 1. Install Build Tools

```bash
# Update package list
sudo apt-get update

# Install required tools
sudo apt-get install -y build-essential cmake python3-dev python3-pip
```

### 2. Install Python Dependencies

```bash
# Install pybind11 (for C++ bindings)
pip3 install pybind11

# Install/upgrade numpy
pip3 install --upgrade numpy

# OpenCV should already be installed, but verify:
python3 -c "import cv2; print('OpenCV version:', cv2.__version__)"
```

### 3. Build the C++ Module

```bash
cd ~/PRGR_Project

# Build and install
pip3 install -e .
```

### 4. Verify Installation

```bash
# Test import
python3 -c "import fast_detection; print('✅ Fast detection loaded!')"
```

You should see: `✅ Fast detection loaded!`

---

## 🎯 Configure App for 100 FPS

### Option 1: Use the UI (Recommended)

1. Run the app:
   ```bash
   cd ~/PRGR_Project
   python3 main.py
   ```

2. Navigate to **Camera Settings**

3. **Either:**
   - Select **"Spin Detection"** preset (auto-sets to 100 FPS), **OR**
   - Manually choose **100 FPS** from the frame rate buttons

4. Click **Save**

### Option 2: Set Default in Code

Edit `screens/CameraSettings.qml` line 19:

```qml
property int frameRate: 100  // Change from 30 to 100
```

---

## ✅ Verify It's Working

When you run the app, check the console output:

**✅ Success (C++ enabled):**
```
✅ Fast C++ detection loaded - using optimized ball detection
```

**⚠️ Fallback (Python only):**
```
⚠️ Fast C++ detection not available - using Python fallback
```

---

## 📊 Test Performance (Optional)

Run the benchmark to see the speedup:

```bash
cd ~/PRGR_Project
./benchmark_detection.py
```

**Expected output:**
```
SPEEDUP: 3.82x faster with C++

Target for 100 FPS: 10.0ms per frame
  Python: 14.23ms - ❌ TOO SLOW
  C++:    3.72ms - ✅ CAN keep up
```

---

## 🐛 Troubleshooting

### "cmake: command not found"

```bash
sudo apt-get install cmake
```

### "pybind11 not found"

```bash
pip3 install pybind11
# If still failing:
pip3 install "pybind11[global]"
```

### "OpenCV not found"

```bash
pip3 install opencv-python
# or on Raspberry Pi OS:
sudo apt-get install python3-opencv
```

### Build succeeds but import fails

```bash
# Check Python version matches
python3 --version

# Rebuild from scratch
cd ~/PRGR_Project
rm -rf build/ *.egg-info
pip3 install -e .
```

### App runs but still shows "Python fallback"

```bash
# Check if module is installed
pip3 list | grep fast-detection

# Try re-importing
python3 -c "import fast_detection"
```

---

## 🔄 Rebuilding After Changes

If you modify `fast_detection.cpp`:

```bash
cd ~/PRGR_Project
rm -rf build/
pip3 install -e .
```

---

## ❌ Uninstall C++ Module

```bash
pip3 uninstall fast_detection
```

The app will automatically fall back to Python detection.

---

## 📁 What Gets Installed

### System packages:
- `build-essential` - GCC compiler
- `cmake` - Build system
- `python3-dev` - Python headers

### Python packages:
- `pybind11` - C++/Python bindings
- `numpy` - Already installed
- `opencv-python` - Already installed (via picamera2)

### Project files:
- `fast_detection.cpython-*.so` - Compiled C++ module

---

## 🎓 Technical Details

### Where is the compiled module?

After building, you'll see a file like:
```
fast_detection.cpython-311-aarch64-linux-gnu.so
```

This is the compiled C++ module that Python imports.

### How does it work?

1. `fast_detection.cpp` contains C++ code
2. `pybind11` creates Python bindings
3. `CMake` compiles it to a `.so` shared library
4. Python imports it like any other module
5. `main.py` automatically uses it if available

### Performance optimization flags:

The module is compiled with:
- `-O3` - Maximum optimization
- `-march=native` - Use all CPU features (ARM NEON on Pi)
- `NDEBUG` - Remove debug checks

---

## 🚀 That's It!

You now have professional-grade ball detection at 100 FPS! 🏌️

**Total installation time: ~2-5 minutes**
