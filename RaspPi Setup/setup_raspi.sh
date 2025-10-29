#!/bin/bash

echo "======================================"
echo "ProfilerV1 - Raspberry Pi Setup v2"
echo "======================================"
echo ""

# Update system packages
echo "📦 Updating system packages..."
sudo apt-get update

# Install Python 3 and pip if not already installed
echo "🐍 Ensuring Python 3 and pip are installed..."
sudo apt-get install -y python3 python3-pip python3-dev

# Install Qt6 base dependencies
echo "🎨 Installing Qt6 base dependencies..."
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

# Install Qt6 QML modules (THIS IS WHAT WAS MISSING!)
echo "📦 Installing Qt6 QML modules..."
sudo apt-get install -y \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtquick-templates \
    qml6-module-qtquick-window \
    qml6-module-qtqml-workerscript \
    qt6-declarative-dev

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
python3 -c "import PySide6.QtQml; print('✓ PySide6.QtQml installed successfully')" 2>/dev/null || echo "❌ PySide6.QtQml installation failed"
python3 -c "import PySide6.QtMultimedia; print('✓ PySide6.QtMultimedia installed successfully')" 2>/dev/null || echo "❌ PySide6.QtMultimedia installation failed"
python3 -c "import numpy; print('✓ NumPy installed successfully')" 2>/dev/null || echo "❌ NumPy installation failed"

# Check if QML modules are available
echo ""
echo "✅ Checking QML modules..."
if dpkg -l | grep -q "qml6-module-qtquick-controls"; then
    echo "✓ QtQuick.Controls QML module installed"
else
    echo "❌ QtQuick.Controls QML module NOT installed"
fi

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
