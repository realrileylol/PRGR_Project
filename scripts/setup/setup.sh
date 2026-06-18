#!/usr/bin/env bash
# PRGR Launch Monitor - Raspberry Pi 5 Setup Script
# Installs all system dependencies, Qt6, OpenCV, and Python packages.

set -euo pipefail

echo "=== PRGR Launch Monitor - Raspberry Pi Setup ==="
echo ""

# Ensure we are running on a Raspberry Pi (basic check)
if [ ! -f /proc/device-tree/model ] || ! grep -qi "raspberry" /proc/device-tree/model 2>/dev/null; then
    echo "WARNING: This script is designed for Raspberry Pi. Proceeding anyway..."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "[1/3] Installing apt dependencies..."
sudo apt-get update
sudo apt-get install -y \
    qt6-base-dev \
    qt6-declarative-dev \
    qt6-multimedia-dev \
    libqt6serialport6-dev \
    qml6-module-qtquick-controls \
    libopencv-dev \
    cmake \
    build-essential \
    python3-pip \
    python3-venv

echo ""
echo "[2/3] Creating Python virtual environment for radar..."
python3 -m venv "$PROJECT_ROOT/radar/.venv"
source "$PROJECT_ROOT/radar/.venv/bin/activate"

echo ""
echo "[3/3] Installing radar Python package..."
pip install -e "$PROJECT_ROOT/radar/"

deactivate

echo ""
echo "============================================"
echo "  Setup complete!"
echo ""
echo "  Build the project:   make build"
echo "  Run the project:     make run"
echo "  Start radar bridge:  source radar/.venv/bin/activate && make radar-start"
echo "============================================"
