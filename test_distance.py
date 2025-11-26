#!/usr/bin/env python3
"""
Distance Detection Test
Tests if radar can detect motion at different distances
"""
import sys
import time
from kld2_manager import KLD2Manager

def main():
    print("\n" + "="*70)
    print("  K-LD2 Distance Detection Test")
    print("="*70)
    print("\nPURPOSE: Find the maximum distance the radar can detect motion")
    print("\nSetup:")
    print("  [Radar] ----4-5 feet----> [Ball location]")
    print("\nTest procedure:")
    print("  1. Start at 1 foot from radar")
    print("  2. Hold club/hand and push TOWARD radar, pull AWAY")
    print("  3. Note if you see detection")
    print("  4. Step back to 2 feet, repeat")
    print("  5. Step back to 3 feet, repeat")
    print("  6. Step back to 4 feet, repeat")
    print("  7. Step back to 5 feet, repeat")
    print("\nIMPORTANT:")
    print("  - Move TOWARD and AWAY from radar (not sideways!)")
    print("  - Keep movements at waist height (where clubhead would be)")
    print("  - Make BIG, FAST movements")
    print("\nPress Ctrl+C to exit\n")
    print("="*70)

    kld2 = KLD2Manager(
        min_trigger_speed=3.0,
        min_magnitude_db=0,
        max_magnitude_db=999,
        sensitivity=9,
        debug_mode=False  # Clean output
    )

    detection_count = 0
    last_speed = 0
    last_magnitude = 0

    def on_speed_updated(speed_mph):
        nonlocal detection_count, last_speed, last_magnitude
        if speed_mph >= 3.0:
            detection_count += 1
            last_speed = speed_mph
            last_magnitude = kld2.get_current_magnitude()
            print(f"\n{'='*70}")
            print(f"  ✅ DETECTED #{detection_count}")
            print(f"  Speed: {speed_mph:.1f} mph")
            print(f"  Magnitude: {last_magnitude} dB")
            print(f"{'='*70}\n")
            print("Move to next distance and repeat...")

    kld2.speedUpdated.connect(on_speed_updated)

    if not kld2.start():
        print("Failed to start K-LD2!")
        return 1

    print("\n✅ Radar ready!")
    print("\nStart at 1 FOOT from radar:")
    print("  - Push club/hand TOWARD radar")
    print("  - Pull AWAY from radar")
    print("  - Watch for detection above ↑")
    print("\nWaiting for motion...\n")

    try:
        while True:
            time.sleep(0.1)

    except KeyboardInterrupt:
        print("\n\nStopping...")

    finally:
        kld2.stop()
        print(f"\n{'='*70}")
        print("Test Results")
        print(f"{'='*70}")
        print(f"Total detections: {detection_count}")
        if last_magnitude > 0:
            print(f"Last magnitude: {last_magnitude} dB")

        if detection_count == 0:
            print("\n⚠️  NO DETECTIONS AT ANY DISTANCE!")
            print("\nTroubleshooting:")
            print("  1. Check radar angle - tilt UP 15-20°")
            print("  2. Verify you're moving TOWARD/AWAY (not sideways)")
            print("  3. Make movements at waist height")
            print("  4. Try BIGGER, FASTER movements")
            print("  5. Check radar is powered and connected")
        else:
            print(f"\n✅ Radar is working!")
            print(f"\nWhat distance gave detections?")
            print(f"  1 foot? - Radar works close")
            print(f"  2-3 feet? - Radar works medium range")
            print(f"  4-5 feet? - Radar works at ball distance! ✅")
            print(f"\nIf only 1-2 feet worked:")
            print(f"  - Try tilting radar UP more")
            print(f"  - Check angle aims at ball location, not ground")

    return 0

if __name__ == "__main__":
    sys.exit(main())
