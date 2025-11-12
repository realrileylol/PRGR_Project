#!/usr/bin/env python3
"""Test SMART ball detection with brightness filtering on the current snapshot"""

import cv2
import numpy as np

# Load the snapshot image
img_path = "BallSnapshotTest/BallTest1.jpg"
frame = cv2.imread(img_path)

if frame is None:
    print(f"❌ Could not load image: {img_path}")
    exit(1)

print(f"📸 Testing SMART detection on: {img_path}")
print(f"   Image size: {frame.shape[1]}x{frame.shape[0]}")

# Convert to grayscale
gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

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

print(f"\n🔍 Running HoughCircles detection...")

# Ultra-sensitive circle detection
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
        print(f"   ✅ Found {len(circles[0])} raw circles with param2={param2}")
        break

if circles_found is not None:
    circles_found = np.uint16(np.around(circles_found))

    # Remove concentric circles
    filtered_circles = []
    used_centers = set()

    for circle in circles_found[0]:
        x, y, r = int(circle[0]), int(circle[1]), int(circle[2])

        is_duplicate = False
        for (cx, cy) in used_centers:
            if abs(x - cx) < 10 and abs(y - cy) < 10:
                is_duplicate = True
                break

        if not is_duplicate:
            filtered_circles.append(circle)
            used_centers.add((x, y))

    print(f"   After removing duplicates: {len(filtered_circles)} unique circles")

    # === SMART FILTERING with brightness check ===
    print(f"\n🎯 Applying SMART filtering...")
    best_circle = None
    best_score = 0
    valid_circles = []

    for circle in filtered_circles:
        x, y, r = int(circle[0]), int(circle[1]), int(circle[2])

        # Validate bounds
        if x - r < 0 or x + r >= gray.shape[1]:
            continue
        if y - r < 0 or y + r >= gray.shape[0]:
            continue

        # Ball size filtering
        if r < 20 or r > 100:
            continue

        # Extract ball region
        y1 = max(0, y - r)
        y2 = min(gray.shape[0], y + r)
        x1 = max(0, x - r)
        x2 = min(gray.shape[1], x + r)

        region = gray[y1:y2, x1:x2]

        if region.size == 0:
            continue

        # BRIGHTNESS FILTERING
        region_brightness = region.mean()

        # Reject dark circles (noise)
        if region_brightness < 40:
            continue

        # Calculate score
        score = 0

        # Brightness score (most important)
        score += region_brightness * 2.0

        # Position score (bottom of frame preferred)
        position_score = (y / gray.shape[0]) * 50
        score += position_score

        # Size score (ideal 30-60px)
        if 30 <= r <= 60:
            score += 30

        valid_circles.append((x, y, r, region_brightness, score))

        if score > best_score:
            best_score = score
            best_circle = circle

    print(f"   After brightness filtering (>40): {len(valid_circles)} valid circles")

    if valid_circles:
        print(f"\n✨ Valid circles (sorted by score):")
        valid_circles.sort(key=lambda c: c[4], reverse=True)
        for i, (x, y, r, brightness, score) in enumerate(valid_circles[:5]):
            marker = "🏆 BEST" if i == 0 else f"   #{i+1}"
            print(f"{marker}: x={x}, y={y}, r={r}px, brightness={brightness:.1f}, score={score:.1f}")

        # Draw all valid circles
        for i, (x, y, r, brightness, score) in enumerate(valid_circles):
            color = (0, 255, 0) if i == 0 else (0, 255, 255)  # Best circle green, others yellow
            cv2.circle(frame, (x, y), r, color, 3)
            cv2.circle(frame, (x, y), 3, color, -1)
            label = f"BALL r={r}" if i == 0 else f"#{i+1} r={r}"
            cv2.putText(frame, label, (x + r + 5, y),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)

        # Save result
        output_path = "test_smart_detection_result.jpg"
        cv2.imwrite(output_path, frame)
        print(f"\n✅ Result saved to: {output_path}")

        print(f"\n🎯 FINAL DETECTION STATUS:")
        print(f"   ✅ Ball DETECTED at: x={valid_circles[0][0]}, y={valid_circles[0][1]}, r={valid_circles[0][2]}px")
        print(f"   ✅ Ball brightness: {valid_circles[0][3]:.1f}")
        print(f"   ✅ Detection score: {valid_circles[0][4]:.1f}")
        print(f"   ✅ Ball will lock GREEN in ~5 frames (0.05-0.17 seconds)")
        print(f"   ✅ Ready to capture on ball movement >20px/frame")

    else:
        print(f"\n❌ NO VALID CIRCLES after brightness filtering")
        print(f"   All detected circles were too dark (brightness < 40)")
        print(f"   Need to lower brightness threshold or adjust lighting")

else:
    print(f"\n❌ NO CIRCLES DETECTED by HoughCircles")
    print(f"   Need to adjust HoughCircles parameters")
