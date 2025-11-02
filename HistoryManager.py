import json
import os
import csv
from datetime import datetime
from PySide6.QtCore import QObject, Signal, Slot

class HistoryManager(QObject):
    """Manages shot history data with JSON file persistence"""

    historyChanged = Signal()

    def __init__(self):
        super().__init__()
        self._history_file = os.path.join(os.path.dirname(__file__), "history.json")
        self._history_data = self._load_history()

    def _load_history(self):
        """Load history from JSON file"""
        if os.path.exists(self._history_file):
            try:
                with open(self._history_file, 'r') as f:
                    return json.load(f)
            except Exception as e:
                print(f"⚠️ Error loading history: {e}")
                return self._get_default_data()
        return self._get_default_data()

    def _get_default_data(self):
        """Return default history structure"""
        return {
            "shots": []
        }

    def _save_history(self):
        """Save history to JSON file"""
        try:
            with open(self._history_file, 'w') as f:
                json.dump(self._history_data, f, indent=2)
            print(f"✅ History saved to {self._history_file}")
        except Exception as e:
            print(f"⚠️ Error saving history: {e}")

    @Slot(str, str, float, float, float, float, int, int, int)
    def addShot(self, profile, club, clubSpeed, ballSpeed, smash, launch, spin, carry, total):
        """Add a new shot to history"""
        shot = {
            "timestamp": datetime.now().isoformat(),
            "profile": profile,
            "club": club,
            "clubSpeed": round(clubSpeed, 1),
            "ballSpeed": round(ballSpeed, 1),
            "smash": round(smash, 2),
            "launch": round(launch, 1),
            "spin": spin,
            "carry": carry,
            "total": total
        }

        self._history_data["shots"].append(shot)
        self._save_history()
        self.historyChanged.emit()
        print(f"📊 Shot added to history for {profile} using {club}")

    @Slot(str, result=str)
    def getHistoryForProfile(self, profile):
        """Get shot history for a specific profile as JSON string"""
        profile_shots = [
            shot for shot in self._history_data["shots"]
            if shot.get("profile") == profile
        ]
        # Return in reverse order (newest first)
        return json.dumps(profile_shots[::-1])

    @Slot(result=str)
    def getAllHistory(self):
        """Get all shot history as JSON string (newest first)"""
        return json.dumps(self._history_data["shots"][::-1])

    @Slot()
    def clearAllHistory(self):
        """Delete all shot history"""
        self._history_data = self._get_default_data()
        self._save_history()
        self.historyChanged.emit()
        print("🗑️ All history cleared")

    @Slot(str)
    def clearProfileHistory(self, profile):
        """Delete all shots for a specific profile"""
        self._history_data["shots"] = [
            shot for shot in self._history_data["shots"]
            if shot.get("profile") != profile
        ]
        self._save_history()
        self.historyChanged.emit()
        print(f"🗑️ History cleared for {profile}")

    @Slot(result=str)
    def exportToCSV(self):
        """Export all shot history to a CSV file"""
        try:
            # Generate filename with timestamp
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            export_file = os.path.join(os.path.dirname(__file__), f"shot_history_{timestamp}.csv")

            # Define CSV columns
            fieldnames = [
                'Date/Time', 'Profile', 'Club', 'Ball Speed (mph)',
                'Club Speed (mph)', 'Smash Factor', 'Launch Angle (°)',
                'Spin (rpm)', 'Carry (yds)', 'Total (yds)'
            ]

            # Write to CSV
            with open(export_file, 'w', newline='') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                writer.writeheader()

                # Write each shot (oldest first for CSV)
                for shot in self._history_data["shots"]:
                    # Parse timestamp
                    try:
                        dt = datetime.fromisoformat(shot.get("timestamp", ""))
                        date_time = dt.strftime("%Y-%m-%d %H:%M:%S")
                    except:
                        date_time = shot.get("timestamp", "Unknown")

                    writer.writerow({
                        'Date/Time': date_time,
                        'Profile': shot.get('profile', 'Unknown'),
                        'Club': shot.get('club', 'N/A'),
                        'Ball Speed (mph)': shot.get('ballSpeed', 0),
                        'Club Speed (mph)': shot.get('clubSpeed', 0),
                        'Smash Factor': shot.get('smash', 0),
                        'Launch Angle (°)': shot.get('launch', 0),
                        'Spin (rpm)': shot.get('spin', 0),
                        'Carry (yds)': shot.get('carry', 0),
                        'Total (yds)': shot.get('total', 0)
                    })

            print(f"📄 History exported to {export_file}")
            return export_file

        except Exception as e:
            print(f"❌ Error exporting history: {e}")
            return ""
