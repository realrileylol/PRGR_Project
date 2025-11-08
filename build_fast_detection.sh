#!/bin/bash
# Build script for fast_detection C++ module

echo "========================================="
echo "Building Fast Detection C++ Module"
echo "========================================="

# Set up virtual environment
VENV_DIR="venv"

if [ ! -d "$VENV_DIR" ]; then
    echo ""
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to create virtual environment."
        echo "Install python3-venv with: sudo apt-get install python3-venv"
        exit 1
    fi
fi

# Activate virtual environment
echo "Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Upgrade pip
echo ""
echo "Upgrading pip..."
pip install --upgrade pip

# Install dependencies if needed
echo ""
echo "Checking dependencies..."

# Check for pybind11
if ! python -c "import pybind11" 2>/dev/null; then
    echo "Installing pybind11..."
    pip install pybind11
fi

# Check for OpenCV
if ! python -c "import cv2" 2>/dev/null; then
    echo "Installing OpenCV..."
    pip install opencv-python
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
pip install -e .

# Test import
echo ""
echo "Testing import..."
if python -c "import fast_detection; print('✅ fast_detection module loaded successfully!')" 2>/dev/null; then
    echo ""
    echo "========================================="
    echo "✅ Build completed successfully!"
    echo "========================================="
    echo ""
    echo "The fast_detection module is now available in the virtual environment."
    echo ""
    echo "To use it, activate the venv first:"
    echo "  source venv/bin/activate"
    echo "  python main.py"
else
    echo ""
    echo "========================================="
    echo "⚠️  Build completed but import failed"
    echo "========================================="
    echo ""
    echo "The system will fall back to Python detection."
    deactivate
    exit 1
fi

deactivate
