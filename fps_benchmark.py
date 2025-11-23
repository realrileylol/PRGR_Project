#!/usr/bin/env python3
"""
Raw FPS Benchmark Script
Tests camera performance at different resolutions and settings
Displays current camera configuration and achieved FPS
"""

import time
import sys
from picamera2 import Picamera2

def benchmark_fps(resolution, target_fps, duration=5):
    """
    Benchmark actual FPS at given resolution and settings

    Args:
        resolution: Tuple (width, height)
        target_fps: Target frame rate to set
        duration: How long to run test in seconds

    Returns:
        Tuple (actual_fps, frames_captured)
    """
    print(f"\n{'='*60}")
    print(f"Testing: {resolution[0]}x{resolution[1]} @ {target_fps} FPS")
    print(f"{'='*60}")

    try:
        picam2 = Picamera2()

        # Camera settings matching main.py (ultra-high-speed mode)
        shutter_speed = 800  # 0.8ms
        gain = 10.0

        config = picam2.create_video_configuration(
            main={"size": resolution},
            controls={
                "FrameRate": target_fps,
                "ExposureTime": shutter_speed,
                "AnalogueGain": gain,
            }
        )

        picam2.configure(config)

        # Get actual configured values
        metadata = picam2.camera_configuration()
        print(f"\nCamera Configuration:")
        print(f"   Resolution: {resolution[0]}x{resolution[1]}")
        print(f"   Target FPS: {target_fps}")
        print(f"   Shutter Speed: {shutter_speed}µs ({shutter_speed/1000:.2f}ms)")
        print(f"   Gain: {gain}x")
        print(f"   Format: {metadata['main']['format']}")
        print(f"   Stride: {metadata['main']['stride']}")

        picam2.start()

        # Warmup
        print(f"\nWarming up (1 second)...")
        time.sleep(1)
        for _ in range(10):
            picam2.capture_array()

        # Actual benchmark
        print(f" Benchmarking for {duration} seconds...")
        frame_count = 0
        start_time = time.time()

        while time.time() - start_time < duration:
            frame = picam2.capture_array()
            frame_count += 1

        end_time = time.time()
        elapsed = end_time - start_time
        actual_fps = frame_count / elapsed

        picam2.stop()
        picam2.close()

        print(f"\nResults:")
        print(f"   Frames Captured: {frame_count}")
        print(f"   Duration: {elapsed:.2f}s")
        print(f"   Actual FPS: {actual_fps:.2f}")
        print(f"   Target FPS: {target_fps}")
        print(f"   Efficiency: {(actual_fps/target_fps)*100:.1f}%")

        if actual_fps < target_fps * 0.95:
            print(f"    WARNING: Not achieving target FPS!")
        else:
            print(f"   Target FPS achieved!")

        return actual_fps, frame_count

    except Exception as e:
        print(f"Error: {e}")
        return 0, 0

def main():
    print("\n" + "="*60)
    print("PRGR PROJECT - RAW FPS BENCHMARK")
    print("OV9281 Camera Performance Testing")
    print("="*60)

    # Test configurations (resolution, target_fps)
    # OV9281 sensor supports various resolutions
    test_configs = [
        # Current configuration
        ((640, 480), 200, "Current Config (VGA)"),

        # Lower resolutions for higher FPS potential
        ((320, 240), 200, "QVGA - Lower Res"),
        ((320, 240), 300, "QVGA - Higher FPS"),
        ((320, 240), 400, "QVGA - Max FPS?"),

        # Test if 640x480 can go higher
        ((640, 480), 300, "VGA - Higher FPS Test"),

        # Even smaller for maximum FPS
        ((160, 120), 400, "Tiny - Max FPS Test"),
    ]

    results = []

    for resolution, target_fps, description in test_configs:
        print(f"\n\n{description}")
        actual_fps, frames = benchmark_fps(resolution, target_fps, duration=5)
        results.append((description, resolution, target_fps, actual_fps, frames))
        time.sleep(2)  # Cool down between tests

    # Summary
    print("\n\n" + "="*60)
    print("BENCHMARK SUMMARY")
    print("="*60)
    print(f"{'Description':<25} {'Resolution':<12} {'Target':<8} {'Actual':<8} {'Efficiency'}")
    print("-"*60)

    for desc, res, target, actual, frames in results:
        efficiency = (actual/target)*100 if target > 0 else 0
        res_str = f"{res[0]}x{res[1]}"
        print(f"{desc:<25} {res_str:<12} {target:<8} {actual:<8.1f} {efficiency:.1f}%")

    print("\n" + "="*60)
    print("RECOMMENDATIONS:")
    print("="*60)

    # Find best config
    best_fps = max(results, key=lambda x: x[3])
    print(f"Highest FPS achieved: {best_fps[3]:.1f} FPS")
    print(f"   Config: {best_fps[1][0]}x{best_fps[1][1]} @ {best_fps[2]} target")

    # Find config that meets target best
    meeting_target = [r for r in results if r[3] >= r[2] * 0.95]
    if meeting_target:
        print(f"\nConfigs meeting target FPS (>95%):")
        for r in meeting_target:
            print(f"   - {r[1][0]}x{r[1][1]} @ {r[2]} FPS (actual: {r[3]:.1f})")

    print("\n" + "="*60)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n Benchmark interrupted by user")
        sys.exit(0)
