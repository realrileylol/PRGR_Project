#!/usr/bin/env python3
"""
Simple camera frame capture test for spin detection development.
Captures frames from Raspberry Pi camera using picamera2.
Now reads camera settings from your GUI configuration!
"""

import time
import numpy as np
from picamera2 import Picamera2
import cv2
from SettingsManager import SettingsManager

def test_camera_capture():
    """Capture and save test frames from camera"""

    print("🎥 Initializing camera...")

    # Load camera settings from GUI
    settings_manager = SettingsManager()
    shutter_speed = int(settings_manager.getNumber("cameraShutterSpeed") or 5000)
    gain = float(settings_manager.getNumber("cameraGain") or 2.0)
    frame_rate = int(settings_manager.getNumber("cameraFrameRate") or 30)
    time_of_day = settings_manager.getString("cameraTimeOfDay") or "Cloudy/Shade"

    print(f"📷 Using saved settings from GUI:")
    print(f"   Time of Day: {time_of_day}")
    print(f"   Shutter: {shutter_speed}µs")
    print(f"   Gain: {gain}x")
    print(f"   Frame Rate: {frame_rate} fps")
    print()

    # Initialize camera
    picam2 = Picamera2()

    # Configure with your saved settings
    config = picam2.create_video_configuration(
        main={"size": (640, 480), "format": "RGB888"},
        controls={
            "FrameRate": frame_rate,
            "ExposureTime": shutter_speed,
            "AnalogueGain": gain
        }
    )

    picam2.configure(config)
    picam2.start()

    # Let camera warm up
    time.sleep(2)

    print("✅ Camera ready!")
    print("\n📸 Instructions:")
    print("  1. Position ball 4-5 feet from camera")
    print("  2. Make sure dots are visible")
    print("  3. Press ENTER to capture 10 frames")
    print("  4. Gently toss/roll ball after pressing ENTER")

    input("\nPress ENTER when ready...")

    frames = []
    print("\n📷 Capturing frames...")

    # Capture 10 frames rapidly
    frame_delay = 1.0 / frame_rate  # Spacing based on your frame rate setting
    for i in range(10):
        frame = picam2.capture_array()
        frames.append(frame)
        print(f"  Frame {i+1}/10 captured")
        time.sleep(frame_delay)

    picam2.stop()

    # Save frames
    print("\n💾 Saving frames...")
    for i, frame in enumerate(frames):
        filename = f"test_frame_{i:03d}.jpg"
        cv2.imwrite(filename, cv2.cvtColor(frame, cv2.COLOR_RGB2BGR))
        print(f"  Saved: {filename}")

    print("\n✅ Done! Check the saved images.")
    print("   Look for clear dots on the ball in the images.")
    print("   If blurry, adjust Camera Settings (faster shutter, more light).")

if __name__ == "__main__":
    try:
        test_camera_capture()
    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\nMake sure picamera2 is installed:")
        print("  sudo apt install python3-picamera2")
