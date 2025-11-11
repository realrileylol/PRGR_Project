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

def detect_ball(frame, roi=None, expected_radius=None):
    """
    Detect golf ball in frame using circle detection

    Args:
        frame: RGB frame from camera
        roi: Optional (x, y, width, height) to search only in specific region
        expected_radius: Optional expected ball radius to filter by size
    """
    gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)

    # If ROI specified, crop to region
    if roi is not None:
        x, y, w, h = roi
        # Ensure ROI is within frame bounds
        x = max(0, x)
        y = max(0, y)
        w = min(w, frame.shape[1] - x)
        h = min(h, frame.shape[0] - y)
        gray_roi = gray[y:y+h, x:x+w]
    else:
        gray_roi = gray
        x, y = 0, 0

    blurred = cv2.GaussianBlur(gray_roi, (9, 9), 2)

    # Adjust radius search range if we know expected size
    if expected_radius is not None:
        min_r = int(expected_radius * 0.8)  # 20% tolerance
        max_r = int(expected_radius * 1.2)
    else:
        min_r = 20
        max_r = 150

    circles = cv2.HoughCircles(
        blurred,
        cv2.HOUGH_GRADIENT,
        dp=1,
        minDist=100,
        param1=50,
        param2=30,
        minRadius=min_r,
        maxRadius=max_r
    )

    if circles is not None:
        circles = np.uint16(np.around(circles))
        # Adjust coordinates back to full frame if ROI was used
        ball = circles[0, 0].copy()
        ball[0] += x  # Adjust x coordinate
        ball[1] += y  # Adjust y coordinate
        return ball  # x, y, radius
    return None

def calculate_velocity(prev_ball, curr_ball, time_delta):
    """
    Calculate ball velocity in pixels per second

    Returns velocity in px/sec, or 0 if calculation not possible
    """
    if prev_ball is None or curr_ball is None or time_delta <= 0:
        return 0

    # Convert to int to avoid uint16 overflow warnings
    dx = int(curr_ball[0]) - int(prev_ball[0])
    dy = int(curr_ball[1]) - int(prev_ball[1])
    distance = np.sqrt(dx**2 + dy**2)

    velocity = distance / time_delta  # pixels per second

    return velocity

def ball_has_moved(prev_ball, curr_ball, threshold=40):
    """Check if ball has moved significantly from original position"""
    if prev_ball is None or curr_ball is None:
        return False

    # Convert to int to avoid uint16 overflow warnings
    dx = int(curr_ball[0]) - int(prev_ball[0])
    dy = int(curr_ball[1]) - int(prev_ball[1])
    distance = np.sqrt(dx**2 + dy**2)

    return distance > threshold

def create_ball_roi(ball_position, roi_size=100):
    """
    Create ROI around ball position for focused tracking

    Args:
        ball_position: (x, y, r) tuple
        roi_size: Size of ROI box around ball center (default 100px)

    Returns:
        (x, y, width, height) tuple for ROI
    """
    if ball_position is None:
        return None

    x, y, r = int(ball_position[0]), int(ball_position[1]), int(ball_position[2])

    # Create square ROI centered on ball
    roi_x = x - roi_size // 2
    roi_y = y - roi_size // 2

    return (roi_x, roi_y, roi_size, roi_size)

