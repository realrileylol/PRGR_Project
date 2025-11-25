#!/usr/bin/env python3
"""
K-LD2 Radar Positioning Test Tool

This script helps you find the optimal positioning and orientation for the K-LD2 radar sensor.
It shows ALL detections regardless of speed, helping you understand what the radar sees.

The K-LD2 detects motion using the Doppler effect along its beam axis:
- Best detection: Object moving TOWARD or AWAY from the sensor
- Poor detection: Object moving perpendicular to the beam
- No detection: Object moving across the beam (90° to sensor axis)

For golf swing detection:
- Point the sensor DOWN THE LINE (towards target or towards golfer)
- NOT across the swing path
- The clubhead should be moving toward/away from the sensor at impact
"""

import sys
from kld2_manager import KLD2Manager
from PySide6.QtCore import QCoreApplication, QTimer

def print_usage():
    print("\n" + "="*70)
    print("K-LD2 RADAR POSITIONING TEST")
    print("="*70)
    print("\nDETECTION PRINCIPLES:")
    print("  • Radar detects motion along its beam axis (Doppler effect)")
    print("  • BEST: Object moving directly toward/away from sensor")
    print("  • POOR: Object at an angle to sensor")
    print("  • NONE: Object moving perpendicular (across) sensor beam")
    print("\nFOR GOLF SETUP:")
    print("  1. Point sensor DOWN THE LINE (toward target or golfer)")
    print("  2. NOT across the swing path")
    print("  3. Height: Aim at impact zone (ball height)")
    print("  4. Distance: 3-6 feet from impact point")
    print("\nTESTING PROCEDURE:")
    print("  1. Wave your hand rapidly in front of sensor (close range)")
    print("  2. Move around sensor to find detection 'dead zones'")
    print("  3. Swing club toward/away from sensor")
    print("  4. Try different angles to find best orientation")
    print("\nWatch the output below - it will show EVERY detection:")
    print("="*70 + "\n")

class RadarTester:
    def __init__(self):
        self.app = QCoreApplication(sys.argv)

        # Create K-LD2 manager with very sensitive settings
        self.kld2 = KLD2Manager(
            min_trigger_speed=5.0,  # Very low threshold
            debug_mode=True  # Show ALL detections
        )

        # Connect signals
        self.kld2.speedUpdated.connect(self.on_speed_updated)
        self.kld2.detectionTriggered.connect(self.on_detection_triggered)
        self.kld2.statusChanged.connect(self.on_status_changed)

        self.detection_count = 0
        self.max_speed_seen = 0.0

    def on_speed_updated(self, speed_mph):
        """Called whenever radar detects motion"""
        if speed_mph > self.max_speed_seen:
            self.max_speed_seen = speed_mph
            print(f"\n🏆 NEW MAX SPEED: {speed_mph:.1f} mph")

    def on_detection_triggered(self):
        """Called when detection exceeds trigger threshold"""
        self.detection_count += 1
        print(f"\n🎯 TRIGGER #{self.detection_count} - Would capture frame!")

    def on_status_changed(self, message, color):
        """Called on status changes"""
        print(f"[STATUS] {message}")

    def run(self):
        """Start the test"""
        print_usage()

        print("Starting K-LD2 radar...")
        if not self.kld2.start():
            print("❌ Failed to start K-LD2 radar!")
            print("Check connections and port settings.")
            return 1

        print("✅ K-LD2 radar active - monitoring for motion...")
        print("   Press Ctrl+C to stop\n")

        # Print stats every 10 seconds
        def print_stats():
            print(f"\n📊 STATS: Max speed: {self.max_speed_seen:.1f} mph, "
                  f"Triggers: {self.detection_count}")

        timer = QTimer()
        timer.timeout.connect(print_stats)
        timer.start(10000)  # Every 10 seconds

        try:
            return self.app.exec()
        except KeyboardInterrupt:
            print("\n\n" + "="*70)
            print("STOPPING...")
            print("="*70)
            self.kld2.stop()
            print(f"\nFINAL STATS:")
            print(f"  Max speed detected: {self.max_speed_seen:.1f} mph")
            print(f"  Total triggers: {self.detection_count}")
            print("\nTIPS FOR BETTER DETECTION:")
            if self.max_speed_seen < 10:
                print("  ⚠️ Very low speeds detected - check sensor orientation!")
                print("     • Ensure sensor is pointed DOWN THE LINE")
                print("     • Object should move toward/away from sensor")
                print("     • Try repositioning sensor angle")
            elif self.max_speed_seen < 30:
                print("  ⚡ Moderate speeds detected - getting closer!")
                print("     • Fine-tune sensor angle")
                print("     • Check distance (3-6 feet optimal)")
            else:
                print("  ✅ Good speeds detected - sensor positioned well!")
            print("")
            return 0

if __name__ == "__main__":
    tester = RadarTester()
    sys.exit(tester.run())
