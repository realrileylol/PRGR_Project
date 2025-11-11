#!/bin/bash
# Build script for fast_detection C++ module
echo "========================================="
echo "Building Fast Detection C++ Module"
echo "========================================="

# Install dependencies if needed
echo ""
echo "Checking dependencies..."

# Check for pybind11
if ! python3 -c "import pybind11" 2>/dev/null; then
    echo "Installing pybind11..."
    pip3 install --break-system-packages pybind11
fi

# Check for OpenCV
if ! python3 -c "import cv2" 2>/dev/null; then
    echo "ERROR: OpenCV (cv2) not found. Install with:"
    echo "  pip3 install --break-system-packages opencv-python"
    exit 1
fi

# Check for cmake
if ! command -v cmake &> /dev/null; then
    echo "ERROR: CMake not found. Install with:"
    echo "  sudo apt-get install cmake"
    exit 1
fi

# Build the module
echo ""
echo "Building C++ extension..."
pip3 install --break-system-packages -e .

# Test import
echo ""
echo "Testing import..."
if python3 -c "import fast_detection; print('✅ fast_detection module loaded successfully!')" 2>/dev/null; then
    echo ""
    echo "========================================="
    echo "✅ Build completed successfully!"
    echo "========================================="
    echo ""
    echo "The fast_detection module is now available."
    echo "Your main.py will automatically use it for 3-5x speedup."
else
    echo ""
    echo "========================================="
    echo "⚠️  Build completed but import failed"
    echo "========================================="
    echo ""
    echo "The system will fall back to Python detection."
    exit 1
fi