def test_camera_capture():
    """Motion-triggered capture with ball detection"""

    # Create captures folder if it doesn't exist
    captures_folder = "ball_captures"
    os.makedirs(captures_folder, exist_ok=True)

    # Find next shot number by checking existing files
    existing_shots = [f for f in os.listdir(captures_folder) if f.startswith("shot_")]
    if existing_shots:
        shot_numbers = [int(f.split("_")[1]) for f in existing_shots]
        next_shot = max(shot_numbers) + 1
    else:
        next_shot = 0

    print("🎥 Initializing camera...")
    print(f"📁 Saving captures to: {captures_folder}/")
    print(f"📝 Next shot number: #{next_shot}\n")

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
    print("  3. When ball moves fast (>1500 px/sec) → captures 10 frames")
    print("  4. Club waggle/adjustments ignored (velocity check prevents false triggers)")
    print("  5. Script will stop after capturing one shot")
    print("  6. Run script again for next shot\n")

    original_ball = None
    stable_frames = 0
    last_ball_position = None
    last_timestamp = None

    # Velocity threshold to distinguish hit from club waggle/adjustments
    VELOCITY_THRESHOLD = 1500  # px/sec - minimum speed for hit detection

    try:
        while True:
            current_timestamp = time.time()
            frame = picam2.capture_array()

            # Use ROI-based detection once ball is locked
            if original_ball is not None:
                # Create ROI around last known ball position
                roi = create_ball_roi(last_ball_position or original_ball, roi_size=120)
                expected_radius = int(original_ball[2])
                current_ball = detect_ball(frame, roi=roi, expected_radius=expected_radius)
            else:
                # Full-frame search when initially detecting ball
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

                    if stable_frames >= 20:
                        original_ball = current_ball
                        last_ball_position = current_ball
                        last_timestamp = current_timestamp
                        print(f"🎯 Ball locked at position ({x}, {y}), radius {r}px")
                        print("   Ready to capture - hit your shot!")
                        print(f"   (Velocity threshold: {VELOCITY_THRESHOLD} px/sec)")
                        stable_frames = 0

                # Ball is locked, check for motion with velocity threshold
                elif ball_has_moved(original_ball, current_ball):
                    # Calculate velocity to distinguish hit from slow adjustment
                    if last_ball_position is not None and last_timestamp is not None:
                        time_delta = current_timestamp - last_timestamp
                        velocity = calculate_velocity(last_ball_position, current_ball, time_delta)

                        # Only trigger on fast movement (actual hit, not club waggle)
                        if velocity >= VELOCITY_THRESHOLD:
                            cv2.circle(display, (x, y), r, (0, 0, 255), 3)  # Red = CAPTURING!
                            cv2.putText(display, "CAPTURING!", (10, 30),
                                      cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 3)

                            print(f"\n🚀 HIT DETECTED - Shot #{next_shot}")
                            print(f"   Velocity: {velocity:.1f} px/sec (threshold: {VELOCITY_THRESHOLD})")
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
                                filename = f"shot_{next_shot:03d}_frame_{i:03d}.jpg"
                                filepath = os.path.join(captures_folder, filename)
                                cv2.imwrite(filepath, cv2.cvtColor(save_frame, cv2.COLOR_RGB2BGR))
                                print(f"   Saved: {filepath}")

                            print(f"\n✅ Shot #{next_shot} saved!")
                            print(f"📊 Total frames saved: 10")
                            print(f"📈 Hit velocity: {velocity:.1f} px/sec")
                            print("\n✅ Done! Run script again to capture next shot.")

                            # Stop after one capture
                            picam2.stop()
                            return
                        else:
                            # Slow movement - probably adjusting ball or club waggle
                            cv2.circle(display, (x, y), r, (255, 165, 0), 2)  # Orange = movement detected
                            cv2.putText(display, f"Movement: {velocity:.0f} px/s (< {VELOCITY_THRESHOLD})", (10, 30),
                                      cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 165, 0), 2)
                            cv2.putText(display, "Too slow for hit (adjusting ball?)", (10, 60),
                                      cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 165, 0), 2)

                            # Update baseline if ball is being repositioned
                            last_ball_position = current_ball
                            last_timestamp = current_timestamp

                else:
                    # Ball stable and ready
                    cv2.circle(display, (x, y), r, (0, 255, 0), 2)  # Green = ready
                    cv2.putText(display, "READY - Hit the ball!", (10, 30),
                              cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

                    # Update tracking position
                    last_ball_position = current_ball
                    last_timestamp = current_timestamp

            else:
                # No ball detected
                if original_ball is not None:
                    # Ball was locked but now disappeared - might be a hit!
                    cv2.putText(display, "Ball disappeared - checking...", (10, 30),
                              cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 0, 0), 2)
                    # Wait a couple frames to see if it's really gone or just detection glitch
                else:
                    cv2.putText(display, "No ball detected", (10, 30),
                              cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                    stable_frames = 0

            # Optional: Save preview frame for debugging
            # cv2.imwrite("preview.jpg", cv2.cvtColor(display, cv2.COLOR_RGB2BGR))

            time.sleep(0.03)  # Small delay to prevent CPU overload

    except KeyboardInterrupt:
        print("\n\n⏹️  Stopped by user")
        print("   No shot captured")

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
