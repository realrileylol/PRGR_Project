#!/bin/bash

# KLD2 Sensor Setup Script for Raspberry Pi
# This script installs all necessary dependencies for GNU Radio and KLD2 monitoring

set -e  # Exit on error

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     KLD2 Doppler Radar Sensor Setup for Raspberry Pi        ║"
echo "║              GNU Radio & Signal Processing                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    echo "⚠️  Warning: This doesn't appear to be a Raspberry Pi"
    echo "   Some features may not work correctly"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "📦 Step 1: Updating package lists..."
sudo apt-get update

echo ""
echo "📦 Step 2: Installing GNU Radio and dependencies..."
sudo apt-get install -y \
    gnuradio \
    python3-gnuradio \
    gr-qtgui \
    python3-scipy \
    python3-matplotlib \
    python3-numpy \
    python3-pyqt5 \
    python3-spidev \
    python3-rpi.gpio

echo ""
echo "📦 Step 3: Installing Python packages..."
pip3 install --break-system-packages \
    spidev \
    RPi.GPIO \
    numpy \
    scipy \
    matplotlib \
    pyqtgraph

echo ""
echo "🔧 Step 4: Checking SPI interface..."
if [ -e /dev/spidev0.0 ]; then
    echo "✅ SPI is enabled"
else
    echo "⚠️  SPI is not enabled"
    echo ""
    echo "To enable SPI:"
    echo "  1. Run: sudo raspi-config"
    echo "  2. Navigate to: Interface Options → SPI"
    echo "  3. Select: Yes"
    echo "  4. Reboot: sudo reboot"
    echo ""
    read -p "Would you like to enable SPI now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo raspi-config nonint do_spi 0
        echo "✅ SPI enabled! You may need to reboot."
    fi
fi

echo ""
echo "👤 Step 5: Adding user to SPI and GPIO groups..."
sudo usermod -a -G spi,gpio $USER
echo "✅ User added to groups (logout/login to apply)"

echo ""
echo "🧪 Step 6: Testing installation..."

# Test Python imports
python3 << 'EOF'
import sys
errors = []

try:
    import numpy as np
    print("✅ NumPy: OK")
except ImportError as e:
    print("❌ NumPy: FAILED")
    errors.append("numpy")

try:
    import scipy
    print("✅ SciPy: OK")
except ImportError as e:
    print("❌ SciPy: FAILED")
    errors.append("scipy")

try:
    import matplotlib
    print("✅ Matplotlib: OK")
except ImportError as e:
    print("❌ Matplotlib: FAILED")
    errors.append("matplotlib")

try:
    import spidev
    print("✅ SPIdev: OK")
except ImportError as e:
    print("❌ SPIdev: FAILED")
    errors.append("spidev")

try:
    import RPi.GPIO as GPIO
    print("✅ RPi.GPIO: OK")
except ImportError as e:
    print("❌ RPi.GPIO: FAILED (OK if not on Raspberry Pi)")

try:
    from gnuradio import gr, blocks
    print("✅ GNU Radio: OK")
except ImportError as e:
    print("❌ GNU Radio: FAILED")
    errors.append("gnuradio")

try:
    from PyQt5 import Qt
    print("✅ PyQt5: OK")
except ImportError as e:
    print("❌ PyQt5: FAILED")
    errors.append("PyQt5")

if errors:
    print(f"\n⚠️  {len(errors)} module(s) failed to import: {', '.join(errors)}")
    sys.exit(1)
else:
    print("\n✅ All modules imported successfully!")
EOF

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Some dependencies failed to install"
    echo "   Please check the error messages above"
    exit 1
fi

echo ""
echo "🧪 Step 7: Testing sensor module..."
if python3 -c "from kld2_sensor import KLD2Sensor; print('✅ KLD2 sensor module OK')"; then
    echo "✅ Sensor module loaded successfully"
else
    echo "⚠️  Sensor module test failed"
fi

echo ""
echo "✨ Step 8: Testing GNU Radio version..."
gnuradio-config-info --version || echo "⚠️  Could not get GNU Radio version"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    INSTALLATION COMPLETE!                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📝 Quick Start:"
echo ""
echo "  1. Test with simulation:"
echo "     python3 simple_kld2_monitor.py --sim"
echo ""
echo "  2. Connect hardware and test sensor:"
echo "     python3 kld2_sensor.py"
echo ""
echo "  3. Start monitoring (simple):"
echo "     python3 simple_kld2_monitor.py"
echo ""
echo "  4. Start monitoring (GNU Radio):"
echo "     python3 gnuradio_kld2_monitor.py"
echo ""
echo "  5. Open in GNU Radio Companion:"
echo "     gnuradio-companion kld2_monitor.grc"
echo ""
echo "📖 For detailed instructions, see:"
echo "   KLD2_SETUP.md"
echo ""
echo "⚠️  Important:"
echo "   - Logout and login to apply group changes"
echo "   - If SPI was just enabled, reboot your Raspberry Pi"
echo ""
echo "🆘 Troubleshooting:"
echo "   - Check hardware connections (see KLD2_SETUP.md)"
echo "   - Verify SPI: ls /dev/spi*"
echo "   - Test ADC: python3 kld2_sensor.py"
echo ""
echo "Happy monitoring! 🏌️"
