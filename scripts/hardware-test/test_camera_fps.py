#!/usr/bin/env python3
"""
PRGR Launch Monitor - Camera FPS Test

Standalone test to verify the Raspberry Pi camera can sustain the target frame
rate. Uses rpicam-vid to capture raw frames at 640x400 @ 240fps for 5 seconds
and measures the actual throughput.

NOTE: This script only works on Raspberry Pi with libcamera and rpicam-vid
installed. It will not work on desktop Linux, macOS, or Windows.
"""

import subprocess
import sys
import time

# Test parameters
WIDTH = 640
HEIGHT = 400
TARGET_FPS = 240
DURATION_SECONDS = 5
PASS_THRESHOLD_FPS = 200  # Minimum acceptable FPS

# Each raw frame is WIDTH * HEIGHT bytes (8-bit grayscale / Y plane)
FRAME_SIZE = WIDTH * HEIGHT


def main():
    print("=== PRGR Camera FPS Test ===")
    print(f"Resolution:  {WIDTH}x{HEIGHT}")
    print(f"Target FPS:  {TARGET_FPS}")
    print(f"Duration:    {DURATION_SECONDS}s")
    print(f"Pass threshold: >= {PASS_THRESHOLD_FPS} FPS")
    print()

    # Build the rpicam-vid command
    # Output raw YUV420 to stdout, which we consume via pipe.
    # The Y plane alone is WIDTH*HEIGHT bytes per frame.
    cmd = [
        "rpicam-vid",
        "--width", str(WIDTH),
        "--height", str(HEIGHT),
        "--framerate", str(TARGET_FPS),
        "--timeout", str(DURATION_SECONDS * 1000),  # milliseconds
        "--codec", "yuv420",
        "--output", "-",  # stdout
        "--nopreview",
    ]

    print(f"Running: {' '.join(cmd)}")
    print()

    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError:
        print("ERROR: rpicam-vid not found. This test requires a Raspberry Pi")
        print("       with libcamera installed.")
        sys.exit(1)

    # Read frames from stdout
    # YUV420 frame size = WIDTH * HEIGHT * 3 / 2 (Y + U/4 + V/4)
    yuv420_frame_size = WIDTH * HEIGHT * 3 // 2
    frame_count = 0
    bytes_read = 0

    start_time = time.monotonic()

    while True:
        data = proc.stdout.read(yuv420_frame_size)
        if not data:
            break
        bytes_read += len(data)
        if len(data) == yuv420_frame_size:
            frame_count += 1

    elapsed = time.monotonic() - start_time
    proc.wait()

    # Report results
    if frame_count == 0:
        print("ERROR: No frames received.")
        stderr_output = proc.stderr.read().decode(errors="replace")
        if stderr_output:
            print(f"rpicam-vid stderr:\n{stderr_output}")
        sys.exit(1)

    actual_fps = frame_count / elapsed if elapsed > 0 else 0
    passed = actual_fps >= PASS_THRESHOLD_FPS

    print(f"Frames received:  {frame_count}")
    print(f"Elapsed time:     {elapsed:.2f}s")
    print(f"Frame size:       {yuv420_frame_size} bytes (YUV420)")
    print(f"Total data:       {bytes_read / (1024 * 1024):.1f} MB")
    print(f"Target FPS:       {TARGET_FPS}")
    print(f"Actual FPS:       {actual_fps:.1f}")
    print()
    print(f"Result: {'PASS' if passed else 'FAIL'} (threshold: {PASS_THRESHOLD_FPS} FPS)")

    # Print stderr from rpicam-vid (often contains useful diagnostics)
    stderr_output = proc.stderr.read().decode(errors="replace").strip()
    if stderr_output:
        print(f"\nrpicam-vid diagnostics:\n{stderr_output}")

    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
