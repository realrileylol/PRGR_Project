#!/usr/bin/env python3
"""
OPTIMIZED BALL DETECTION - Fast & Accurate for OV9281

Key improvements:
1. Adaptive strategies instead of fixed thresholds
2. Morphological operations to clean up noise
3. Size filtering to reject false positives
4. Better handling of reflections and shadows
5. Edge-based detection as backup
"""

import cv2
import numpy as np
import time
from picamera2 import Picamera2

def detect_ball_optimized(frame):
    """
    Optimized ball detection using multiple strategies
    Returns: (x, y, radius) or None
    """
    
    # Convert to grayscale
    gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
    
    # === STRATEGY 1: Bright blob detection ===
    # Golf balls are bright - use threshold to find them
    _, bright_mask = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY)
    
    # Clean up noise
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_OPEN, kernel)
    bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_CLOSE, kernel)
    
    # === STRATEGY 2: Edge detection ===
    # Ball edges are sharp
    edges = cv2.Canny(gray, 50, 150)
    edges = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, kernel)
    
    # === STRATEGY 3: Hough circles on combined mask ===
    # Combine both strategies
    combined = cv2.bitwise_or(bright_mask, edges)
    
    # Blur for better circle detection
    blurred = cv2.GaussianBlur(combined, (9, 9), 2)
    
    # Detect circles
    circles = cv2.HoughCircles(
        blurred,
        cv2.HOUGH_GRADIENT,
        dp=1,
        minDist=80,           # Min distance between circles
        param1=30,            # Edge threshold
        param2=20,            # Accumulator threshold (lower = more sensitive)
        minRadius=15,         # Min ball radius in pixels
        maxRadius=200         # Max ball radius
    )
    
    if circles is not None and len(circles[0]) > 0:
        # Get the circle with highest "score" (most circular)
        circles = np.uint16(np.around(circles))
        
        # Filter circles by size and brightness
        best_circle = None
        best_score = 0
        
        for circle in circles[0]:
            x, y, r = int(circle[0]), int(circle[1]), int(circle[2])
            
            # Check if circle is within frame
            if x - r < 0 or x + r >= frame.shape[1]:
                continue
            if y - r < 0 or y + r >= frame.shape[0]:
                continue
            
            # Extract circle region
            y1 = max(0, y - r)
            y2 = min(gray.shape[0], y + r)
            x1 = max(0, x - r)
            x2 = min(gray.shape[1], x + r)
            
            region = gray[y1:y2, x1:x2]
            
            if region.size == 0:
                continue
            
            # Score based on brightness and uniformity
            mean_brightness = np.mean(region)
            std_dev = np.std(region)
            
            # Golf balls are bright (>130) and relatively uniform
            if mean_brightness > 130:
                # Prefer uniform circles (low std dev = more likely ball)
                score = mean_brightness * (1.0 - np.clip(std_dev / 100, 0, 0.5))
                
                if score > best_score:
                    best_score = score
                    best_circle = circle
        
        if best_circle is not None:
            return tuple(best_circle)
    
    return None


def detect_ball_fast_fallback(frame):
    """
    FASTER fallback when optimized is too slow
    Trades some accuracy for speed
    """
    gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
    
    # Single-pass threshold
    _, mask = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY)
    
    # Minimal morphology
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=1)
    
    # Detect circles (faster parameters)
    circles = cv2.HoughCircles(
        mask,
        cv2.HOUGH_GRADIENT,
        dp=1,
        minDist=100,
        param1=20,
        param2=15,
        minRadius=15,
        maxRadius=150
    )
    
    if circles is not None and len(circles[0]) > 0:
        # Return largest circle
        circle = circles[0][np.argsort(circles[0][:, 2])[-1]]
        return tuple(circle)
    
    return None


def test_detection(use_optimized=True):
    """Test detection on live camera feed"""
    
    print("="*60)
    print("OPTIMIZED BALL DETECTION TEST")
    print("="*60)
    
    print("\n🎥 Initializing camera...")
    picam2 = Picamera2()
    
    config = picam2.create_video_configuration(
        main={"size": (640, 480), "format": "RGB888"},
        controls={
            "FrameRate": 60,
            "ExposureTime": 3000,  # Shorter shutter to reduce motion blur
            "AnalogueGain": 3.0    # Moderate gain
        }
    )
    
    picam2.configure(config)
    picam2.start()
    time.sleep(2)
    
    print("✅ Camera ready!")
    print("\n📍 Instructions:")
    print("  1. Hold ball 3-4 feet from camera")
    print("  2. Ensure good lighting (bright white on dark background)")
    print("  3. Watch for green circle detection")
    print("  4. Press 'q' to quit\n")
    
    frame_count = 0
    detection_count = 0
    total_time = 0
    
    try:
        while True:
            frame = picam2.capture_array()
            frame_count += 1
            
            # Time the detection
            start = time.perf_counter()
            
            if use_optimized:
                result = detect_ball_optimized(frame)
            else:
                result = detect_ball_fast_fallback(frame)
            
            elapsed = (time.perf_counter() - start) * 1000
            total_time += elapsed
            
            # Display frame with detection
            display = frame.copy()
            
            if result is not None:
                x, y, r = int(result[0]), int(result[1]), int(result[2])
                detection_count += 1
                
                # Draw circle
                cv2.circle(display, (x, y), r, (0, 255, 0), 2)  # Green
                cv2.circle(display, (x, y), 3, (0, 255, 0), -1)  # Center
                
                # Info
                cv2.putText(display, f"Ball at ({x},{y}) r={r}px", 
                          (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, 
                          (0, 255, 0), 2)
            else:
                cv2.putText(display, "No ball detected", 
                          (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, 
                          (0, 0, 255), 2)
            
            # Show timing
            avg_time = total_time / frame_count
            fps = 1000 / avg_time if avg_time > 0 else 0
            cv2.putText(display, f"Time: {elapsed:.1f}ms ({fps:.0f} fps)", 
                      (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.7, 
                      (255, 255, 0), 2)
            
            # Show detection rate
            detection_rate = (detection_count / frame_count) * 100 if frame_count > 0 else 0
            cv2.putText(display, f"Detected: {detection_rate:.0f}% ({detection_count}/{frame_count})", 
                      (10, 90), cv2.FONT_HERSHEY_SIMPLEX, 0.7, 
                      (255, 255, 0), 2)
            
            # Resize for display (half size to fit better)
            display_small = cv2.resize(display, (320, 240))
            cv2.imshow("Ball Detection", display_small)
            
            # Exit on 'q'
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
    
    except KeyboardInterrupt:
        pass
    
    finally:
        picam2.stop()
        cv2.destroyAllWindows()
        
        print("\n" + "="*60)
        print("RESULTS")
        print("="*60)
        print(f"Frames processed: {frame_count}")
        print(f"Detections: {detection_count}")
        print(f"Detection rate: {(detection_count/frame_count)*100:.1f}%")
        print(f"Avg time per frame: {total_time/frame_count:.2f}ms")
        print(f"Effective FPS: {1000/(total_time/frame_count):.1f}")


if __name__ == "__main__":
    import sys
    
    use_opt = "--fast" not in sys.argv
    test_detection(use_optimized=use_opt)
