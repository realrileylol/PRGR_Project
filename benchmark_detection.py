#!/usr/bin/env python3
"""
Benchmark script to compare Python vs C++ ball detection performance
Run this to verify the speedup from fast_detection module
"""

import time
import numpy as np
import cv2
from picamera2 import Picamera2

# Try to import fast detection
try:
    import fast_detection
    FAST_DETECTION_AVAILABLE = True
    print("✅ Fast C++ detection available")
except ImportError:
    FAST_DETECTION_AVAILABLE = False
    print("⚠️ Fast C++ detection not available - will only test Python")


def python_detect_ball(frame):
    """Python implementation (from main.py)"""
    gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
    hsv = cv2.cvtColor(frame, cv2.COLOR_RGB2HSV)

    # HSV Color filtering for WHITE golf balls
    lower_white = np.array([0, 0, 150])
    upper_white = np.array([180, 60, 255])
    white_color_mask = cv2.inRange(hsv, lower_white, upper_white)

    # Yellow golf balls
    lower_yellow = np.array([20, 100, 150])
    upper_yellow = np.array([30, 255, 255])
    yellow_color_mask = cv2.inRange(hsv, lower_yellow, upper_yellow)

    # Combine masks
    color_mask = cv2.bitwise_or(white_color_mask, yellow_color_mask)

    # Brightness mask
    _, brightness_mask = cv2.threshold(gray, 140, 255, cv2.THRESH_BINARY)

    # Combined mask
    combined_mask = cv2.bitwise_and(color_mask, brightness_mask)
    masked_gray = cv2.bitwise_and(gray, gray, mask=combined_mask)

    # Blur
    blurred = cv2.GaussianBlur(masked_gray, (9, 9), 2)

    # Detect circles
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
        for circle in circles[0]:
            x, y, r = int(circle[0]), int(circle[1]), int(circle[2])

            y1, y2 = max(0, y - r), min(gray.shape[0], y + r)
            x1, x2 = max(0, x - r), min(gray.shape[1], x + r)

            ball_region_gray = gray[y1:y2, x1:x2]
            ball_region_hsv = hsv[y1:y2, x1:x2]

            if ball_region_gray.size > 0 and ball_region_hsv.size > 0:
                mean_brightness = np.mean(ball_region_gray)
                mean_saturation = np.mean(ball_region_hsv[:, :, 1])

                if mean_brightness > 130 and mean_saturation < 80:
                    mask_region = combined_mask[y1:y2, x1:x2]
                    bright_pixel_ratio = np.count_nonzero(mask_region) / mask_region.size if mask_region.size > 0 else 0

                    if bright_pixel_ratio > 0.6:
                        return circle

    return None


