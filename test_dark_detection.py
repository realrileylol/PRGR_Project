#!/usr/bin/env python3
"""Quick test of new dark-adapted detection"""

import cv2
import numpy as np

def test_new_scoring(image_path):
    frame = cv2.imread(image_path)
    if frame is None:
        print(f"ERROR: Could not read {image_path}")
        return

    if len(frame.shape) == 3:
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    else:
        gray = frame

    print(f"Testing new dark-adapted detection on: {image_path}")
    print(f"Image brightness: mean={gray.mean():.1f}")

    # Apply CLAHE
    clahe = cv2.createCLAHE(clipLimit=6.0, tileGridSize=(6, 6))
    enhanced_gray = clahe.apply(gray)

    # Brightness threshold
    _, bright_mask = cv2.threshold(enhanced_gray, 100, 255, cv2.THRESH_BINARY)

    # Morphology
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_OPEN, kernel)
    bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_CLOSE, kernel)

    # Edges
    edges = cv2.Canny(enhanced_gray, 50, 150)
    combined = cv2.bitwise_or(bright_mask, edges)
    blurred = cv2.GaussianBlur(combined, (9, 9), 2)

    # HoughCircles with adaptive param2
    param2_values = [20, 18, 22, 16, 24, 15, 26]
    circles = None

    for param2 in param2_values:
        circles = cv2.HoughCircles(
            blurred,
            cv2.HOUGH_GRADIENT,
            dp=1,
            minDist=80,
            param1=30,
            param2=param2,
            minRadius=15,
            maxRadius=200
        )
        if circles is not None and 1 <= len(circles[0]) <= 4:
            print(f"✅ Found {len(circles[0])} circles with param2={param2}")
            break

    if circles is None or len(circles[0]) == 0:
        print("❌ No circles detected")
        return

    circles = np.uint16(np.around(circles))

    # Score circles with new system
    print(f"\nScoring {len(circles[0])} detected circles:\n")

    best_circle = None
    best_score = 0

    for i, circle in enumerate(circles[0]):
        x, y, r = int(circle[0]), int(circle[1]), int(circle[2])

        # Extract region
        y1 = max(0, y - r)
        y2 = min(gray.shape[0], y + r)
        x1 = max(0, x - r)
        x2 = min(gray.shape[1], x + r)
        region = gray[y1:y2, x1:x2]

        if region.size == 0:
            continue

        mean_brightness = np.mean(region)
        std_dev = np.std(region)

        # New scoring
        uniformity_score = 1.0 - np.clip(std_dev / 100, 0, 0.5)
        size_score = 1.0 - abs(r - 25) / 100
        brightness_score = np.clip(mean_brightness / 100, 0, 1.0)
        score = (uniformity_score * 0.5 + size_score * 0.3 + brightness_score * 0.2) * 100

        print(f"Circle {i+1}: pos=({x},{y}), radius={r}")
        print(f"  Brightness: {mean_brightness:.1f}, Std: {std_dev:.1f}")
        print(f"  Uniformity: {uniformity_score:.2f}, Size: {size_score:.2f}, Brightness: {brightness_score:.2f}")
        print(f"  TOTAL SCORE: {score:.1f}")

        if score > best_score:
            best_score = score
            best_circle = circle

    if best_circle is not None:
        x, y, r = int(best_circle[0]), int(best_circle[1]), int(best_circle[2])
        print(f"\n✅ BEST DETECTION: pos=({x},{y}), radius={r}, score={best_score:.1f}")
        print("Ball should now be detected successfully!")
    else:
        print("\n❌ No valid circles found")

if __name__ == "__main__":
    import sys
    image = sys.argv[1] if len(sys.argv) > 1 else "BallRecognition_Test/Ball_Rec1 - Indoor - High Light.png"
    test_new_scoring(image)
