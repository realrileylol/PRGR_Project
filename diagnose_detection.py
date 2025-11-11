#!/usr/bin/env python3
"""
Diagnostic script to test ball detection parameters
Tests each step of detection pipeline to identify issues
"""

import cv2
import numpy as np
import sys

def test_detection_pipeline(image_path):
    """Test detection with verbose output at each stage"""

    # Read image
    print(f"\n{'='*60}")
    print(f"Testing detection on: {image_path}")
    print(f"{'='*60}\n")

    frame = cv2.imread(image_path)
    if frame is None:
        print(f"ERROR: Could not read image from {image_path}")
        return

    print(f"✓ Image loaded: {frame.shape}")

    # Convert to grayscale
    if len(frame.shape) == 3:
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    else:
        gray = frame

    print(f"✓ Grayscale shape: {gray.shape}")
    print(f"  Brightness range: {gray.min()}-{gray.max()}, mean: {gray.mean():.1f}")

    # Test 1: WITHOUT CLAHE (original approach)
    print(f"\n{'='*60}")
    print("TEST 1: Detection WITHOUT CLAHE (original optimized_detection.py)")
    print(f"{'='*60}\n")
    test_detection_without_clahe(gray)

    # Test 2: WITH CLAHE (new PiTrac approach)
    print(f"\n{'='*60}")
    print("TEST 2: Detection WITH CLAHE (new PiTrac enhancement)")
    print(f"{'='*60}\n")
    test_detection_with_clahe(gray)

    # Test 3: Lower thresholds
    print(f"\n{'='*60}")
    print("TEST 3: Detection with LOWER brightness thresholds")
    print(f"{'='*60}\n")
    test_detection_lower_thresholds(gray)


def test_detection_without_clahe(gray):
    """Test original detection without CLAHE"""

    # Brightness threshold
    _, bright_mask = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY)
    bright_pixels = np.count_nonzero(bright_mask)
    print(f"✓ Brightness threshold (150): {bright_pixels} bright pixels ({bright_pixels/bright_mask.size*100:.1f}%)")

    if bright_pixels == 0:
        print("  ⚠️  WARNING: No pixels above brightness threshold 150!")
        print("  → Ball might be dimmer than expected")
        return

    # Morphology
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_OPEN, kernel)
    bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_CLOSE, kernel)
    print(f"✓ Morphology applied")

    # Edges
    edges = cv2.Canny(gray, 50, 150)
    edge_pixels = np.count_nonzero(edges)
    print(f"✓ Canny edges: {edge_pixels} edge pixels")

    # Combine
    combined = cv2.bitwise_or(bright_mask, edges)
    print(f"✓ Combined bright+edges")

    # Blur
    blurred = cv2.GaussianBlur(combined, (9, 9), 2)
    print(f"✓ Gaussian blur applied")

    # HoughCircles - single param2
    circles = cv2.HoughCircles(
        blurred,
        cv2.HOUGH_GRADIENT,
        dp=1,
        minDist=80,
        param1=30,
        param2=20,
        minRadius=15,
        maxRadius=200
    )

    if circles is not None:
        print(f"✅ HoughCircles (param2=20) found {len(circles[0])} circles")
        for i, c in enumerate(circles[0][:3]):  # Show first 3
            print(f"   Circle {i+1}: center=({int(c[0])}, {int(c[1])}), radius={int(c[2])}")
            # Check brightness
            x, y, r = int(c[0]), int(c[1]), int(c[2])
            if 0 <= x-r and x+r < gray.shape[1] and 0 <= y-r and y+r < gray.shape[0]:
                region = gray[max(0,y-r):min(gray.shape[0],y+r), max(0,x-r):min(gray.shape[1],x+r)]
                print(f"   Region brightness: mean={region.mean():.1f}, std={region.std():.1f}")
                if region.mean() > 130:
                    print(f"   ✅ Would pass brightness validation (>130)")
                else:
                    print(f"   ❌ Would FAIL brightness validation (need >130)")
    else:
        print(f"❌ HoughCircles found NO circles")
        print("  → Trying more sensitive param2 values...")

        for param2 in [18, 16, 15, 12, 10]:
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
            if circles is not None:
                print(f"  ✓ param2={param2} found {len(circles[0])} circles")
                break
        else:
            print(f"  ❌ Even param2=10 found nothing - detection parameters need adjustment")


