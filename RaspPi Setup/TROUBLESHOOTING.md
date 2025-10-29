# Raspberry Pi Troubleshooting Guide

## Common Errors and Solutions

### Error: "ModuleNotFoundError: No module named 'PySide6'"
**Solution:**
```bash
pip3 install --break-system-packages PySide6
```

### Error: "qt.qpa.plugin: Could not load the Qt platform plugin"
**Solutions to try:**

1. Install Qt6 platform plugins:
```bash
sudo apt-get install -y qt6-base-dev libqt6gui6
```

2. Set the platform explicitly:
```bash
export QT_QPA_PLATFORM=xcb
python3 main.py
```

3. Or run with the environment variable directly:
```bash
QT_QPA_PLATFORM=xcb python3 main.py
```

### Error: "ImportError: libQt6Multimedia.so.6: cannot open shared object file"
**Solution:**
```bash
sudo apt-get install -y libqt6multimedia6 qt6-multimedia-dev
```

### Error: Sound files not working
**Solution:**
```bash
# Generate sound files first
cd sounds
python3 Download.py
cd ..

# Ensure audio system is running
pulseaudio --check
pulseaudio --start
```

### Error: "ModuleNotFoundError: No module named 'numpy'"
**Solution:**
```bash
pip3 install --break-system-packages numpy
```

### Error: Permission denied when installing packages
**Solution:**
Use `--break-system-packages` flag or install in a virtual environment:
```bash
# Option 1: Use break-system-packages flag
pip3 install --break-system-packages PySide6

# Option 2: Create virtual environment (recommended)
python3 -m venv venv
source venv/bin/activate
pip install PySide6 numpy
python main.py
```

### Error: Display issues or blank window
**Solutions:**

1. Ensure X11 is running (if using GUI):
```bash
export DISPLAY=:0
```

2. Run with full OpenGL support:
```bash
export QT_XCB_GL_INTEGRATION=xcb_egl
python3 main.py
```

3. Use software rendering if hardware acceleration fails:
```bash
export QT_QUICK_BACKEND=software
python3 main.py
```

### Performance Issues on Raspberry Pi
**Optimizations:**

1. Reduce window size in main.qml if needed
2. Disable animations by adding to main.py:
```python
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"  # Instead of Material
```

3. Close other applications to free up memory

## Complete Setup Process

### Step 1: Make setup script executable
```bash
chmod +x setup_raspi.sh
```

### Step 2: Run setup script
```bash
./setup_raspi.sh
```

### Step 3: Generate sound files
```bash
cd sounds
python3 Download.py
cd ..
```

### Step 4: Run the application
```bash
python3 main.py
```

## Raspberry Pi Specific Configuration

### For Raspberry Pi 4 or older:
Consider using the Basic style instead of Material for better performance:

Edit `main.py` and change:
```python
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"  # Change from "Material"
```

### For headless operation:
If running without a display, you'll need to set up a virtual framebuffer:
```bash
sudo apt-get install xvfb
Xvfb :1 -screen 0 800x480x24 &
export DISPLAY=:1
python3 main.py
```

## System Requirements Check

Run this to check if all dependencies are installed:
```bash
python3 << EOF
import sys
try:
    import PySide6.QtCore
    print("✓ PySide6: OK")
except ImportError:
    print("✗ PySide6: MISSING")
    
try:
    import PySide6.QtMultimedia
    print("✓ PySide6.QtMultimedia: OK")
except ImportError:
    print("✗ PySide6.QtMultimedia: MISSING")
    
try:
    import numpy
    print("✓ NumPy: OK")
except ImportError:
    print("✗ NumPy: MISSING")
    
print(f"\nPython version: {sys.version}")
EOF
```

## Getting Help

If you're still experiencing issues:

1. Check the exact error message
2. Note your Raspberry Pi model and OS version:
   ```bash
   cat /etc/os-release
   cat /proc/device-tree/model
   ```
3. Check available memory:
   ```bash
   free -h
   ```
4. Verify Qt installation:
   ```bash
   dpkg -l | grep qt6
   ```

## Quick Fix Commands

Run all these if you want to try everything at once:

```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install all dependencies
sudo apt-get install -y python3 python3-pip python3-dev \
    qt6-base-dev libqt6multimedia6 qt6-multimedia-dev \
    libgles2-mesa-dev libegl1-mesa-dev libgbm-dev libdrm-dev \
    libxkbcommon-x11-0 libxcb-xinerama0 libxcb-cursor0 \
    libasound2-dev pulseaudio libpulse-dev

# Install Python packages
pip3 install --break-system-packages PySide6 numpy

# Generate sound files
cd sounds && python3 Download.py && cd ..

# Run app
python3 main.py
```
