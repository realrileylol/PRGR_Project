#!/usr/bin/env python3
"""
Test script to monitor K-LD2 radar magnitude values
Shows speed and signal strength (dB) in real-time
"""
import sys
import time
from kld2_manager import KLD2Manager

def main():
    print("\n" + "="*70)
    print("  K-LD2 Magnitude (Signal Strength) Test")
    print("="*70)
    print("\nThis test will show you the magnitude values at different distances.")
    print("Try swinging at:")
    print("  - Close range (< 1 foot)")
    print("  - Medium range (1-2 feet)")
    print("  - Far range (2-4 feet)")
    print("\nWatch the magnitude (dB) values to see how they change with distance.")
    print("\nPress Ctrl+C to exit\n")
    print("="*70)

    # Create KLD2Manager with:
    # - min_trigger_speed=5.0 (very low to catch all swings)
    # - min_magnitude_db=0 (no filtering - see everything)
    # - debug_mode=True (verbose output)
    kld2 = KLD2Manager(
        min_trigger_speed=5.0,
        min_magnitude_db=0,
        debug_mode=True
    )

    # Start the radar
    if not kld2.start():
        print("Failed to start K-LD2!")
        return 1

    print("\n🎯 K-LD2 started - watching for motion...")
    print("   (Swing your club at different distances)\n")

    try:
        # Keep running until user presses Ctrl+C
        while True:
            time.sleep(1)

    except KeyboardInterrupt:
        print("\n\nStopping...")

    finally:
        kld2.stop()
        print("\n" + "="*70)
        print("Test complete!")
        print("="*70)
        print("\nNow you know the magnitude values at different distances.")
        print("To set a threshold, edit main.py line 2149 and add:")
        print("  min_magnitude_db=XX  (where XX is your threshold)")
        print("="*70 + "\n")

    return 0

if __name__ == "__main__":
    sys.exit(main())
