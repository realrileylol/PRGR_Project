# Fast C++ Ball Detection Module

This directory contains the optimized C++ ball detection implementation.

## Files

- `fast_detection.cpp` - C++ source code for ball detection
- `CMakeLists.txt` - CMake build configuration
- `setup.py` - Python package setup for installation
- `build.sh` - Build script (use main installer instead)

## Building

**Don't build from here directly.** Use the main installer:

```bash
cd ..
./INSTALL_FAST_DETECTION.sh
```

## What It Does

Provides 3-5x faster ball detection compared to pure Python by:
- Using native C++ OpenCV operations
- Zero-copy numpy array integration
- SIMD optimizations (-march=native)
- Eliminating Python/C++ boundary overhead

## Installation

The module is installed as `fast_detection` and automatically used by `main.py` when available.