def benchmark_live_camera(num_frames=100):
    """Benchmark using live camera feed"""
    print("\n" + "="*60)
    print("LIVE CAMERA BENCHMARK")
    print("="*60)

    # Initialize camera
    print("\nInitializing camera at 100 FPS...")
    picam2 = Picamera2()
    config = picam2.create_video_configuration(
        main={"size": (640, 480), "format": "RGB888"},
        controls={
            "FrameRate": 100,
            "ExposureTime": 5000,
            "AnalogueGain": 2.0
        }
    )
    picam2.configure(config)
    picam2.start()
    time.sleep(2)  # Let camera stabilize

    print(f"Capturing {num_frames} frames for benchmark...\n")

    # Capture test frames
    frames = []
    for _ in range(num_frames):
        frames.append(picam2.capture_array())

    picam2.stop()

    # Benchmark Python detection
    print("Benchmarking Python detection...")
    start = time.perf_counter()
    python_results = []
    for frame in frames:
        python_results.append(python_detect_ball(frame))
    python_time = time.perf_counter() - start

    python_avg = (python_time / num_frames) * 1000  # ms per frame
    python_fps = num_frames / python_time

    print(f"  Total time: {python_time:.3f}s")
    print(f"  Avg per frame: {python_avg:.2f}ms")
    print(f"  Effective FPS: {python_fps:.1f}")
    print(f"  Detections: {sum(1 for r in python_results if r is not None)}/{num_frames}")

    # Benchmark C++ detection if available
    if FAST_DETECTION_AVAILABLE:
        print("\nBenchmarking C++ detection...")
        start = time.perf_counter()
        cpp_results = []
        for frame in frames:
            cpp_results.append(fast_detection.detect_ball(frame))
        cpp_time = time.perf_counter() - start

        cpp_avg = (cpp_time / num_frames) * 1000  # ms per frame
        cpp_fps = num_frames / cpp_time

        print(f"  Total time: {cpp_time:.3f}s")
        print(f"  Avg per frame: {cpp_avg:.2f}ms")
        print(f"  Effective FPS: {cpp_fps:.1f}")
        print(f"  Detections: {sum(1 for r in cpp_results if r is not None)}/{num_frames}")

        # Calculate speedup
        speedup = python_time / cpp_time
        print(f"\n{'='*60}")
        print(f"SPEEDUP: {speedup:.2f}x faster with C++")
        print(f"{'='*60}")

        # Check if can keep up at 100 FPS
        target_time = 10.0  # ms (100 FPS = 10ms per frame)
        print(f"\nTarget for 100 FPS: {target_time:.1f}ms per frame")
        print(f"  Python: {python_avg:.2f}ms - {'✅ CAN keep up' if python_avg < target_time else '❌ TOO SLOW'}")
        print(f"  C++:    {cpp_avg:.2f}ms - {'✅ CAN keep up' if cpp_avg < target_time else '❌ TOO SLOW'}")

        # Check for 120 FPS
        target_time_120 = 8.33  # ms (120 FPS)
        print(f"\nTarget for 120 FPS: {target_time_120:.1f}ms per frame")
        print(f"  Python: {python_avg:.2f}ms - {'✅ CAN keep up' if python_avg < target_time_120 else '❌ TOO SLOW'}")
        print(f"  C++:    {cpp_avg:.2f}ms - {'✅ CAN keep up' if cpp_avg < target_time_120 else '❌ TOO SLOW'}")

    else:
        print("\n⚠️ C++ detection not available - build with ./build_fast_detection.sh")


def benchmark_synthetic_frames(num_frames=1000):
    """Benchmark using synthetic test frames"""
    print("\n" + "="*60)
    print("SYNTHETIC FRAMES BENCHMARK")
    print("="*60)
    print(f"\nGenerating {num_frames} random test frames...")

    # Generate random frames
    frames = [np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8) for _ in range(num_frames)]

    # Benchmark Python
    print("\nBenchmarking Python detection...")
    start = time.perf_counter()
    for frame in frames:
        python_detect_ball(frame)
    python_time = time.perf_counter() - start
    python_avg = (python_time / num_frames) * 1000

    print(f"  Total time: {python_time:.3f}s")
    print(f"  Avg per frame: {python_avg:.2f}ms")

    # Benchmark C++
    if FAST_DETECTION_AVAILABLE:
        print("\nBenchmarking C++ detection...")
        start = time.perf_counter()
        for frame in frames:
            fast_detection.detect_ball(frame)
        cpp_time = time.perf_counter() - start
        cpp_avg = (cpp_time / num_frames) * 1000

        print(f"  Total time: {cpp_time:.3f}s")
        print(f"  Avg per frame: {cpp_avg:.2f}ms")

        speedup = python_time / cpp_time
        print(f"\n{'='*60}")
        print(f"SPEEDUP: {speedup:.2f}x faster with C++")
        print(f"{'='*60}")


if __name__ == "__main__":
    print("="*60)
    print("BALL DETECTION PERFORMANCE BENCHMARK")
    print("="*60)

    # Check if camera is available
    try:
        benchmark_live_camera(num_frames=100)
    except Exception as e:
        print(f"\n⚠️ Camera not available: {e}")
        print("Running synthetic benchmark instead...\n")
        benchmark_synthetic_frames(num_frames=500)

    print("\n" + "="*60)
    print("BENCHMARK COMPLETE")
    print("="*60)
