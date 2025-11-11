#!/usr/bin/env python3
"""
Visualize CLAHE effect on ball detection
Shows before/after comparison
"""

import cv2
import numpy as np
import sys

def visualize_clahe(image_path):
    """Show CLAHE effect on image"""

    frame = cv2.imread(image_path)
    if frame is None:
        print(f"ERROR: Could not read {image_path}")
        return

    # Convert to grayscale
    if len(frame.shape) == 3:
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    else:
        gray = frame

    print(f"Analyzing CLAHE effect on: {image_path}\n")
    print("="*60)

    # Original image stats
    print("ORIGINAL IMAGE:")
    print(f"  Brightness range: {gray.min()}-{gray.max()}")
    print(f"  Mean brightness: {gray.mean():.1f}")
    print(f"  Std deviation: {gray.std():.1f}")

    # Calculate histogram
    hist_original = cv2.calcHist([gray], [0], None, [256], [0, 256])
    pixels_below_50 = np.sum(hist_original[0:50])
    pixels_above_200 = np.sum(hist_original[200:256])
    total_pixels = gray.size

    print(f"  Dark pixels (<50): {pixels_below_50/total_pixels*100:.1f}%")
    print(f"  Bright pixels (>200): {pixels_above_200/total_pixels*100:.1f}%")

    # Apply CLAHE
    clahe = cv2.createCLAHE(clipLimit=6.0, tileGridSize=(6, 6))
    enhanced = clahe.apply(gray)

    print("\n" + "="*60)
    print("AFTER CLAHE:")
    print(f"  Brightness range: {enhanced.min()}-{enhanced.max()}")
    print(f"  Mean brightness: {enhanced.mean():.1f}")
    print(f"  Std deviation: {enhanced.std():.1f}")

    # Calculate enhanced histogram
    hist_enhanced = cv2.calcHist([enhanced], [0], None, [256], [0, 256])
    pixels_below_50_e = np.sum(hist_enhanced[0:50])
    pixels_above_200_e = np.sum(hist_enhanced[200:256])

    print(f"  Dark pixels (<50): {pixels_below_50_e/total_pixels*100:.1f}%")
    print(f"  Bright pixels (>200): {pixels_above_200_e/total_pixels*100:.1f}%")

    print("\n" + "="*60)
    print("IMPROVEMENT:")
    mean_diff = enhanced.mean() - gray.mean()
    std_diff = enhanced.std() - gray.std()

    print(f"  Mean brightness: {mean_diff:+.1f} ({'+' if mean_diff > 0 else ''}{mean_diff/gray.mean()*100:.1f}%)")
    print(f"  Contrast (std): {std_diff:+.1f} ({'+' if std_diff > 0 else ''}{std_diff/gray.std()*100:.1f}%)")

    # Test ball region detection
    print("\n" + "="*60)
    print("BALL DETECTION COMPARISON:\n")

    # Original detection
    _, bright_original = cv2.threshold(gray, 100, 255, cv2.THRESH_BINARY)
    bright_pixels_orig = np.count_nonzero(bright_original)

    # CLAHE detection
    _, bright_clahe = cv2.threshold(enhanced, 100, 255, cv2.THRESH_BINARY)
    bright_pixels_clahe = np.count_nonzero(bright_clahe)

    print(f"Bright pixels (threshold=100) without CLAHE: {bright_pixels_orig} ({bright_pixels_orig/total_pixels*100:.1f}%)")
    print(f"Bright pixels (threshold=100) with CLAHE: {bright_pixels_clahe} ({bright_pixels_clahe/total_pixels*100:.1f}%)")
    print(f"Improvement: {bright_pixels_clahe - bright_pixels_orig:+d} pixels ({(bright_pixels_clahe - bright_pixels_orig)/bright_pixels_orig*100:+.1f}%)")

    # Show what areas are enhanced
    print("\n" + "="*60)
    print("REGIONAL ENHANCEMENT:")

    # Divide into 4 quadrants
    h, w = gray.shape
    regions = [
        ("Top-left", gray[0:h//2, 0:w//2], enhanced[0:h//2, 0:w//2]),
        ("Top-right", gray[0:h//2, w//2:w], enhanced[0:h//2, w//2:w]),
        ("Bottom-left", gray[h//2:h, 0:w//2], enhanced[h//2:h, 0:w//2]),
        ("Bottom-right", gray[h//2:h, w//2:w], enhanced[h//2:h, w//2:w])
    ]

    for name, orig_region, enhanced_region in regions:
        orig_mean = orig_region.mean()
        enh_mean = enhanced_region.mean()
        improvement = enh_mean - orig_mean
        print(f"  {name:15s}: {orig_mean:5.1f} → {enh_mean:5.1f} ({improvement:+5.1f})")

    print("\n" + "="*60)
    print("SUMMARY:")
    print("CLAHE enhances local contrast in each 6×6 tile independently.")
    print("This makes the ball stand out better from varying backgrounds.")
    print("=" * 60)

if __name__ == "__main__":
    image = sys.argv[1] if len(sys.argv) > 1 else "BallRecognition_Test/Ball_Rec1 - Indoor - High Light.png"
    visualize_clahe(image)
