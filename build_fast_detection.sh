#!/bin/bash
# Build script for fast_detection C++ module

echo "========================================="
echo "Building Fast Detection C++ Module"
echo "========================================="

# Check for system dependencies first
echo ""
echo "Checking system dependencies..."

missing_deps=()

# Check for cmake
if ! command -v cmake &> /dev/null; then
    missing_deps+=("cmake")
fi

# Check for pybind11-dev (system package)
if ! dpkg -l | grep -q pybind11-dev; then
    missing_deps+=("pybind11-dev")
fi

# Check for python3-opencv
if ! python3 -c "import cv2" 2>/dev/null; then
    if ! dpkg -l | grep -q python3-opencv; then
        missing_deps+=("python3-opencv")
    fi
fi

if [ ${#missing_deps[@]} -gt 0 ]; then
    echo ""
    echo "Missing system dependencies: ${missing_deps[*]}"
    echo ""
    echo "Install them with:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install ${missing_deps[*]}"
    echo ""
    read -p "Install now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo apt-get update
        sudo apt-get install -y ${missing_deps[*]}
    else
        echo "Aborting. Please install dependencies and try again."
        exit 1
    fi
fi

# Build the module
echo ""
echo "Building C++ extension..."
python3 setup.py build_ext --inplace

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
    echo "Run your program with: python3 main.py"
else
    echo ""
    echo "========================================="
    echo "⚠️  Build completed but import failed"
    echo "========================================="
    echo ""
    echo "The system will fall back to Python detection."
    exit 1
fi
