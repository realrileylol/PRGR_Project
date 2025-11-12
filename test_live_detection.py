#!/usr/bin/env python3
"""
Simple ball detection test - saves frames showing what's being detected
Run this to see if ANY circles are being found
"""

import cv2
import numpy as np
import sys
import time

try:
    from picamera2 import Picamera2
    CAMERA_AVAILABLE = True
except ImportError:
    CAMERA_AVAILABLE = False
    print("❌ Picamera2 not available")
    sys.exit(1)

def test_live_detection():
    """Test ball detection with live camera"""

    print("🎥 Starting camera...")
    picam2 = Picamera2()

    # Use same config as main.py
    config = picam2.create_video_configuration(
        main={"size": (640, 480), "format": "RGB888"},
        controls={
            "FrameRate": 30,
            "ExposureTime": 5000,
            "AnalogueGain": 2.0
        }
    )
    picam2.configure(config)
    picam2.start()
    time.sleep(2)

    print("✅ Camera started")
    print("📸 Testing detection for 10 seconds...")
    print("   Saving frames to test_detection_*.jpg")
    print()

    frame_count = 0
    detections = 0

    for i in range(300):  # 10 seconds at 30 FPS
        frame = picam2.capture_array()

        # Convert to grayscale
        if len(frame.shape) == 3:
            gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
        else:
            gray = frame

        # CLAHE
        clahe = cv2.createCLAHE(clipLimit=6.0, tileGridSize=(6, 6))
        enhanced = clahe.apply(gray)

        # Super low threshold
        _, bright_mask = cv2.threshold(enhanced, 50, 255, cv2.THRESH_BINARY)

        # Morphology
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
        bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_OPEN, kernel)
        bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_CLOSE, kernel)

        # Edges
        edges = cv2.Canny(enhanced, 50, 150)

        # Combine
        combined = cv2.bitwise_or(bright_mask, edges)
        blurred = cv2.GaussianBlur(combined, (9, 9), 2)

        # Try ULTRA-sensitive detection
        circles = None
        for param2 in [10, 8, 6, 5, 4, 3]:
            circles = cv2.HoughCircles(
                blurred,
                cv2.HOUGH_GRADIENT,
                dp=1,
                minDist=50,
                param1=20,
                param2=param2,
                minRadius=10,
                maxRadius=250
            )
            if circles is not None:
                break

        # Draw on frame
        vis_frame = frame.copy()

        if circles is not None and len(circles[0]) > 0:
            detections += 1
            for circle in circles[0]:
                x, y, r = int(circle[0]), int(circle[1]), int(circle[2])
                cv2.circle(vis_frame, (x, y), r, (0, 255, 0), 3)
                cv2.circle(vis_frame, (x, y), 3, (0, 255, 0), -1)
                cv2.putText(vis_frame, f"({x},{y}) r={r}", (x+r+5, y),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)

            status = f"DETECTED: {len(circles[0])} circles"
            color = (0, 255, 0)
        else:
            status = "NO DETECTION"
            color = (0, 0, 255)

        # Add info overlay
        cv2.putText(vis_frame, status, (10, 30),
                   cv2.FONT_HERSHEY_SIMPLEX, 1, color, 2)
        cv2.putText(vis_frame, f"Frame: {frame_count}", (10, 70),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        cv2.putText(vis_frame, f"Brightness: {gray.mean():.1f}", (10, 100),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)

        # Save every 30 frames (1 second)
        if frame_count % 30 == 0:
            filename = f"test_detection_{frame_count:04d}.jpg"
            cv2.imwrite(filename, cv2.cvtColor(vis_frame, cv2.COLOR_RGB2BGR))
            print(f"Frame {frame_count}: {status} | Brightness: {gray.mean():.1f}")

        frame_count += 1
        time.sleep(0.033)  # ~30 FPS

    picam2.stop()

    print()
    print("="*60)
    print(f"RESULTS:")
    print(f"  Total frames: {frame_count}")
    print(f"  Detections: {detections}")
    print(f"  Detection rate: {detections/frame_count*100:.1f}%")
    print()
    print(f"Check test_detection_*.jpg files to see what was detected")
    print("="*60)

if __name__ == "__main__":
    test_live_detection()
