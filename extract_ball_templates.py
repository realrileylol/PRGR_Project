#!/usr/bin/env python3
"""
Extract ball-only templates from full scene images
Finds the ball (green circle) and crops to 80x80 region
"""
import cv2
import numpy as np
import os

# Template source images with approximate ball locations
templates = {
    'FrontLeft_1.png': (60, 650),      # Bottom-left
    'FrontRight_1.png': (570, 650),    # Bottom-right
    'BackLeft_1.png': (120, 600),      # Back-left
    'BackRight_1.png': (540, 620),     # Back-right
    'BallCalibration_1.png': (180, 120),  # Center, small image
    'pic1.png': (525, 200),            # Right side
    'pic2.png': (460, 260),            # Center-right
    'pic3.png': (465, 235),            # Center-right
}

output_dir = 'ball_templates_cropped'
os.makedirs(output_dir, exist_ok=True)

for filename, (approx_x, approx_y) in templates.items():
    filepath = f'ball_templates/{filename}'

    print(f'\nProcessing {filename}...')

    # Read image
    img = cv2.imread(filepath, cv2.IMREAD_GRAYSCALE)
    if img is None:
        print(f'  ❌ Failed to load {filepath}')
        continue

    # Create search region around approximate location (200x200)
    search_size = 100
    x1 = max(0, approx_x - search_size)
    y1 = max(0, approx_y - search_size)
    x2 = min(img.shape[1], approx_x + search_size)
    y2 = min(img.shape[0], approx_y + search_size)

    search_region = img[y1:y2, x1:x2]

    # Apply CLAHE to enhance contrast (same as camera detection)
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(search_region)

    # Detect circles in search region
    circles = cv2.HoughCircles(
        enhanced,
        cv2.HOUGH_GRADIENT,
        dp=1,
        minDist=30,
        param1=50,
        param2=30,
        minRadius=15,
        maxRadius=35
    )

    if circles is None or len(circles[0]) == 0:
        print(f'  ⚠ No ball detected, using approximate location')
        # Use approximate location
        crop_size = 40
        cx, cy = approx_x, approx_y
    else:
        # Use detected circle
        circle = circles[0][0]
        cx = int(x1 + circle[0])
        cy = int(y1 + circle[1])
        radius = int(circle[2])
        crop_size = max(40, radius * 2)
        print(f'  ✓ Ball detected at ({cx}, {cy}) radius={radius}')

    # Crop 80x80 region around ball
    crop_x1 = max(0, cx - crop_size)
    crop_y1 = max(0, cy - crop_size)
    crop_x2 = min(img.shape[1], cx + crop_size)
    crop_y2 = min(img.shape[0], cy + crop_size)

    ball_crop = img[crop_y1:crop_y2, crop_x1:crop_x2]

    # Resize to standard 60x60
    ball_resized = cv2.resize(ball_crop, (60, 60))

    # Normalize brightness
    ball_normalized = cv2.normalize(ball_resized, None, 0, 255, cv2.NORM_MINMAX)

    # Save
    output_path = f'{output_dir}/{filename}'
    cv2.imwrite(output_path, ball_normalized)
    print(f'  💾 Saved {output_path} ({ball_normalized.shape})')

print(f'\n✅ Extracted {len(templates)} ball templates to {output_dir}/')
