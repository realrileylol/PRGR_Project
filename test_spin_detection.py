#!/usr/bin/env python3
"""
Basic spin detection test using OpenCV.
Detects ball, tracks dots/features, estimates rotation.
"""

import cv2
import numpy as np
import time
from picamera2 import Picamera2
import math

class SpinDetector:
    def __init__(self):
        self.prev_frame = None
        self.prev_points = None

    def detect_ball(self, frame):
        """Detect golf ball in frame using circle detection"""
        gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)

        # Blur to reduce noise
        blurred = cv2.GaussianBlur(gray, (9, 9), 2)

        # Detect circles (golf ball)
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
            # Return the first (hopefully only) circle
            return circles[0, 0]  # x, y, radius

        return None

    def detect_dots(self, frame, ball_center, ball_radius):
        """Detect dark dots on the ball"""
        x, y, r = ball_center[0], ball_center[1], ball_radius

        # Create mask for ball area only
        mask = np.zeros(frame.shape[:2], dtype=np.uint8)
        cv2.circle(mask, (x, y), int(r * 0.9), 255, -1)

        # Convert to grayscale
        gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)

        # Threshold to find dark dots (adjust threshold as needed)
        _, thresh = cv2.threshold(gray, 80, 255, cv2.THRESH_BINARY_INV)

        # Apply mask
        thresh = cv2.bitwise_and(thresh, thresh, mask=mask)

        # Find contours (dots)
        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        dot_centers = []
        for cnt in contours:
            area = cv2.contourArea(cnt)
            # Filter by size (adjust as needed)
            if 10 < area < 500:
                M = cv2.moments(cnt)
                if M["m00"] != 0:
                    cx = int(M["m10"] / M["m00"])
                    cy = int(M["m01"] / M["m00"])
                    dot_centers.append((cx, cy))

        return dot_centers

    def calculate_spin(self, prev_dots, curr_dots, ball_center, time_delta):
        """Calculate spin from dot movement"""
        if len(prev_dots) < 2 or len(curr_dots) < 2:
            return None

        # Match dots between frames (simple nearest neighbor)
        # In production, use proper feature matching
        total_angle = 0
        matches = 0

        for prev_dot in prev_dots:
            # Find closest current dot
            min_dist = float('inf')
            closest_curr = None

            for curr_dot in curr_dots:
                dist = math.sqrt((curr_dot[0] - prev_dot[0])**2 +
                               (curr_dot[1] - prev_dot[1])**2)
                if dist < min_dist and dist < 50:  # Max movement threshold
                    min_dist = dist
                    closest_curr = curr_dot

            if closest_curr:
                # Calculate angle moved around ball center
                angle1 = math.atan2(prev_dot[1] - ball_center[1],
                                   prev_dot[0] - ball_center[0])
                angle2 = math.atan2(closest_curr[1] - ball_center[1],
                                   closest_curr[0] - ball_center[0])

                angle_diff = angle2 - angle1

                # Normalize to -pi to pi
                if angle_diff > math.pi:
                    angle_diff -= 2 * math.pi
                elif angle_diff < -math.pi:
                    angle_diff += 2 * math.pi

                total_angle += abs(angle_diff)
                matches += 1

        if matches > 0:
            avg_angle = total_angle / matches
            # Convert to degrees
            degrees = math.degrees(avg_angle)
            # Convert to RPM (degrees per frame -> RPM)
            # RPM = (degrees / frame) * (frames / sec) * (60 sec / min) / (360 deg / rev)
            fps = 1.0 / time_delta if time_delta > 0 else 60
            rpm = (degrees * fps * 60) / 360
            return rpm

        return None

def test_spin_detection():
    """Test spin detection on live camera feed"""

    print("🎥 Initializing camera for spin detection...")

    picam2 = Picamera2()

    # Configure for high-speed capture
    config = picam2.create_video_configuration(
        main={"size": (640, 480), "format": "RGB888"},
        controls={
            "FrameRate": 60,
            "ExposureTime": 1500,  # 1.5ms shutter
            "AnalogueGain": 8.0
        }
    )

    picam2.configure(config)
    picam2.start()
    time.sleep(2)

    detector = SpinDetector()

    print("\n✅ Camera ready!")
    print("🎯 Position ball with visible dots in frame")
    print("🏌️ Hit a gentle shot and watch for spin detection")
    print("Press Ctrl+C to stop\n")

    frame_count = 0
    last_time = time.time()

    try:
        while True:
            # Capture frame
            frame = picam2.capture_array()
            frame_count += 1
            current_time = time.time()
            time_delta = current_time - last_time

            # Detect ball
            ball = detector.detect_ball(frame)

            # Create display frame
            display = frame.copy()

            if ball is not None:
                x, y, r = int(ball[0]), int(ball[1]), int(ball[2])

                # Draw ball circle
                cv2.circle(display, (x, y), r, (0, 255, 0), 2)
                cv2.circle(display, (x, y), 2, (0, 255, 0), 3)

                # Detect dots on ball
                dots = detector.detect_dots(frame, (x, y), r)

                # Draw dots
                for dot in dots:
                    cv2.circle(display, dot, 5, (255, 0, 0), -1)

                # Calculate spin if we have previous frame
                if detector.prev_dots is not None and len(dots) > 0:
                    rpm = detector.calculate_spin(
                        detector.prev_dots,
                        dots,
                        (x, y),
                        time_delta
                    )

                    if rpm is not None:
                        # Display spin
                        text = f"Spin: {int(rpm)} RPM"
                        cv2.putText(display, text, (10, 30),
                                  cv2.FONT_HERSHEY_SIMPLEX, 1,
                                  (0, 255, 255), 2)
                        print(f"🔄 Detected spin: {int(rpm)} RPM")

                # Store for next frame
                detector.prev_dots = dots
            else:
                cv2.putText(display, "No ball detected", (10, 30),
                          cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)

            # Save annotated frame occasionally for debugging
            if frame_count % 30 == 0:
                cv2.imwrite(f"spin_debug_{frame_count}.jpg",
                          cv2.cvtColor(display, cv2.COLOR_RGB2BGR))

            last_time = current_time

            # Small delay to prevent overwhelming
            time.sleep(0.01)

    except KeyboardInterrupt:
        print("\n\n⏹️  Stopped")

    finally:
        picam2.stop()
        print("✅ Camera stopped")

if __name__ == "__main__":
    try:
        test_spin_detection()
    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\nMake sure dependencies are installed:")
        print("  sudo apt install python3-opencv python3-picamera2")
