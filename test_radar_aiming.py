#!/usr/bin/env python3
"""
Radar Aiming Diagnostic Tool
Helps find the optimal angle/position for K-LD2 radar

This tool makes a BEEP sound when it detects motion,
helping you aim the radar without looking at the screen.
"""
import sys
import time
from kld2_manager import KLD2Manager
import subprocess

def beep():
    """Make a beep sound"""
    try:
        subprocess.run(['aplay', '-q', '/usr/share/sounds/alsa/Front_Center.wav'],
                      timeout=0.5, stderr=subprocess.DEVNULL)
    except:
        # Fallback to console beep
        print('\a', end='', flush=True)

def main():
    print("\n" + "="*70)
    print("  K-LD2 Radar Aiming Tool")
    print("="*70)
    print("\nThis tool will BEEP when it detects motion.")
    print("\nHow to use:")
    print("  1. Point radar in a direction")
    print("  2. Wave your hand or swing club in front")
    print("  3. Listen for BEEP (means detection!)")
    print("  4. Adjust angle until you hear beeps at 5-6 feet")
    print("\nTips:")
    print("  - Start by aiming DIRECTLY at the ball spot")
    print("  - Tilt UP about 15-20 degrees (aim at waist height)")
    print("  - If no beeps at 5-6 ft, try tilting more UP or DOWN")
    print("  - Try moving the club TOWARD the radar, not across")
    print("\nPress Ctrl+C to exit\n")
    print("="*70)

    kld2 = KLD2Manager(
        min_trigger_speed=3.0,  # Very low to catch any movement
        min_magnitude_db=0,
        max_magnitude_db=999,
        sensitivity=9,
        debug_mode=True
    )

    detection_count = 0
    last_beep_time = 0

    def on_speed_updated(speed_mph):
        nonlocal detection_count, last_beep_time
        if speed_mph >= 5.0:
            detection_count += 1
            # Beep at most once per second
            now = time.time()
            if now - last_beep_time > 1.0:
                beep()
                last_beep_time = now
                print(f"\n🔊 BEEP! Detection #{detection_count}")

    kld2.speedUpdated.connect(on_speed_updated)

    if not kld2.start():
        print("Failed to start K-LD2!")
        return 1

    print("\n✅ Radar active - start testing different angles!")
    print("   (You'll hear a BEEP when motion is detected)\n")

    try:
        while True:
            time.sleep(0.1)

    except KeyboardInterrupt:
        print("\n\nStopping...")

    finally:
        kld2.stop()
        print(f"\n📊 Total detections: {detection_count}")
        if detection_count == 0:
            print("\n⚠️  NO DETECTIONS!")
            print("   Try these fixes:")
            print("   1. Tilt radar UP more (aim higher)")
            print("   2. Move the club TOWARD/AWAY from radar, not across")
            print("   3. Try a bigger, faster arm wave first")
            print("   4. Check radar is pointed AT the ball location")
        else:
            print("\n✅ Radar is detecting! Now fine-tune the angle.")

    return 0

if __name__ == "__main__":
    sys.exit(main())
