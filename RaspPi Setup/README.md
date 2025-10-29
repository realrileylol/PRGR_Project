# ProfilerV1 - Raspberry Pi Setup Guide

Golf shot simulator application with profile management and club bag configuration.

## Quick Start (Raspberry Pi)

### 1. Install Dependencies

Make the setup script executable and run it:

```bash
chmod +x setup_raspi.sh
./setup_raspi.sh
```

This will install:
- Python 3 and pip
- Qt6 libraries for PySide6
- Audio system dependencies
- PySide6 and NumPy Python packages

### 2. Generate Sound Files

```bash
cd sounds
python3 Download.py
cd ..
```

### 3. Run the Application

```bash
chmod +x run.sh
./run.sh
```

Or manually:
```bash
python3 main.py
```

## Manual Installation

If the setup script doesn't work, follow these steps:

### Install System Packages
```bash
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-dev \
    qt6-base-dev libqt6multimedia6 qt6-multimedia-dev \
    libgles2-mesa-dev libegl1-mesa-dev libgbm-dev libdrm-dev \
    libxkbcommon-x11-0 libxcb-xinerama0 libxcb-cursor0 \
    libasound2-dev pulseaudio libpulse-dev
```

### Install Python Packages
```bash
pip3 install --break-system-packages PySide6 numpy
```

### Generate Sound Files
```bash
cd sounds
python3 Download.py
cd ..
```

### Run the App
```bash
python3 main.py
```

## Common Issues

### "ModuleNotFoundError: No module named 'PySide6'"
```bash
pip3 install --break-system-packages PySide6
```

### "Could not load the Qt platform plugin"
```bash
export QT_QPA_PLATFORM=xcb
python3 main.py
```

### Sound not working
```bash
# Ensure PulseAudio is running
pulseaudio --check
pulseaudio --start

# Regenerate sound files
cd sounds
python3 Download.py
cd ..
```

### Display issues
```bash
# Try software rendering
export QT_QUICK_BACKEND=software
python3 main.py
```

For more troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

## Features

- **Profile Management**: Create and switch between multiple user profiles
- **Club Bag Configuration**: Customize club lofts for each profile
- **Multiple Presets**: Save different club configurations per profile
- **Shot Metrics**: View comprehensive shot data including:
  - Club Speed, Ball Speed, Smash Factor
  - Launch Angle, Spin Rate
  - Carry Distance, Total Distance
  - And more advanced metrics
- **Environmental Settings**: Configure temperature, wind, and ball type effects
- **Swipe Navigation**: Easy navigation between controls and metrics pages

## System Requirements

- Raspberry Pi 3 or newer (Pi 4/5 recommended)
- Raspberry Pi OS (Debian-based)
- 1GB+ RAM (2GB+ recommended)
- Display with touchscreen or mouse support
- Audio output (optional, for sound effects)

## File Structure

```
ProfilerV1/
├── main.py                 # Application entry point
├── ProfileManager.py       # Profile and bag data management
├── profiles.json          # Saved profiles and club data
├── main.qml               # Main window and app configuration
├── screens/
│   ├── AppWindow.qml      # Main app interface with swipe views
│   ├── ProfileScreen.qml  # Profile management
│   ├── MyBag.qml          # Club bag configuration
│   ├── SettingsScreen.qml # App settings
│   └── ...                # Other settings screens
├── sounds/
│   ├── Download.py        # Sound file generator
│   ├── click.wav          # Button click sound
│   └── success.wav        # Shot simulation sound
├── setup_raspi.sh         # Automated setup script
├── run.sh                 # Quick start script
└── requirements.txt       # Python dependencies
```

## Usage

### Creating a Profile
1. Click **Profile** button
2. Enter a name in the text field
3. Click **Save**
4. Click **Set Active** to use the new profile

### Configuring Your Bag
1. Select a profile and click **My Bag**
2. Click on any club to edit its loft angle
3. Use the **+** button to create new presets
4. Switch between presets using the dropdown

### Viewing Shot Metrics
1. Swipe right or use page indicator to go to metrics page
2. Long-press any metric to remove it
3. Click **+** button to add more metrics
4. Use **Simulate Shot** button to generate test data

### Adjusting Settings
1. Click **Settings** from main screen
2. Enable/disable environmental effects:
   - Wind Effects
   - Temperature Effects
   - Ball Type
   - Launch Angle Settings
3. Click **Configure** to adjust specific parameters

## Performance Tips for Raspberry Pi

1. **Close other applications** to free up memory
2. **Use wired network** instead of WiFi if possible
3. **Reduce animations** by editing `main.py`:
   ```python
   os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
   ```
4. **Lower resolution** if running on Pi 3 (edit dimensions in main.qml)

## Development

To modify the application:

1. **QML files** control the user interface
2. **Python files** handle logic and data management
3. **ProfileManager.py** manages JSON persistence
4. Test changes with: `python3 main.py`

## License

This is a custom golf simulator application. Modify as needed for your project.

## Support

If you encounter issues:
1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Verify all dependencies are installed
3. Check system requirements
4. Review error messages carefully

## Version

ProfilerV1 - Raspberry Pi Edition
