#!/usr/bin/env python3
"""Test camera maximum frame rate"""
import cv2
import time

def test_camera_fps(camera_index=0):
    """Test the maximum FPS a camera can achieve"""

    # Try different FPS settings
    test_fps = [30, 60, 90, 120, 144, 240, 480]

    print(f"\n=== Testing Camera {camera_index} ===\n")

    for target_fps in test_fps:
        cap = cv2.VideoCapture(camera_index)
        cap.set(cv2.CAP_PROP_FPS, target_fps)

        # Give camera time to initialize
        time.sleep(0.5)

        # Check what FPS was actually set
        actual_fps = cap.get(cv2.CAP_PROP_FPS)
        width = cap.get(cv2.CAP_PROP_FRAME_WIDTH)
        height = cap.get(cv2.CAP_PROP_FRAME_HEIGHT)

        # Measure real-world FPS
        frame_count = 0
        start_time = time.time()
        test_duration = 2  # seconds

        while (time.time() - start_time) < test_duration:
            ret, frame = cap.read()
            if ret:
                frame_count += 1
            else:
                break

        elapsed = time.time() - start_time
        measured_fps = frame_count / elapsed if elapsed > 0 else 0

        cap.release()

        print(f"Target: {target_fps} FPS | Reported: {actual_fps:.1f} FPS | "
              f"Measured: {measured_fps:.1f} FPS | Resolution: {int(width)}x{int(height)}")

    print("\n=== Test Complete ===\n")

if __name__ == "__main__":
    # Test camera 0 (default camera)
    test_camera_fps(0)

    # Uncomment to test additional cameras:
    # test_camera_fps(1)
    # test_camera_fps(2)
