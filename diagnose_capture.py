#!/usr/bin/env python3
"""
Diagnostic tool to check why ball detection fails during capture
Runs the exact same detection as capture loop and saves debug info
"""

import cv2
import numpy as np
import time
from picamera2 import Picamera2
from collections import deque

print("🔍 Starting capture diagnostic...")
print("This will run for 10 seconds and show why detection is failing\n")

# Initialize camera with same settings as capture loop
# FORCE diagnostic settings that work
shutter_speed = 1500
gain = 8.0
frame_rate = 100

picam2 = Picamera2()
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
time.sleep(2)

print(f"✅ Camera started: {frame_rate} FPS, {shutter_speed}µs shutter, {gain}x gain\n")

# Run detection for 10 seconds
start_time = time.time()
frame_count = 0
detection_count = 0

while time.time() - start_time < 10:
    frame = picam2.capture_array()
    frame_count += 1

    # === EXACT SAME DETECTION AS main.py ===

    # Convert to grayscale
    if len(frame.shape) == 3:
        gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
    else:
        gray = frame

    # CLAHE preprocessing
    clahe = cv2.createCLAHE(clipLimit=6.0, tileGridSize=(6, 6))
    enhanced_gray = clahe.apply(gray)

    # Brightness detection
    _, bright_mask = cv2.threshold(enhanced_gray, 50, 255, cv2.THRESH_BINARY)

    # Clean up noise
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_OPEN, kernel)
    bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_CLOSE, kernel)

    # Edge detection
    edges = cv2.Canny(enhanced_gray, 50, 150)

    # Combine
    combined = cv2.bitwise_or(bright_mask, edges)
    blurred = cv2.GaussianBlur(combined, (9, 9), 2)

    # Circle detection
    param2_values = [10, 8, 12, 15, 7, 6, 5]
    circles = None

    for param2 in param2_values:
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

    # Filter circles
    ball_detected = False
    if circles is not None and len(circles[0]) > 0:
        circles = np.uint16(np.around(circles))

        # Remove duplicates
        filtered_circles = []
        used_centers = set()

        for circle in circles[0]:
            x, y, r = int(circle[0]), int(circle[1]), int(circle[2])
            is_duplicate = False
            for (cx, cy) in used_centers:
                if abs(x - cx) < 10 and abs(y - cy) < 10:
                    is_duplicate = True
                    break
            if not is_duplicate:
                filtered_circles.append(circle)
                used_centers.add((x, y))

        # Smart filtering
        for circle in filtered_circles:
            x, y, r = int(circle[0]), int(circle[1]), int(circle[2])

            # Bounds check
            if x - r < 0 or x + r >= gray.shape[1]:
                continue
            if y - r < 0 or y + r >= gray.shape[0]:
                continue

            # Size check
            if r < 20 or r > 100:
                continue

            # Extract region
            y1 = max(0, y - r)
            y2 = min(gray.shape[0], y + r)
            x1 = max(0, x - r)
            x2 = min(gray.shape[1], x + r)
            region = gray[y1:y2, x1:x2]

            if region.size == 0:
                continue

            # Brightness filtering
            region_brightness = region.mean()
            if region_brightness < 40:
                continue

            # Circularity check
            max_brightness = region.max()
            brightness_contrast = max_brightness - region_brightness
            if brightness_contrast < 30:
                continue

            # Ball found!
            ball_detected = True
            detection_count += 1
            print(f"✅ Frame {frame_count}: Ball detected at ({x}, {y}) r={r}, brightness={region_brightness:.1f}, contrast={brightness_contrast:.1f}")

            # Save debug frame
            debug_frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
            cv2.circle(debug_frame, (x, y), r, (0, 255, 0), 3)
            cv2.circle(debug_frame, (x, y), 3, (0, 255, 0), -1)
            cv2.putText(debug_frame, f"Ball r={r}", (x + r + 5, y),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            cv2.imwrite(f"diagnose_capture_detected_{frame_count}.jpg", debug_frame)
            break

    # Save debug info every 30 frames
    if frame_count % 30 == 0:
        if not ball_detected:
            print(f"❌ Frame {frame_count}: No ball detected")
            print(f"   Frame shape: {frame.shape}")
            print(f"   Gray stats: min={gray.min()}, max={gray.max()}, mean={gray.mean():.1f}")
            print(f"   Circles found: {len(circles[0]) if circles is not None else 0}")

            # Save debug images
            cv2.imwrite(f"diagnose_gray_{frame_count}.jpg", gray)
            cv2.imwrite(f"diagnose_clahe_{frame_count}.jpg", enhanced_gray)
            cv2.imwrite(f"diagnose_bright_mask_{frame_count}.jpg", bright_mask)
            cv2.imwrite(f"diagnose_edges_{frame_count}.jpg", edges)
            cv2.imwrite(f"diagnose_combined_{frame_count}.jpg", combined)
            cv2.imwrite(f"diagnose_blurred_{frame_count}.jpg", blurred)

    time.sleep(0.1)

picam2.stop()
picam2.close()

print(f"\n📊 Diagnostic Summary:")
print(f"   Total frames: {frame_count}")
print(f"   Detections: {detection_count}")
print(f"   Detection rate: {(detection_count/frame_count)*100:.1f}%")
print(f"\n💡 Debug images saved to diagnose_*.jpg")

if detection_count == 0:
    print(f"\n❌ NO BALL DETECTED - Check the debug images to see what's wrong")
    print(f"   Most likely issues:")
    print(f"   1. Ball too dark (brightness < 40)")
    print(f"   2. Ball too uniform (contrast < 30)")
    print(f"   3. Wrong camera format (monochrome sensor as RGB)")
else:
    print(f"\n✅ Ball detection is working! Issue might be elsewhere in capture loop")
