#!/usr/bin/env python3
"""
Simple camera frame capture test for spin detection development.
Captures frames from Raspberry Pi camera using picamera2.
"""

import time
import numpy as np
from picamera2 import Picamera2
import cv2

def test_camera_capture():
    """Capture and save test frames from camera"""

    print("🎥 Initializing camera...")

    # Initialize camera
    picam2 = Picamera2()

    # Configure for high-speed capture
    config = picam2.create_video_configuration(
        main={"size": (640, 480), "format": "RGB888"},
        controls={
            "FrameRate": 60,  # Match your Camera Settings
            "ExposureTime": 1500,  # 1.5ms shutter (Spin Detection preset)
            "AnalogueGain": 8.0    # High gain for indoor
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
    for i in range(10):
        frame = picam2.capture_array()
        frames.append(frame)
        print(f"  Frame {i+1}/10 captured")
        time.sleep(0.016)  # ~60fps spacing

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
