#!/bin/bash

echo "ProfilerV1 Quick Start"
echo "======================"
echo ""

# Check if sound files exist
if [ ! -f "sounds/click.wav" ] || [ ! -f "sounds/success.wav" ]; then
    echo "⚠️  Sound files not found. Generating..."
    cd sounds
    python3 Download.py
    cd ..
    echo ""
fi

# Check Python dependencies
echo "Checking dependencies..."
python3 << EOF
import sys
errors = []

try:
    import PySide6.QtCore
    print("✓ PySide6")
except ImportError:
    errors.append("PySide6")
    print("✗ PySide6 - MISSING")
    
try:
    import PySide6.QtMultimedia
    print("✓ PySide6.QtMultimedia")
except ImportError:
    errors.append("PySide6.QtMultimedia")
    print("✗ PySide6.QtMultimedia - MISSING")
    
try:
    import numpy
    print("✓ NumPy")
except ImportError:
    errors.append("NumPy")
    print("✗ NumPy - MISSING")

if errors:
    print("\n❌ Missing dependencies:", ", ".join(errors))
    print("Run './setup_raspi.sh' to install them")
    sys.exit(1)
else:
    print("\n✅ All dependencies installed")
EOF

if [ $? -ne 0 ]; then
    echo ""
    echo "Would you like to run setup now? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        chmod +x setup_raspi.sh
        ./setup_raspi.sh
    else
        exit 1
    fi
fi

echo ""
echo "🚀 Starting ProfilerV1..."
echo ""

# Try to run with best settings for Raspberry Pi
export QT_QPA_PLATFORM=xcb
export QT_QUICK_CONTROLS_STYLE=Material

python3 main.py

# If that fails, try alternative settings
if [ $? -ne 0 ]; then
    echo ""
    echo "⚠️  Failed with default settings. Trying software rendering..."
    export QT_QUICK_BACKEND=software
    python3 main.py
fi
