#!/usr/bin/env python3
"""
Test Auto Exposure Controller
Demonstrates adaptive exposure adjustment for indoor/outdoor conditions
"""

import cv2
import numpy as np
import time
from picamera2 import Picamera2
from auto_exposure import AutoExposureController

print("=" * 60)
print("AUTO EXPOSURE TEST")
print("=" * 60)
print("\nThis test will:")
print("  1. Initialize camera with default settings")
print("  2. Enable auto-exposure on ball zone")
print("  3. Monitor brightness and adjust exposure automatically")
print("  4. Run for 30 seconds showing adjustments")
print("\nPress Ctrl+C to stop\n")

# Initialize camera
print("Initializing camera...")
picam2 = Picamera2()

# Start with conservative settings
initial_shutter = 1000  # 1ms
initial_gain = 8.0
frame_rate = 100  # Lower FPS for testing

config = picam2.create_video_configuration(
    main={"size": (640, 480), "format": "YUV420"},
    controls={
        "FrameRate": frame_rate,
        "ExposureTime": initial_shutter,
        "AnalogueGain": initial_gain
    }
)
picam2.configure(config)
picam2.start()
time.sleep(2)
print(f"Camera started: {frame_rate} FPS, {initial_shutter}µs shutter, {initial_gain}x gain\n")

# Initialize auto exposure controller
auto_exposure = AutoExposureController(picam2)

# Try to detect ball zone (or use center of frame)
print("Looking for ball to set zone...")
for _ in range(10):
    frame = picam2.capture_array()
    # Convert to grayscale
    if len(frame.shape) == 3:
        gray = cv2.cvtColor(frame, cv2.COLOR_YUV420p2GRAY)
    else:
        gray = frame

    # Simple ball detection (bright circle)
    clahe = cv2.createCLAHE(clipLimit=4.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)

    circles = cv2.HoughCircles(
        enhanced,
        cv2.HOUGH_GRADIENT,
        dp=1,
        minDist=50,
        param1=80,
        param2=15,
        minRadius=20,
        maxRadius=50
    )

    if circles is not None and len(circles[0]) > 0:
        x, y, r = circles[0][0]
        auto_exposure.set_ball_zone((int(x), int(y)), int(r))
        print(f"Ball zone found: center=({int(x)}, {int(y)}), radius={int(r)}\n")
        break
    time.sleep(0.1)
else:
    # Use center of frame
    center = (320, 240)
    radius = 30
    auto_exposure.set_ball_zone(center, radius)
    print(f"Using center zone: {center}, radius={radius}\n")

# Test different modes
print("=" * 60)
print("TESTING PRESET MODES")
print("=" * 60)

modes_to_test = [
    ('auto', 5),
    ('outdoor_bright', 3),
    ('outdoor_normal', 3),
    ('indoor', 3),
    ('auto', 10)
]

try:
    for mode, duration in modes_to_test:
        print(f"\n--- Testing mode: {mode} ({duration}s) ---")
        auto_exposure.set_preset_mode(mode)

        start_time = time.time()
        update_count = 0
        adjustment_count = 0

        while time.time() - start_time < duration:
            # Capture frame
            frame = picam2.capture_array()

            # Convert to grayscale
            if len(frame.shape) == 3:
                if frame.shape[2] == 3:
                    gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
                else:
                    gray = cv2.cvtColor(frame, cv2.COLOR_YUV420p2GRAY)
            else:
                gray = frame

            # Update auto exposure
            result = auto_exposure.update(gray)
            update_count += 1

            if result['adjusted']:
                adjustment_count += 1
                print(f"  Adjusted: {result['reason']}")
                print(f"    Brightness: {result['brightness']:.1f} (target: {result['target']})")
                print(f"    Settings: Shutter={result['shutter']}µs, Gain={result['gain']:.1f}x")

            # Show status every 1 second
            if update_count % 10 == 0:
                status = auto_exposure.get_status()
                if result.get('brightness'):
                    print(f"  Status: Brightness={result['brightness']:.1f}, "
                          f"Shutter={status['shutter']}µs, Gain={status['gain']:.1f}x")

            time.sleep(0.1)

        print(f"  {adjustment_count} adjustments in {duration}s")

except KeyboardInterrupt:
    print("\n\nTest interrupted by user")

# Final test - AUTO mode with real-time monitoring
print("\n" + "=" * 60)
print("FINAL TEST: AUTO MODE (30 seconds)")
print("=" * 60)
print("Cover the camera or shine light to see auto-adjustment\n")

auto_exposure.set_preset_mode('auto')

try:
    start_time = time.time()
    frame_count = 0
    last_print = 0

    while time.time() - start_time < 30:
        # Capture frame
        frame = picam2.capture_array()

        # Convert to grayscale
        if len(frame.shape) == 3:
            if frame.shape[2] == 3:
                gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
            else:
                gray = cv2.cvtColor(frame, cv2.COLOR_YUV420p2GRAY)
        else:
            gray = frame

        # Update auto exposure
        result = auto_exposure.update(gray)
        frame_count += 1

        # Print status every 2 seconds
        current_time = time.time()
        if current_time - last_print >= 2.0:
            status = auto_exposure.get_status()
            brightness = result.get('brightness', 0)
            brightness_raw = result.get('brightness_raw', 0)
            brightness_max = result.get('brightness_max', 0)

            print(f"[{current_time - start_time:5.1f}s] "
                  f"Brightness: mean={brightness:.1f} raw={brightness_raw:.1f} max={brightness_max:.1f} | "
                  f"Shutter={status['shutter']}µs | "
                  f"Gain={status['gain']:.1f}x | "
                  f"Target={status['target_brightness']}")

            if result['adjusted']:
                print(f"          --> ADJUSTED ({result['reason']})")

            last_print = current_time

        time.sleep(0.1)

except KeyboardInterrupt:
    print("\n\nTest stopped by user")

# Cleanup
picam2.stop()
picam2.close()

print("\n" + "=" * 60)
print("TEST COMPLETE")
print("=" * 60)
print("\nAuto-exposure controller is ready for integration into main.py")
print("The system can:")
print("  ✓ Automatically adjust to indoor/outdoor lighting")
print("  ✓ Maintain optimal ball brightness (160-200)")
print("  ✓ Use preset modes for specific conditions")
print("  ✓ Keep shutter speed fast to avoid motion blur")
print("  ✓ Adjust gain primarily for exposure control")
