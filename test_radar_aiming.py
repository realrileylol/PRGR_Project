#!/usr/bin/env python3
"""
Radar Aiming Diagnostic Tool
Helps find the optimal angle/position for K-LD2 radar

This tool shows BIG VISUAL alerts when it detects motion,
making it easy to see from across the room while adjusting the radar.
"""
import sys
import time
from kld2_manager import KLD2Manager

def clear_screen():
    """Clear the terminal screen"""
    print("\033[2J\033[H", end='', flush=True)

def print_detection_banner(speed, magnitude, count):
    """Print a big visual banner when motion detected"""
    print("\n" + "="*70)
    print("█" * 70)
    print("█" + " " * 68 + "█")
    print(f"█    *** DETECTED #{count} ***    Speed: {speed:.1f} mph    Magnitude: {magnitude} dB    █".center(70))
    print("█" + " " * 68 + "█")
    print("█" * 70)
    print("="*70 + "\n")

def main():
    clear_screen()
    print("\n" + "="*70)
    print("  K-LD2 Radar Aiming Tool (Visual Mode)")
    print("="*70)
    print("\nThis tool shows BIG VISUAL ALERTS when it detects motion.")
    print("\nHow to use:")
    print("  1. Point radar DIRECTLY at the ball location (5-6 feet away)")
    print("  2. Tilt UP about 15-20° (aim at waist height, not ground)")
    print("  3. Wave arms or swing club at the BALL LOCATION")
    print("  4. Move TOWARD/AWAY from radar (not side-to-side!)")
    print("  5. Watch for BIG █████ DETECTED █████ banners")
    print("\nTips:")
    print("  - NO DETECTION? Tilt radar UP more (aim higher)")
    print("  - Still nothing? Try tilting DOWN (maybe too high)")
    print("  - Move TOWARD radar, not perpendicular")
    print("  - Try bigger, faster arm movements first")
    print("\nWatching for motion at 5-6 feet...")
    print("Press Ctrl+C to exit\n")
    print("="*70)

    kld2 = KLD2Manager(
        min_trigger_speed=3.0,  # Very low to catch any movement
        min_magnitude_db=0,
        max_magnitude_db=999,
        sensitivity=9,
        debug_mode=True
    )

    detection_count = 0
    last_detection_time = 0

    def on_speed_updated(speed_mph):
        nonlocal detection_count, last_detection_time
        if speed_mph >= 5.0:
            detection_count += 1
            # Show banner at most once per second
            now = time.time()
            if now - last_detection_time > 1.0:
                magnitude = kld2.get_current_magnitude()
                print_detection_banner(speed_mph, magnitude, detection_count)
                last_detection_time = now

    kld2.speedUpdated.connect(on_speed_updated)

    if not kld2.start():
        print("Failed to start K-LD2!")
        return 1

    print("\n✅ Radar active - watching for motion at 5-6 feet...")
    print("   (Big █████ banners will appear when motion is detected)\n")

    try:
        while True:
            time.sleep(0.1)

    except KeyboardInterrupt:
        print("\n\nStopping...")

    finally:
        kld2.stop()
        print(f"\n📊 Total detections: {detection_count}")
        if detection_count == 0:
            print("\n⚠️  NO DETECTIONS AT 5-6 FEET!")
            print("\n   Possible issues:")
            print("   1. Angle too low - Tilt radar UP more (aim at waist height)")
            print("   2. Angle too high - Try tilting DOWN a bit")
            print("   3. Wrong motion - Move TOWARD/AWAY from radar, not sideways")
            print("   4. Not aimed at ball - Point directly at hitting zone")
            print("   5. Too slow - Try bigger, faster arm movements")
            print("\n   Try these angles systematically:")
            print("     - Start at 10° up → test")
            print("     - Then 20° up → test")
            print("     - Then 30° up → test")
            print("     - Find which one gives detections!")
        else:
            print("\n✅ Radar is detecting! Check the magnitude values:")
            print("   - If 60+ dB: Detecting close range (good!)")
            print("   - If 30-60 dB: Detecting medium range")
            print("   - If <30 dB: May be noise or very weak signal")
            print("\n   Now test at the actual ball location (5-6 ft away)")

    return 0

if __name__ == "__main__":
    sys.exit(main())
