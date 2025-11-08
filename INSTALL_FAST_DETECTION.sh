#!/bin/bash
#
# Complete Installation Script for Fast C++ Ball Detection
# Run this on your Raspberry Pi to set up optimized 100 FPS detection
#

set -e  # Exit on any error

echo "========================================="
echo "Fast Detection Installation"
echo "========================================="
echo ""

# ============================================
# Step 1: Update System
# ============================================
echo "Step 1: Updating system packages..."
sudo apt-get update

# ============================================
# Step 2: Install Build Tools
# ============================================
echo ""
echo "Step 2: Installing build tools..."
sudo apt-get install -y \
    build-essential \
    cmake \
    python3-dev \
    python3-pip

# ============================================
# Step 3: Install Python Dependencies
# ============================================
echo ""
echo "Step 3: Installing Python dependencies..."

# Install pybind11
pip3 install --upgrade pybind11

# Install numpy (usually already installed)
pip3 install --upgrade numpy

# OpenCV is already installed via picamera2, but verify
if ! python3 -c "import cv2" 2>/dev/null; then
    echo "Installing OpenCV..."
    pip3 install opencv-python
else
    echo "✅ OpenCV already installed"
fi

# ============================================
# Step 4: Build C++ Extension Module
# ============================================
echo ""
echo "Step 4: Building C++ fast_detection module..."
echo ""

cd /home/user/PRGR_Project

# Clean any previous builds
rm -rf build/ *.egg-info dist/

# Build and install
pip3 install -e .

# ============================================
# Step 5: Verify Installation
# ============================================
echo ""
echo "Step 5: Verifying installation..."
echo ""

if python3 -c "import fast_detection; print('Module version:', fast_detection.__doc__)" 2>/dev/null; then
    echo ""
    echo "========================================="
    echo "✅ SUCCESS! Installation complete!"
    echo "========================================="
    echo ""
    echo "The fast_detection C++ module is ready."
    echo ""
    echo "Next steps:"
    echo "  1. Run the app: python3 main.py"
    echo "  2. Go to Camera Settings"
    echo "  3. Set frame rate to 100 FPS"
    echo "  4. Enjoy 3-5x faster detection!"
    echo ""
    echo "Optional: Run benchmark to see speedup:"
    echo "  ./benchmark_detection.py"
    echo ""
else
    echo ""
    echo "========================================="
    echo "⚠️  Installation completed but import failed"
    echo "========================================="
    echo ""
    echo "The app will fall back to Python detection."
    echo "This is still functional, just slower."
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check errors above"
    echo "  2. Ensure OpenCV is installed: pip3 install opencv-python"
    echo "  3. Try: pip3 install pybind11[global]"
    echo ""
    exit 1
fi
