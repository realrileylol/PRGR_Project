#!/usr/bin/env python3
"""
Motion-triggered camera frame capture for spin detection.
Detects ball, monitors for movement, auto-captures when ball moves.
Now reads camera settings from your GUI configuration!
"""

import time
import numpy as np
import os
from picamera2 import Picamera2
import cv2
from SettingsManager import SettingsManager

def detect_ball(frame):
    """Detect golf ball in frame using circle detection"""
    gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
    blurred = cv2.GaussianBlur(gray, (9, 9), 2)

    circles = cv2.HoughCircles(
        blurred,
        cv2.HOUGH_GRADIENT,
        dp=1,
        minDist=100,
        param1=50,
        param2=30,
        minRadius=20,
        maxRadius=150
    )

    if circles is not None:
        circles = np.uint16(np.around(circles))
        return circles[0, 0]  # x, y, radius
    return None

def ball_has_moved(prev_ball, curr_ball, threshold=40):
    """Check if ball has moved significantly from original position"""
    if prev_ball is None or curr_ball is None:
        return False

    # Convert to int to avoid uint16 overflow warnings
    dx = int(curr_ball[0]) - int(prev_ball[0])
    dy = int(curr_ball[1]) - int(prev_ball[1])
    distance = np.sqrt(dx**2 + dy**2)

    return distance > threshold

def test_camera_capture():
    """Motion-triggered capture with ball detection"""

    # Create captures folder if it doesn't exist
    captures_folder = "ball_captures"
    os.makedirs(captures_folder, exist_ok=True)

    print("🎥 Initializing camera...")
    print(f"📁 Saving captures to: {captures_folder}/\n")

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
    print("\n📸 Motion Detection Instructions:")
    print("  1. Position ball 4-5 feet from camera with dots visible")
    print("  2. Camera will detect the ball automatically")
    print("  3. When ball moves → automatically captures 10 frames")
    print("  4. Saved images will be numbered sequentially")
    print("  5. Press Ctrl+C to stop\n")

    shot_number = 0
    original_ball = None
    stable_frames = 0
    motion_frames = 0  # Require consecutive motion frames to avoid false triggers

    try:
        while True:
            frame = picam2.capture_array()
            current_ball = detect_ball(frame)

            # Display frame with ball detection
            display = frame.copy()

            if current_ball is not None:
                x, y, r = int(current_ball[0]), int(current_ball[1]), int(current_ball[2])

                # Check if ball has been stable (establish baseline position)
                if original_ball is None:
                    stable_frames += 1
                    cv2.circle(display, (x, y), r, (255, 255, 0), 2)  # Yellow = detecting
                    cv2.putText(display, f"Detecting ball... {stable_frames}/20", (10, 30),
                              cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 0), 2)

                    if stable_frames >= 20:  # Increased from 10 to 20 for better stability
                        original_ball = current_ball
                        print(f"🎯 Ball locked at position ({x}, {y})")
                        print("   Ready to capture - hit your shot!")
                        stable_frames = 0
                        motion_frames = 0

                # Ball is locked, check for motion
                elif ball_has_moved(original_ball, current_ball):
                    motion_frames += 1
                    cv2.circle(display, (x, y), r, (255, 165, 0), 3)  # Orange = motion detected
                    cv2.putText(display, f"Motion detected... {motion_frames}/3", (10, 30),
                              cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 165, 0), 2)

                    # Require 3 consecutive motion frames to trigger capture
                    if motion_frames >= 3:
                        cv2.circle(display, (x, y), r, (0, 0, 255), 3)  # Red = CAPTURING!
                        cv2.putText(display, "CAPTURING!", (10, 30),
                                  cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 3)

                        print(f"\n🚀 MOTION CONFIRMED - Shot #{shot_number + 1}")
                        print("📷 Capturing frames...")

                        # Capture frames rapidly
                        frames = []
                        frame_delay = 1.0 / frame_rate
                        for i in range(10):
                            capture_frame = picam2.capture_array()
                            frames.append(capture_frame)
                            print(f"   Frame {i+1}/10 captured")
                            time.sleep(frame_delay)

                        # Save frames
                        print("💾 Saving frames...")
                        for i, save_frame in enumerate(frames):
                            filename = f"shot_{shot_number:03d}_frame_{i:03d}.jpg"
                            filepath = os.path.join(captures_folder, filename)
                            cv2.imwrite(filepath, cv2.cvtColor(save_frame, cv2.COLOR_RGB2BGR))
                            print(f"   Saved: {filepath}")

                        print(f"✅ Shot #{shot_number + 1} saved!\n")
                        print("   Position ball for next shot...")

                        shot_number += 1
                        original_ball = None
                        stable_frames = 0
                        motion_frames = 0
                        time.sleep(2)  # Cooldown before next detection

                else:
                    # Ball stable and ready - reset motion counter
                    motion_frames = 0
                    cv2.circle(display, (x, y), r, (0, 255, 0), 2)  # Green = ready
                    cv2.putText(display, "READY - Hit the ball!", (10, 30),
                              cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

            else:
                cv2.putText(display, "No ball detected", (10, 30),
                          cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                original_ball = None
                stable_frames = 0
                motion_frames = 0

            # Optional: Save preview frame for debugging
            # cv2.imwrite("preview.jpg", cv2.cvtColor(display, cv2.COLOR_RGB2BGR))

            time.sleep(0.03)  # Small delay to prevent CPU overload

    except KeyboardInterrupt:
        print("\n\n⏹️  Stopped by user")
        print(f"📊 Total shots captured: {shot_number}")

    finally:
        picam2.stop()
        print("✅ Camera stopped")

if __name__ == "__main__":
    try:
        test_camera_capture()
    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\nMake sure picamera2 is installed:")
        print("  sudo apt install python3-picamera2")
