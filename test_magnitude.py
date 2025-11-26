#!/usr/bin/env python3
"""
Test script to monitor K-LD2 radar magnitude values
Optimized for FAR-FIELD detection (4+ feet)
Shows speed and signal strength (dB) in real-time
"""
import sys
import time
from kld2_manager import KLD2Manager

def main():
    print("\n" + "="*70)
    print("  K-LD2 Far-Field Detection Calibration (4+ feet)")
    print("="*70)
    print("\nGOAL: Detect swings at 4+ feet, ignore close-range movements")
    print("\nThis test will show magnitude values at different distances.")
    print("\nTest procedure:")
    print("  1. Stand/wave at CLOSE range (< 1 foot) - note magnitude")
    print("  2. Swing at MEDIUM range (2-3 feet) - note magnitude")
    print("  3. Swing at FAR range (4-6 feet) - note magnitude")
    print("\nMagnitude pattern to expect:")
    print("  - Close (< 1 ft): 70-90+ dB (STRONG)")
    print("  - Medium (2-3 ft): 50-70 dB")
    print("  - Far (4-6 ft): 20-50 dB (WEAK)")
    print("\nSet thresholds to:")
    print("  - min_magnitude_db: Just below your far-field values")
    print("  - max_magnitude_db: Just below your close-range values")
    print("\nPress Ctrl+C to exit\n")
    print("="*70)

    # Create KLD2Manager with:
    # - min_trigger_speed=5.0 (very low to catch all swings)
    # - min_magnitude_db=0 (see everything)
    # - max_magnitude_db=999 (no filtering)
    # - sensitivity=9 (maximum sensitivity for far-field)
    # - debug_mode=True (verbose output)
    kld2 = KLD2Manager(
        min_trigger_speed=5.0,
        min_magnitude_db=0,
        max_magnitude_db=999,
        sensitivity=9,  # Maximum sensitivity for far-field detection
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
        print("Calibration complete!")
        print("="*70)
        print("\nNow you know the magnitude values at different distances.")
        print("\nTo optimize for 4+ feet detection, edit main.py line 2149:")
        print("  kld2_manager = KLD2Manager(")
        print("      min_trigger_speed=10.0,")
        print("      min_magnitude_db=XX,   # Set to ~5 below far-field value")
        print("      max_magnitude_db=YY,   # Set to ~5 below close-range value")
        print("      sensitivity=9,         # Max sensitivity for far-field")
        print("      debug_mode=True")
        print("  )")
        print("\nExample for 4+ feet:")
        print("  If far-field shows 30-40 dB and close shows 70+ dB:")
        print("    min_magnitude_db=25    (accept weak far signals)")
        print("    max_magnitude_db=65    (reject strong close signals)")
        print("="*70 + "\n")

    return 0

if __name__ == "__main__":
    sys.exit(main())