def test_detection_with_clahe(gray):
    """Test detection WITH CLAHE enhancement"""

    # Apply CLAHE
    clahe = cv2.createCLAHE(clipLimit=6.0, tileGridSize=(6, 6))
    enhanced_gray = clahe.apply(gray)

    print(f"✓ CLAHE applied")
    print(f"  Original brightness: {gray.min()}-{gray.max()}, mean: {gray.mean():.1f}")
    print(f"  Enhanced brightness: {enhanced_gray.min()}-{enhanced_gray.max()}, mean: {enhanced_gray.mean():.1f}")

    # Brightness threshold on ENHANCED image
    _, bright_mask = cv2.threshold(enhanced_gray, 150, 255, cv2.THRESH_BINARY)
    bright_pixels = np.count_nonzero(bright_mask)
    print(f"✓ Brightness threshold (150) on CLAHE: {bright_pixels} bright pixels ({bright_pixels/bright_mask.size*100:.1f}%)")

    if bright_pixels == 0:
        print("  ⚠️  WARNING: CLAHE made things worse - no bright pixels!")
        return

    # Continue with rest of pipeline
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_OPEN, kernel)
    bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_CLOSE, kernel)

    edges = cv2.Canny(enhanced_gray, 50, 150)
    combined = cv2.bitwise_or(bright_mask, edges)
    blurred = cv2.GaussianBlur(combined, (9, 9), 2)

    # Try adaptive param2
    param2_values = [20, 18, 22, 16, 24, 15, 26]
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
            print(f"✅ Adaptive HoughCircles (param2={param2}) found {len(circles[0])} circles (ideal range!)")
            for i, c in enumerate(circles[0]):
                print(f"   Circle {i+1}: center=({int(c[0])}, {int(c[1])}), radius={int(c[2])}")
            break
    else:
        if circles is not None:
            print(f"⚠️  Found {len(circles[0])} circles but outside ideal 1-4 range")
        else:
            print(f"❌ Adaptive param2 found NO circles in ideal range")


def test_detection_lower_thresholds(gray):
    """Test with lower brightness thresholds for darker conditions"""

    print("Testing with lower brightness threshold (100 instead of 150)...")

    _, bright_mask = cv2.threshold(gray, 100, 255, cv2.THRESH_BINARY)
    bright_pixels = np.count_nonzero(bright_mask)
    print(f"✓ Brightness threshold (100): {bright_pixels} bright pixels ({bright_pixels/bright_mask.size*100:.1f}%)")

    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_OPEN, kernel)
    bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_CLOSE, kernel)

    edges = cv2.Canny(gray, 50, 150)
    combined = cv2.bitwise_or(bright_mask, edges)
    blurred = cv2.GaussianBlur(combined, (9, 9), 2)

    circles = cv2.HoughCircles(
        blurred,
        cv2.HOUGH_GRADIENT,
        dp=1,
        minDist=80,
        param1=30,
        param2=20,
        minRadius=15,
        maxRadius=200
    )

    if circles is not None:
        print(f"✅ Found {len(circles[0])} circles with lower threshold")
        for i, c in enumerate(circles[0][:3]):
            x, y, r = int(c[0]), int(c[1]), int(c[2])
            print(f"   Circle {i+1}: center=({int(c[0])}, {int(c[1])}), radius={int(c[2])}")
            if 0 <= x-r and x+r < gray.shape[1] and 0 <= y-r and y+r < gray.shape[0]:
                region = gray[max(0,y-r):min(gray.shape[0],y+r), max(0,x-r):min(gray.shape[1],x+r)]
                print(f"   Region brightness: mean={region.mean():.1f}, std={region.std():.1f}")
    else:
        print(f"❌ Still no circles with threshold=100")


if __name__ == "__main__":
    # Test on the provided image
    test_image = "BallRecognition_Test/Ball_Rec1 - Indoor - High Light.png"

    if len(sys.argv) > 1:
        test_image = sys.argv[1]

    test_detection_pipeline(test_image)

    print(f"\n{'='*60}")
    print("SUMMARY RECOMMENDATIONS:")
    print(f"{'='*60}")
    print("Run this script on your actual camera frame to diagnose:")
    print("  python3 diagnose_detection.py path/to/your/image.png")
