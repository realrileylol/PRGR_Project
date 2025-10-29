import json
import os
from PySide6.QtCore import QObject, Signal, Slot, Property

class ProfileManager(QObject):
    """Manages profile and bag data with JSON file persistence"""
    
    profilesChanged = Signal()
    activeProfileChanged = Signal()
    
    def __init__(self):
        super().__init__()
        self._profiles_file = os.path.join(os.path.dirname(__file__), "profiles.json")
        self._profiles_data = self._load_profiles()
        self._active_profile = self._profiles_data.get("active_profile", "Guest")
    
    def _load_profiles(self):
        """Load profiles from JSON file"""
        if os.path.exists(self._profiles_file):
            try:
                with open(self._profiles_file, 'r') as f:
                    return json.load(f)
            except Exception as e:
                print(f"⚠️ Error loading profiles: {e}")
                return self._get_default_data()
        return self._get_default_data()
    
    def _get_default_data(self):
        """Return default profile structure"""
        return {
            "active_profile": "Guest",
            "profiles": ["Guest"],
            "bags": {
                "Guest": {
                    "Default Set": {
                        "Driver": 10.5,
                        "3 Wood": 15.0,
                        "5 Wood": 18.0,
                        "3 Hybrid": 19.0,
                        "4 Iron": 21.0,
                        "5 Iron": 24.0,
                        "6 Iron": 28.0,
                        "7 Iron": 34.0,
                        "8 Iron": 38.0,
                        "9 Iron": 42.0,
                        "PW": 46.0,
                        "GW": 50.0,
                        "SW": 56.0,
                        "LW": 60.0
                    }
                }
            },
            "active_presets": {
                "Guest": "Default Set"
            }
        }
    
    def _save_profiles(self):
        """Save profiles to JSON file"""
        try:
            with open(self._profiles_file, 'w') as f:
                json.dump(self._profiles_data, f, indent=2)
            print(f"✅ Profiles saved to {self._profiles_file}")
        except Exception as e:
            print(f"⚠️ Error saving profiles: {e}")
    
    @Slot(str, result=str)
    def getProfilesJson(self, key):
        """Get a JSON string for QML"""
        if key == "profiles":
            return json.dumps(self._profiles_data.get("profiles", []))
        elif key == "bags":
            return json.dumps(self._profiles_data.get("bags", {}))
        elif key == "active_presets":
            return json.dumps(self._profiles_data.get("active_presets", {}))
        return "[]"
    
    @Slot(str, str)
    def saveProfilesJson(self, key, json_str):
        """Save JSON data from QML"""
        try:
            data = json.loads(json_str)
            self._profiles_data[key] = data
            self._save_profiles()
            self.profilesChanged.emit()
        except Exception as e:
            print(f"⚠️ Error saving {key}: {e}")
    
    @Slot(str)
    def setActiveProfile(self, profile_name):
        """Set the active profile"""
        self._active_profile = profile_name
        self._profiles_data["active_profile"] = profile_name
        self._save_profiles()
        self.activeProfileChanged.emit()
    
    @Slot(result=str)
    def getActiveProfile(self):
        """Get the active profile name"""
        return self._active_profile
    
    @Slot(str)
    def createProfile(self, profile_name):
        """Create a new profile with default bag"""
        if profile_name and profile_name not in self._profiles_data["profiles"]:
            self._profiles_data["profiles"].append(profile_name)
            
            # Copy default bag structure
            default_bag = self._get_default_data()["bags"]["Guest"]["Default Set"]
            self._profiles_data["bags"][profile_name] = {
                "Default Set": default_bag.copy()
            }
            self._profiles_data["active_presets"][profile_name] = "Default Set"
            
            self._save_profiles()
            self.profilesChanged.emit()
    
    @Slot(str)
    def deleteProfile(self, profile_name):
        """Delete a profile"""
        if profile_name in self._profiles_data["profiles"] and profile_name != "Guest":
            self._profiles_data["profiles"].remove(profile_name)
            
            # Remove associated data
            if profile_name in self._profiles_data["bags"]:
                del self._profiles_data["bags"][profile_name]
            if profile_name in self._profiles_data["active_presets"]:
                del self._profiles_data["active_presets"][profile_name]
            
            # If deleting active profile, switch to Guest
            if self._active_profile == profile_name:
                self._active_profile = "Guest"
                self._profiles_data["active_profile"] = "Guest"
            
            self._save_profiles()
            self.profilesChanged.emit()
            self.activeProfileChanged.emit()
    
    @Slot(str, str, str)
    def saveBagPreset(self, profile_name, preset_name, clubs_json):
        """Save a bag preset for a profile"""
        try:
            clubs = json.loads(clubs_json)
            
            if profile_name not in self._profiles_data["bags"]:
                self._profiles_data["bags"][profile_name] = {}
            
            self._profiles_data["bags"][profile_name][preset_name] = clubs
            self._save_profiles()
            self.profilesChanged.emit()
        except Exception as e:
            print(f"⚠️ Error saving bag preset: {e}")
    
    @Slot(str, str, result=str)
    def getBagPreset(self, profile_name, preset_name):
        """Get a bag preset for a profile"""
        try:
            if profile_name in self._profiles_data["bags"]:
                if preset_name in self._profiles_data["bags"][profile_name]:
                    return json.dumps(self._profiles_data["bags"][profile_name][preset_name])
        except Exception as e:
            print(f"⚠️ Error getting bag preset: {e}")
        
        # Return default
        return json.dumps(self._get_default_data()["bags"]["Guest"]["Default Set"])
    
    @Slot(str, str)
    def setActivePreset(self, profile_name, preset_name):
        """Set the active preset for a profile"""
        self._profiles_data["active_presets"][profile_name] = preset_name
        self._save_profiles()