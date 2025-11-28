#!/usr/bin/env python3
"""
Analyze K-LD2 Frame Capture Data
Reads CSV from capture_radar_frames.py and provides diagnostic insights
"""
import csv
import sys
import os
from collections import defaultdict

def analyze_capture(csv_filename):
    """Analyze radar capture CSV file"""

    if not os.path.exists(csv_filename):
        print(f"❌ File not found: {csv_filename}")
        return

    print("\n" + "="*80)
    print(f"  ANALYZING: {csv_filename}")
    print("="*80 + "\n")

    # Read all data
    frames = []
    with open(csv_filename, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                frames.append({
                    'timestamp_ms': float(row['timestamp_ms']),
                    'detected': row['detected'] == 'True',
                    'direction': row['direction'],
                    'speed_bin': int(row['speed_bin']),
                    'magnitude_db': int(row['magnitude_db']),
                    'speed_mph': float(row['speed_mph']),
                    'doppler_hz': float(row['doppler_hz'])
                })
            except Exception as e:
                print(f"Warning: Could not parse row: {e}")
                continue

    if not frames:
        print("❌ No frames found in file")
        return

    # Filter to detections only
    detections = [f for f in frames if f['detected'] and f['speed_mph'] >= 1.0]

    print(f"📊 SUMMARY")
    print(f"{'─'*80}")
    print(f"Total frames captured:        {len(frames)}")
    print(f"Frames with detection:        {len(detections)}")
    print(f"Duration:                     {frames[-1]['timestamp_ms']/1000:.1f} seconds")
    print(f"Average frame rate:           {len(frames)/(frames[-1]['timestamp_ms']/1000):.1f} Hz")

    if not detections:
        print("\n⚠️ No detections with speed >= 1.0 mph found")
        return

    # Speed statistics
    speeds = [f['speed_mph'] for f in detections]
    bins = [f['speed_bin'] for f in detections]
    magnitudes = [f['magnitude_db'] for f in detections]

    max_speed = max(speeds)
    max_speed_frame = detections[speeds.index(max_speed)]

    avg_speed = sum(speeds) / len(speeds)

    print(f"\n🎯 SPEED STATISTICS")
    print(f"{'─'*80}")
    print(f"Maximum speed detected:       {max_speed:.2f} mph")
    print(f"  └─ At bin value:            {max_speed_frame['speed_bin']}")
    print(f"  └─ Doppler frequency:       {max_speed_frame['doppler_hz']:.1f} Hz")
    print(f"  └─ Magnitude:               {max_speed_frame['magnitude_db']} dB")
    print(f"  └─ Direction:               {max_speed_frame['direction']}")
    print(f"  └─ Timestamp:               {max_speed_frame['timestamp_ms']:.0f} ms")
    print(f"\nAverage detection speed:      {avg_speed:.2f} mph")
    print(f"Minimum speed detected:       {min(speeds):.2f} mph")

    # Bin analysis
    print(f"\n📈 BIN VALUE ANALYSIS")
    print(f"{'─'*80}")
    print(f"Maximum bin value:            {max(bins)}")
    print(f"Average bin value:            {sum(bins)/len(bins):.1f}")
    print(f"Bin range:                    {min(bins)} - {max(bins)}")

    # What bin values would we expect for different speeds?
    print(f"\n🔍 EXPECTED BIN VALUES (at 2560 Hz sampling):")
    print(f"{'─'*80}")
    expected_speeds = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
    for mph in expected_speeds:
        # Reverse the conversion formula
        # speed_mph = bin × (sampling_rate / 256 / 44.7) × 0.621371
        # bin = speed_mph / ((sampling_rate / 256 / 44.7) × 0.621371)
        expected_bin = mph / ((2560 / 256 / 44.7) * 0.621371)
        print(f"  {mph:3d} mph → bin {expected_bin:6.1f}")

    if max(bins) < 100:
        print(f"\n⚠️  WARNING: Maximum bin value is {max(bins)}, which is quite low")
        print(f"    For 40+ mph club speeds, we'd expect bins > 200")
        print(f"    This suggests the radar is not detecting the full club speed")

    # Magnitude analysis
    print(f"\n📶 SIGNAL STRENGTH (Magnitude)")
    print(f"{'─'*80}")
    print(f"Maximum magnitude:            {max(magnitudes)} dB")
    print(f"Average magnitude:            {sum(magnitudes)/len(magnitudes):.1f} dB")
    print(f"Minimum magnitude:            {min(magnitudes)} dB")

    # Magnitude ranges
    mag_ranges = {
        '85+ dB (< 1 ft)': len([m for m in magnitudes if m >= 85]),
        '80-84 dB (~2 ft)': len([m for m in magnitudes if 80 <= m < 85]),
        '75-79 dB (~3 ft)': len([m for m in magnitudes if 75 <= m < 80]),
        '65-74 dB (~4 ft)': len([m for m in magnitudes if 65 <= m < 75]),
        '< 65 dB (> 4 ft)': len([m for m in magnitudes if m < 65])
    }

    print(f"\nDistance distribution:")
    for range_label, count in mag_ranges.items():
        if count > 0:
            pct = (count / len(magnitudes)) * 100
            print(f"  {range_label:20s} {count:4d} detections ({pct:5.1f}%)")

    # Direction analysis
    print(f"\n🧭 DIRECTION ANALYSIS")
    print(f"{'─'*80}")
    directions = defaultdict(int)
    for f in detections:
        directions[f['direction']] += 1

    for direction, count in directions.items():
        pct = (count / len(detections)) * 100
        print(f"  {direction:15s} {count:4d} detections ({pct:5.1f}%)")

    # Find swing events (bursts of detections)
    print(f"\n🏌️  SWING DETECTION")
    print(f"{'─'*80}")

    # Group detections within 2 seconds of each other
    swings = []
    current_swing = []
    last_timestamp = 0

    for f in detections:
        if not current_swing or (f['timestamp_ms'] - last_timestamp) < 2000:
            current_swing.append(f)
        else:
            if current_swing:
                swings.append(current_swing)
            current_swing = [f]
        last_timestamp = f['timestamp_ms']

    if current_swing:
        swings.append(current_swing)

    print(f"Detected {len(swings)} swing event(s)\n")

    for i, swing in enumerate(swings, 1):
        swing_speeds = [f['speed_mph'] for f in swing]
        swing_bins = [f['speed_bin'] for f in swing]
        swing_peak = max(swing_speeds)
        swing_peak_bin = max(swing_bins)
        swing_duration = swing[-1]['timestamp_ms'] - swing[0]['timestamp_ms']

        print(f"Swing #{i}:")
        print(f"  Duration:     {swing_duration:.0f} ms")
        print(f"  Detections:   {len(swing)}")
        print(f"  Peak speed:   {swing_peak:.2f} mph (bin={swing_peak_bin})")
        print(f"  Avg speed:    {sum(swing_speeds)/len(swing_speeds):.2f} mph")
        print(f"  Start time:   {swing[0]['timestamp_ms']:.0f} ms")
        print()

    # Conclusions
    print(f"\n💡 DIAGNOSTIC INSIGHTS")
    print(f"{'─'*80}")

    if max(bins) < 50:
        print("⚠️  CRITICAL: Maximum bin value < 50")
        print("   This is extremely low. Possible causes:")
        print("   1. Radar sensitivity too low (check $D01 setting)")
        print("   2. Club motion is perpendicular to radar beam")
        print("   3. Hardware limitation of K-LD2 for this use case")
        print("   4. Radar sampling rate misconfigured")
    elif max(bins) < 100:
        print("⚠️  WARNING: Maximum bin value < 100")
        print("   This suggests limited radial velocity detection.")
        print("   The club's motion path may be mostly perpendicular to the radar.")
    elif max(bins) < 200:
        print("⚠️  NOTICE: Maximum bin value < 200")
        print("   Getting closer but still lower than expected for full swings.")
        print("   Expected bins > 200 for 40+ mph speeds.")
    else:
        print("✅ Bin values look reasonable for golf club detection")

    if avg_magnitude := sum(magnitudes)/len(magnitudes):
        if avg_magnitude > 80:
            print("\n📍 Most detections are close range (< 2 ft)")
            print("   Consider testing at greater distance from radar")
        elif avg_magnitude < 65:
            print("\n📍 Most detections are far range (> 4 ft)")
            print("   Signal may be too weak at this distance")
        else:
            print(f"\n✅ Average magnitude {avg_magnitude:.1f} dB is in good range")

    print(f"\n{'='*80}\n")


def main():
    if len(sys.argv) < 2:
        # Find most recent capture file
        import glob
        files = glob.glob("/home/user/PRGR_Project/radar_capture_*.csv")
        if not files:
            print("❌ No capture files found")
            print("Usage: python3 analyze_radar_capture.py <csv_file>")
            print("   or: python3 analyze_radar_capture.py  (uses most recent)")
            return

        # Sort by modification time
        files.sort(key=os.path.getmtime, reverse=True)
        csv_filename = files[0]
        print(f"Using most recent file: {os.path.basename(csv_filename)}")
    else:
        csv_filename = sys.argv[1]

    analyze_capture(csv_filename)


if __name__ == "__main__":
    main()
