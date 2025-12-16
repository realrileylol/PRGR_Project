import json
import os
from PySide6.QtCore import QObject, Signal, Slot

class SettingsManager(QObject):
    """Manages application settings with JSON file persistence"""

    settingsChanged = Signal()

    def __init__(self):
        super().__init__()
        self._settings_file = os.path.join(os.path.dirname(__file__), "settings.json")
        self._settings = self._load_settings()

    def _load_settings(self):
        """Load settings from JSON file"""
        if os.path.exists(self._settings_file):
            try:
                with open(self._settings_file, 'r') as f:
                    return json.load(f)
            except Exception as e:
                print(f"Error loading settings: {e}")
                return self._get_default_settings()
        return self._get_default_settings()

    def _get_default_settings(self):
        """Return default settings structure"""
        return {
            "activeProfile": "",
            "currentClub": "7 Iron",
            "currentLoft": 34.0,
            "ballSpeed": 132.1,
            "clubSpeed": 94.0,
            "smash": 1.40,
            "spinEst": 6500,
            "carry": 180,
            "total": 192,
            "launchDeg": 16.2,
            "useSimulateButton": False,
            "useWind": False,
            "useTemp": False,
            "useBallType": False,
            "useLaunchEst": False,
            "temperature": 75.0,
            "windSpeed": 0.0,
            "windDirection": 0.0,
            "ballCompression": "Mid-High (80–90)",
            "cameraResolution": "320x240",  # 320x240 for 120+ FPS, 640x480 for 30 FPS
            "cameraFormat": "RAW"  # RAW for high FPS, YUV420 for ISP processing
        }

    def _save_settings(self):
        """Save settings to JSON file"""
        try:
            with open(self._settings_file, 'w') as f:
                json.dump(self._settings, f, indent=2)
            print(f"Settings saved to {self._settings_file}")
        except Exception as e:
            print(f"Error saving settings: {e}")

    @Slot(str, result=str)
    def getString(self, key):
        """Get a string setting"""
        return str(self._settings.get(key, ""))

    @Slot(str, result=float)
    def getNumber(self, key):
        """Get a numeric setting"""
        return float(self._settings.get(key, 0))

    @Slot(str, result=bool)
    def getBool(self, key):
        """Get a boolean setting"""
        return bool(self._settings.get(key, False))

    @Slot(str, str)
    def setString(self, key, value):
        """Set a string setting"""
        self._settings[key] = value
        self._save_settings()
        self.settingsChanged.emit()

    @Slot(str, float)
    def setNumber(self, key, value):
        """Set a numeric setting"""
        self._settings[key] = value
        self._save_settings()
        self.settingsChanged.emit()

    @Slot(str, bool)
    def setBool(self, key, value):
        """Set a boolean setting"""
        self._settings[key] = value
        self._save_settings()
        self.settingsChanged.emit()

    @Slot()
    def resetToDefaults(self):
        """Reset all settings to defaults"""
        self._settings = self._get_default_settings()
        self._save_settings()
        self.settingsChanged.emit()
        print("Settings reset to defaults")

    @Slot(result=str)
    def getAllSettingsJson(self):
        """Get all settings as JSON string"""
        return json.dumps(self._settings)
