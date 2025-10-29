#!/bin/bash

echo "======================================"
echo "ProfilerV1 - Raspberry Pi Setup"
echo "======================================"
echo ""

# Update system packages
echo "📦 Updating system packages..."
sudo apt-get update

# Install Python 3 and pip if not already installed
echo "🐍 Ensuring Python 3 and pip are installed..."
sudo apt-get install -y python3 python3-pip python3-dev

# Install Qt6 dependencies for PySide6
echo "🎨 Installing Qt6 dependencies..."
sudo apt-get install -y \
    qt6-base-dev \
    libqt6multimedia6 \
    qt6-multimedia-dev \
    libgles2-mesa-dev \
    libegl1-mesa-dev \
    libgbm-dev \
    libdrm-dev \
    libxkbcommon-x11-0 \
    libxcb-xinerama0 \
    libxcb-cursor0

# Install audio dependencies
echo "🔊 Installing audio dependencies..."
sudo apt-get install -y \
    libasound2-dev \
    pulseaudio \
    libpulse-dev

# Install PySide6 and required Python packages
echo "📚 Installing Python packages..."
pip3 install --break-system-packages PySide6
pip3 install --break-system-packages numpy

# Check if installation was successful
echo ""
echo "✅ Checking installations..."
python3 -c "import PySide6.QtCore; print('✓ PySide6 installed successfully')" 2>/dev/null || echo "❌ PySide6 installation failed"
python3 -c "import numpy; print('✓ NumPy installed successfully')" 2>/dev/null || echo "❌ NumPy installation failed"

echo ""
echo "======================================"
echo "Setup complete!"
echo "======================================"
echo ""
echo "To run your app, use:"
echo "  python3 main.py"
echo ""
echo "If you still get errors, try:"
echo "  QT_QPA_PLATFORM=xcb python3 main.py"
echo ""
