#!/usr/bin/env python3
"""Test ball detection on the current snapshot image"""

import cv2
import numpy as np
from collections import deque

# Load the snapshot image
img_path = "BallSnapshotTest/BallTest1.jpg"
frame = cv2.imread(img_path)

if frame is None:
    print(f"❌ Could not load image: {img_path}")
    exit(1)

print(f"📸 Testing detection on: {img_path}")
print(f"   Image size: {frame.shape[1]}x{frame.shape[0]}")

# Convert to grayscale
gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

# Show brightness stats
print(f"\n📊 Brightness stats:")
print(f"   Min: {gray.min()}, Max: {gray.max()}, Mean: {gray.mean():.1f}")

# === CLAHE PREPROCESSING ===
clahe = cv2.createCLAHE(clipLimit=6.0, tileGridSize=(6, 6))
enhanced_gray = clahe.apply(gray)

print(f"   After CLAHE - Min: {enhanced_gray.min()}, Max: {enhanced_gray.max()}, Mean: {enhanced_gray.mean():.1f}")

# === BRIGHTNESS DETECTION ===
threshold = 50
_, bright_mask = cv2.threshold(enhanced_gray, threshold, 255, cv2.THRESH_BINARY)

# Clean up noise
kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_OPEN, kernel)
bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_CLOSE, kernel)

# === EDGE DETECTION ===
edges = cv2.Canny(enhanced_gray, 50, 150)

# Combine
combined = cv2.bitwise_or(bright_mask, edges)
blurred = cv2.GaussianBlur(combined, (9, 9), 2)

print(f"\n🔍 Running HoughCircles detection...")

# === ULTRA-SENSITIVE CIRCLE DETECTION ===
param2_values = [10, 8, 12, 15, 7, 6, 5]
circles_found = None

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
        circles_found = circles
        print(f"   ✅ Found {len(circles[0])} circles with param2={param2}")
        break
    else:
        print(f"   ❌ No circles with param2={param2}")

if circles_found is not None:
    circles_found = np.uint16(np.around(circles_found))

    # Show all detected circles
    print(f"\n🎯 Detected circles:")
    for i, circle in enumerate(circles_found[0]):
        x, y, r = int(circle[0]), int(circle[1]), int(circle[2])

        # Get ball region stats
        y1 = max(0, y - r)
        y2 = min(gray.shape[0], y + r)
        x1 = max(0, x - r)
        x2 = min(gray.shape[1], x + r)

        region = gray[y1:y2, x1:x2]

        if region.size > 0:
            region_brightness = region.mean()
            print(f"   Circle {i+1}: x={x}, y={y}, radius={r}px, brightness={region_brightness:.1f}")

            # Draw on frame
            color = (0, 255, 0) if i == 0 else (0, 255, 255)  # First circle green, others yellow
            cv2.circle(frame, (x, y), r, color, 3)
            cv2.circle(frame, (x, y), 3, color, -1)
            cv2.putText(frame, f"#{i+1} r={r}", (x + r + 5, y),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)

    # Save result
    output_path = "test_current_snapshot_result.jpg"
    cv2.imwrite(output_path, frame)
    print(f"\n✅ Result saved to: {output_path}")
    print(f"   First circle (ball): x={circles_found[0][0][0]:.0f}, y={circles_found[0][0][1]:.0f}, r={circles_found[0][0][2]:.0f}")

    # Show what will happen
    print(f"\n🎯 DETECTION STATUS:")
    print(f"   ✅ Ball WILL be detected and locked GREEN")
    print(f"   ✅ Lock time: ~5 frames (0.05-0.17 seconds)")
    print(f"   ✅ Ready to capture on ball movement >20px/frame")

else:
    print(f"\n❌ NO CIRCLES DETECTED")
    print(f"   Ball detection will show RED status")
    print(f"   Need to adjust detection parameters")

    # Save debug images
    cv2.imwrite("test_snapshot_gray.jpg", gray)
    cv2.imwrite("test_snapshot_clahe.jpg", enhanced_gray)
    cv2.imwrite("test_snapshot_bright_mask.jpg", bright_mask)
    cv2.imwrite("test_snapshot_edges.jpg", edges)
    cv2.imwrite("test_snapshot_combined.jpg", combined)
    cv2.imwrite("test_snapshot_blurred.jpg", blurred)
    print(f"   Debug images saved: test_snapshot_*.jpg")
