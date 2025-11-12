import sys
import os
import subprocess
import threading
import time
import numpy as np
from collections import deque

os.environ["QT_QUICK_CONTROLS_STYLE"] = "Material"

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType
from PySide6.QtCore import qInstallMessageHandler, QObject, Signal, Slot, QUrl
from PySide6.QtMultimedia import QSoundEffect
from ProfileManager import ProfileManager
from HistoryManager import HistoryManager
from SettingsManager import SettingsManager

# Try to import Picamera2 and cv2 (only works on Pi)
try:
    from picamera2 import Picamera2
    import cv2
    CAMERA_AVAILABLE = True
except ImportError:
    CAMERA_AVAILABLE = False
    print("⚠️ Picamera2 or OpenCV not available - capture features disabled")

# Try to import fast C++ detection module (3-5x speedup)
try:
    import fast_detection
    FAST_DETECTION_AVAILABLE = True
    print("✅ Fast C++ detection loaded - using optimized ball detection")
except ImportError:
    FAST_DETECTION_AVAILABLE = False
    print("⚠️ Fast C++ detection not available - using Python fallback (build with: ./build_fast_detection.sh)")

# ============================================
# Camera Manager Class
# ============================================
class CameraManager(QObject):
    """Manages Raspberry Pi camera using rpicam-vid"""

    def __init__(self, settings_manager=None):
        super().__init__()
        self.camera_process = None
        self.settings_manager = settings_manager

    @Slot()
    def startCamera(self):
        """Start the Raspberry Pi camera preview embedded in the UI"""
        if self.camera_process is not None:
            print("⚠️ Camera is already running")
            return

        # Load camera settings from SettingsManager
        shutter_speed = 5000
        gain = 2.0
        ev_compensation = 0.0
        frame_rate = 30

        if self.settings_manager:
            shutter_speed = int(self.settings_manager.getNumber("cameraShutterSpeed") or 5000)
            gain = float(self.settings_manager.getNumber("cameraGain") or 2.0)
            ev_compensation = float(self.settings_manager.getNumber("cameraEV") or 0.0)
            frame_rate = int(self.settings_manager.getNumber("cameraFrameRate") or 30)
            time_of_day = self.settings_manager.getString("cameraTimeOfDay") or "Cloudy/Shade"
            print(f"📷 Camera settings: {time_of_day} | Shutter: {shutter_speed}µs | Gain: {gain}x | EV: {ev_compensation:+.1f} | FPS: {frame_rate}")

        try:
            # Camera preview embedded in the black rectangle area
            # Window is frameless at (0,0), so coordinates match QML layout exactly
            # x=22 (margin+border), y=82 (margin 20 + header 48 + spacing 12 + border 2), width=756, height=254
            print("🎥 Starting embedded camera preview...")

            # Build command with camera settings
            cmd = [
                'rpicam-vid',
                '--timeout', '0',                # Run indefinitely
                '--width', '640',                # Camera resolution
                '--height', '480',
                '--framerate', str(frame_rate),  # Frames per second
                '--preview', '22,82,756,254',    # x,y,width,height - matches black rectangle exactly
                '--shutter', str(shutter_speed), # Exposure time in microseconds
                '--gain', str(gain),             # Analog gain
                '--ev', str(ev_compensation),    # Exposure compensation in stops
                '--awb', 'auto'                  # Auto white balance
            ]

            self.camera_process = subprocess.Popen(cmd)
            print("✅ Camera started successfully")
        except FileNotFoundError:
            try:
                # Fallback to rpicam-hello with same embedded settings
                print("🎥 Starting camera with rpicam-hello...")
                cmd = [
                    'rpicam-hello',
                    '--timeout', '0',
                    '--width', '640',
                    '--height', '480',
                    '--framerate', str(frame_rate),
                    '--preview', '22,82,756,254',
                    '--shutter', str(shutter_speed),
                    '--gain', str(gain),
                    '--ev', str(ev_compensation)
                ]
                self.camera_process = subprocess.Popen(cmd)
                print("✅ Camera started successfully")
            except FileNotFoundError:
                print("❌ Camera tools not found. Install with: sudo apt install rpicam-apps")
                self.camera_process = None
        except Exception as e:
            print(f"❌ Failed to start camera: {e}")
            self.camera_process = None

    @Slot()
    def stopCamera(self):
        """Stop the camera preview"""
        if self.camera_process is not None:
            print("🛑 Stopping camera...")
            self.camera_process.terminate()
            try:
                self.camera_process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.camera_process.kill()
            self.camera_process = None
            print("✅ Camera stopped")
        else:
            print("⚠️ Camera is not running")

    def __del__(self):
        """Cleanup on destruction"""
        self.stopCamera()

# ============================================
# Capture Manager Class
# ============================================
class CaptureManager(QObject):
    """Manages automatic ball capture with motion detection"""

    # Signals to update UI
    statusChanged = Signal(str, str)  # (status, color) - e.g. ("Ball Locked", "green")
    shotCaptured = Signal(int)  # shot_number
    errorOccurred = Signal(str)  # error_message

    def __init__(self, settings_manager=None, camera_manager=None):
        super().__init__()
        self.settings_manager = settings_manager
        self.camera_manager = camera_manager
        self.is_running = False
        self.capture_thread = None
        self.picam2 = None  # Store camera instance for cleanup
        self._stopping = False  # Flag to track if we're in the process of stopping

    @Slot()
    def startCapture(self):
        """Start the capture process in a background thread"""
        if not CAMERA_AVAILABLE:
            self.errorOccurred.emit("Camera not available on this system")
            return

        if self.is_running:
            print("⚠️ Capture already running")
            return

        # Wait for previous capture to fully stop (if stopping)
        if self._stopping or self.capture_thread is not None:
            print("⏳ Waiting for previous capture to finish...")
            wait_count = 0
            while (self._stopping or self.capture_thread is not None) and wait_count < 20:
                time.sleep(0.2)  # Wait up to 4 seconds total
                wait_count += 1

            if self._stopping:
                print("⚠️ Previous capture still stopping - please try again")
                self.errorOccurred.emit("Previous capture still stopping - please wait")
                return

        # Stop camera preview if it's running
        if self.camera_manager:
            print("🛑 Stopping camera preview before capture...")
            self.camera_manager.stopCamera()
            time.sleep(1)  # Give camera time to release

        self.is_running = True
        self.capture_thread = threading.Thread(target=self._capture_loop, daemon=True)
        self.capture_thread.start()
        print("🎥 Capture started")

    @Slot()
    def stopCapture(self):
        """Stop the capture process (non-blocking)"""
        print("🛑 Stopping capture...")
        self._stopping = True
        self.is_running = False

        # Stop camera if running
        if self.picam2 is not None:
            try:
                self.picam2.stop()
                print("   Camera stopped")
            except Exception as e:
                print(f"   Warning stopping camera: {e}")
            self.picam2 = None

        # Don't block GUI thread with join() - thread will exit naturally
        # The background thread's finally block will handle cleanup

        self.statusChanged.emit("Stopped", "gray")
        print("✅ Capture stop requested (background thread will cleanup)")

    def _detect_ball(self, frame):
        """Detect golf ball in frame using color-filtered circle detection

        Focuses specifically on white/bright colored balls and ignores
        darker objects like shoes, clubs, metallic reflections, etc.

        Uses fast C++ implementation if available (3-5x speedup),
        otherwise falls back to Python version.
        """
        # Use fast C++ detection if available
        if FAST_DETECTION_AVAILABLE:
            result = fast_detection.detect_ball(frame)
            if result is not None:
                # C++ returns tuple (x, y, radius)
                return np.array([result[0], result[1], result[2]], dtype=np.uint16)
            return None

        # Python fallback - OPTIMIZED for OV9281 monochrome camera
        # Works on both color and grayscale cameras

        # Convert to grayscale (handles both color RGB and monochrome input)
        if len(frame.shape) == 3:
            gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
        else:
            gray = frame  # Already grayscale (OV9281)

        # === CLAHE PREPROCESSING (PiTrac-style) ===
        # Enhance contrast for better ball detection in varying lighting
        clahe = cv2.createCLAHE(clipLimit=6.0, tileGridSize=(6, 6))
        enhanced_gray = clahe.apply(gray)

        # === BRIGHTNESS DETECTION (ultra-sensitive for dark camera) ===
        # User's ball has brightness of only 24, so threshold must be very low
        _, bright_mask = cv2.threshold(enhanced_gray, 50, 255, cv2.THRESH_BINARY)

        # Clean up noise with morphological operations
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
        bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_OPEN, kernel)   # Remove small noise
        bright_mask = cv2.morphologyEx(bright_mask, cv2.MORPH_CLOSE, kernel)  # Fill small gaps

        # === EDGE DETECTION (sharp circular edges) ===
        edges = cv2.Canny(enhanced_gray, 50, 150)

        # Combine bright regions + edges for robust detection
        combined = cv2.bitwise_or(bright_mask, edges)

        # Blur for smoother circle detection
        # MATCHED TO optimized_detection.py
        blurred = cv2.GaussianBlur(combined, (9, 9), 2)

        # === ULTRA-SENSITIVE CIRCLE DETECTION ===
        # Very low param2 values for maximum sensitivity
        param2_values = [10, 8, 12, 15, 7, 6, 5]  # Much more sensitive than before
        circles = None

        for param2 in param2_values:
            circles = cv2.HoughCircles(
                blurred,
                cv2.HOUGH_GRADIENT,
                dp=1,
                minDist=50,         # Reduced from 80 for easier detection
                param1=20,          # Reduced from 30 for easier detection
                param2=param2,      # ULTRA-SENSITIVE values
                minRadius=10,       # Reduced from 15 to catch smaller balls
                maxRadius=250       # Increased to catch larger detections
            )

            # Accept any circles found (no ideal range restriction)
            if circles is not None:
                break

        if circles is not None and len(circles[0]) > 0:
            circles = np.uint16(np.around(circles))

            # === CONCENTRIC CIRCLE REMOVAL (PiTrac-style) ===
            # Remove duplicate circles with same center but different radius
            filtered_circles = []
            used_centers = set()

            for circle in circles[0]:
                x, y, r = int(circle[0]), int(circle[1]), int(circle[2])

                # Check if this center is already used (within 10px tolerance)
                is_duplicate = False
                for (cx, cy) in used_centers:
                    if abs(x - cx) < 10 and abs(y - cy) < 10:
                        is_duplicate = True
                        break

                if not is_duplicate:
                    filtered_circles.append(circle)
                    used_centers.add((x, y))

            # === SIMPLIFIED VALIDATION (optimized_detection.py style) ===
            # Score all filtered circles
            best_circle = None
            best_score = 0

            for circle in filtered_circles:
                x, y, r = int(circle[0]), int(circle[1]), int(circle[2])

                # Validate bounds
                if x - r < 0 or x + r >= gray.shape[1]:
                    continue
                if y - r < 0 or y + r >= gray.shape[0]:
                    continue

                # Extract ball region for validation
                y1 = max(0, y - r)
                y2 = min(gray.shape[0], y + r)
                x1 = max(0, x - r)
                x2 = min(gray.shape[1], x + r)

                region = gray[y1:y2, x1:x2]

                if region.size == 0:
                    continue

                # === ULTRA-LENIENT SCORING (accept almost anything circular) ===
                # Just take the first circle found - velocity detection will filter false hits
                best_circle = circle
                break  # Take first valid circle

            # Return best circle immediately (skip refinement for ultra-fast detection)
            if best_circle is not None:
                return best_circle

        return None

    def _ball_has_moved(self, prev_ball, curr_ball, threshold=40):
        """Check if ball has moved significantly"""
        if prev_ball is None or curr_ball is None:
            return False

        dx = int(curr_ball[0]) - int(prev_ball[0])
        dy = int(curr_ball[1]) - int(prev_ball[1])
        distance = np.sqrt(dx**2 + dy**2)

        return distance > threshold

    def _ball_displacement(self, prev_ball, curr_ball):
        """Calculate displacement distance between two ball positions in pixels"""
        if prev_ball is None or curr_ball is None:
            return 0

        dx = int(curr_ball[0]) - int(prev_ball[0])
        dy = int(curr_ball[1]) - int(prev_ball[1])
        distance = np.sqrt(dx**2 + dy**2)

        return distance

    def _is_same_ball(self, ball1, ball2, radius_tolerance=0.5):
        """Check if two detections are the same ball based on position and radius

        Uses relaxed radius tolerance (50%) because HoughCircles can vary
        the detected radius significantly due to ball dimples and lighting.
        """
        if ball1 is None or ball2 is None:
            return False

        # Check position - balls should be in roughly same location
        x1, y1 = int(ball1[0]), int(ball1[1])
        x2, y2 = int(ball2[0]), int(ball2[1])
        position_distance = np.sqrt((x2 - x1)**2 + (y2 - y1)**2)

        # If ball moved more than 100 pixels, it's probably not the same ball
        if position_distance > 100:
            return False

        # Check radius with relaxed tolerance
        r1 = int(ball1[2])
        r2 = int(ball2[2])

        # Radius should be within 50% of original (relaxed for dimpled balls)
        radius_diff = abs(r1 - r2) / max(r1, r2)
        return radius_diff < radius_tolerance

    def _ball_exited_hitbox(self, locked_ball, current_ball, hitbox_inches=6.0):
        """Check if ball exited the hit box zone (6x6 inch safe area)"""
        if locked_ball is None or current_ball is None:
            return False

        # Calculate pixels per inch from ball radius
        # Golf ball radius = 0.84 inches (diameter 1.68")
        ball_radius_px = int(locked_ball[2])
        pixels_per_inch = ball_radius_px / 0.84

        # Hit box is 6x6 inches = 3 inches in each direction from center
        hitbox_radius_px = (hitbox_inches / 2.0) * pixels_per_inch

        # Check if ball moved outside hit box
        dx = int(current_ball[0]) - int(locked_ball[0])
        dy = int(current_ball[1]) - int(locked_ball[1])
        distance = np.sqrt(dx**2 + dy**2)

        return distance > hitbox_radius_px

    def _capture_loop(self):
        """Main capture loop running in background thread"""
        try:
            # Create captures folder
            captures_folder = "ball_captures"
            os.makedirs(captures_folder, exist_ok=True)

            # Find next shot number
            existing_shots = [f for f in os.listdir(captures_folder) if f.startswith("shot_")]
            if existing_shots:
                shot_numbers = [int(f.split("_")[1]) for f in existing_shots]
                next_shot = max(shot_numbers) + 1
            else:
                next_shot = 0

            # Load camera settings
            shutter_speed = int(self.settings_manager.getNumber("cameraShutterSpeed") or 5000)
            gain = float(self.settings_manager.getNumber("cameraGain") or 2.0)
            frame_rate = int(self.settings_manager.getNumber("cameraFrameRate") or 30)

            print(f"📷 Capture settings: Shutter={shutter_speed}µs, Gain={gain}x, FPS={frame_rate}")

            # Initialize camera with retry logic (camera hardware may need time to release)
            camera_initialized = False
            for attempt in range(3):
                try:
                    if attempt > 0:
                        print(f"   Retry attempt {attempt + 1}/3...")
                        time.sleep(2)  # Wait longer between retries

                    self.picam2 = Picamera2()
                    config = self.picam2.create_video_configuration(
                        main={"size": (640, 480), "format": "RGB888"},
                        controls={
                            "FrameRate": frame_rate,
                            "ExposureTime": shutter_speed,
                            "AnalogueGain": gain
                        }
                    )
                    self.picam2.configure(config)
                    self.picam2.start()
                    time.sleep(2)
                    camera_initialized = True
                    print("✅ Camera initialized successfully")
                    break
                except Exception as e:
                    print(f"⚠️ Camera init attempt {attempt + 1} failed: {e}")
                    if self.picam2 is not None:
                        try:
                            self.picam2.close()
                        except:
                            pass
                        self.picam2 = None

            if not camera_initialized:
                raise Exception("Failed to initialize camera after 3 attempts. Please wait a moment and try again.")

            self.statusChanged.emit("Detecting ball...", "yellow")

            original_ball = None
            stable_frames = 0
            last_seen_ball = None
            frames_since_seen = 0
            consecutive_frames_seen = 0  # Track consecutive frames ball is visible (for debouncing)
            prev_ball = None
            frames_since_lock = 0  # Track how long ball has been locked
            detection_history = deque(maxlen=10)  # Track last 10 frames: True=detected, False=not detected
            radius_history = deque(maxlen=5)  # Track last 5 radius values for smoothing
            frame_buffer = deque(maxlen=10)  # Circular buffer for 10 pre-impact frames

            # Calculate target frame time for adaptive sleep
            target_frame_time = 1.0 / frame_rate
            print(f"🎯 Target frame time: {target_frame_time*1000:.1f}ms ({frame_rate} FPS)")

            # FPS tracking for visualization
            fps_counter = 0
            fps_start_time = time.time()
            current_fps = 0

            # Debug frame saving (saves every 10 frames to avoid file spam)
            debug_frame_counter = 0
            print("📺 Debug mode: Saving detection frames to debug_detection_*.jpg every 1 second")

            while self.is_running:
                loop_start_time = time.time()

                frame = self.picam2.capture_array()
                frame_buffer.append(frame.copy())  # Store frame in circular buffer

                # Update FPS counter
                fps_counter += 1
                if time.time() - fps_start_time >= 1.0:
                    current_fps = fps_counter
                    fps_counter = 0
                    fps_start_time = time.time()

                # Create visualization frame
                vis_frame = frame.copy()

                current_ball = self._detect_ball(frame)

                if current_ball is not None:
                    x, y, r = int(current_ball[0]), int(current_ball[1]), int(current_ball[2])

                    # Track radius for smoothing (helps with HoughCircles instability)
                    radius_history.append(r)  # deque auto-truncates at maxlen

                    # Use median radius for more stable validation
                    median_radius = int(np.median(radius_history)) if len(radius_history) >= 3 else r
                    smoothed_ball = np.array([x, y, median_radius], dtype=current_ball.dtype)

                    # Validate this is the same ball (not a person/other object)
                    if last_seen_ball is not None and not self._is_same_ball(last_seen_ball, smoothed_ball):
                        # Skip this detection, likely a different object
                        # (verbose logging removed to reduce console spam)
                        detection_history.append(False)  # Track as not detected (deque auto-truncates)
                        radius_history.clear()  # Reset radius smoothing
                        continue

                    # Ball is now visible
                    consecutive_frames_seen += 1

                    # DEBOUNCING: Only reset frames_since_seen if ball visible for 2+ consecutive frames
                    # This prevents brief 1-frame reappearances from canceling shot detection
                    if consecutive_frames_seen >= 2:
                        # Ball has been visible for 2+ frames - truly reappeared, cancel shot detection
                        if frames_since_seen > 0 and frames_since_seen < 3:
                            # Ball reappeared before shot could be detected (club positioning, not a shot)
                            pass  # Don't spam console
                        frames_since_seen = 0
                    # else: ball visible for only 1 frame - might be flicker, keep counting frames_since_seen

                    last_seen_ball = smoothed_ball  # Use smoothed radius for tracking

                    # Track detection in history
                    detection_history.append(True)  # deque auto-truncates at maxlen

                    # Check if ball has been stable
                    if original_ball is None:
                        # Check radius consistency with previous frame
                        if prev_ball is not None:
                            if not self._is_same_ball(prev_ball, smoothed_ball):
                                # Radius changed too much, probably different object
                                print(f"⚠️ Radius inconsistency during lock - resetting")
                                stable_frames = 0
                                prev_ball = None
                                radius_history.clear()  # Reset radius smoothing
                                continue
                            elif self._ball_has_moved(prev_ball, current_ball, threshold=10):
                                # Ball moved too much, reset stability counter
                                stable_frames = 0
                            else:
                                stable_frames += 1
                        else:
                            stable_frames += 1

                        prev_ball = smoothed_ball  # Use smoothed radius for consistency

                        if stable_frames >= 5:  # Only 5 stable frames needed for ULTRA-FAST locking
                            original_ball = smoothed_ball
                            self.statusChanged.emit("Ready - Hit Ball!", "green")
                            print(f"🎯 Ball locked at ({x}, {y}) with radius {r}px")
                            print(f"   Triggers on: RAPID movement (>20px/frame) OR ball exits frame")
                            print(f"   Will capture 20 frames (10 before + 10 after impact)")
                            stable_frames = 0
                            prev_ball = None
                            frames_since_lock = 0

                    # Ball is locked and still visible - check for RAPID MOVEMENT (hit detection)
                    elif original_ball is not None and self._is_same_ball(original_ball, current_ball):
                        # Ball detected and matches - check if it's moving rapidly (being hit)

                        # Calculate displacement from original locked position
                        displacement = self._ball_displacement(original_ball, current_ball)

                        # Check if ball moved significantly (potential hit)
                        # At 100 FPS: 30px/frame = 3000 px/sec
                        # At 100 FPS: 20px/frame = 2000 px/sec
                        if displacement > 20:  # Rapid movement in single frame = HIT!
                            # Ball is moving fast - this is a shot!
                            print(f"🏌️ RAPID BALL MOVEMENT DETECTED!")
                            print(f"   Displacement: {displacement:.1f} px in one frame")
                            print(f"   Estimated velocity: {displacement * frame_rate:.1f} px/sec")
                            self.statusChanged.emit("Capturing...", "red")

                            # Capture frames: 5 BEFORE impact (from buffer) + 5 AFTER impact
                            frames = list(frame_buffer)  # Get pre-impact frames from circular buffer
                            print(f"   📸 Captured {len(frames)} pre-impact frames from buffer")

                            # Capture post-impact frames
                            frame_delay = 1.0 / frame_rate
                            for i in range(10):
                                capture_frame = self.picam2.capture_array()
                                frames.append(capture_frame)
                                time.sleep(frame_delay)

                            print(f"   📸 Total: {len(frames)} frames captured (10 before + 10 after impact)")

                            # Save frames
                            for i, save_frame in enumerate(frames):
                                filename = f"shot_{next_shot:03d}_frame_{i:03d}.jpg"
                                filepath = os.path.join(captures_folder, filename)
                                cv2.imwrite(filepath, cv2.cvtColor(save_frame, cv2.COLOR_RGB2BGR))

                            print(f"✅ Shot #{next_shot} saved!")
                            self.shotCaptured.emit(next_shot)

                            # Stop after capture
                            self.picam2.stop()
                            self.picam2 = None
                            self.is_running = False
                            return

                        frames_since_lock += 1

                    # Detected a ball but radius doesn't match locked ball
                    elif original_ball is not None and not self._is_same_ball(original_ball, current_ball):
                        # Different ball detected - could be original ball that moved VERY fast
                        # Check displacement anyway in case it's a hit
                        displacement = self._ball_displacement(original_ball, current_ball)

                        # Even if radius doesn't match, check for rapid movement
                        # Ball being hit can cause radius variation due to motion blur
                        if displacement > 30:  # Higher threshold since radius changed
                            print(f"🏌️ RAPID BALL MOVEMENT DETECTED (radius mismatch)!")
                            print(f"   Displacement: {displacement:.1f} px in one frame")
                            print(f"   Estimated velocity: {displacement * frame_rate:.1f} px/sec")
                            self.statusChanged.emit("Capturing...", "red")

                            # Capture frames: 5 BEFORE impact (from buffer) + 5 AFTER impact
                            frames = list(frame_buffer)
                            print(f"   📸 Captured {len(frames)} pre-impact frames from buffer")

                            # Capture post-impact frames
                            frame_delay = 1.0 / frame_rate
                            for i in range(10):
                                capture_frame = self.picam2.capture_array()
                                frames.append(capture_frame)
                                time.sleep(frame_delay)

                            print(f"   📸 Total: {len(frames)} frames captured (10 before + 10 after impact)")

                            # Save frames
                            for i, save_frame in enumerate(frames):
                                filename = f"shot_{next_shot:03d}_frame_{i:03d}.jpg"
                                filepath = os.path.join(captures_folder, filename)
                                cv2.imwrite(filepath, cv2.cvtColor(save_frame, cv2.COLOR_RGB2BGR))

                            print(f"✅ Shot #{next_shot} saved!")
                            self.shotCaptured.emit(next_shot)

                            # Stop after capture
                            self.picam2.stop()
                            self.picam2 = None
                            self.is_running = False
                            return

                        # No rapid movement - ignore this detection
                        # (verbose logging removed to reduce console spam)
                        frames_since_lock += 1

                else:
                    # Ball not detected - it disappeared
                    frames_since_seen += 1
                    consecutive_frames_seen = 0  # Reset consecutive seen counter

                    # Track detection in history
                    detection_history.append(False)  # deque auto-truncates at maxlen

                    # KEEP UI GREEN if ball is locked and temporarily obscured (e.g., club head blocking)
                    # Only turn red if ball is lost for extended period
                    if original_ball is not None and frames_since_seen < 60:
                        # Ball is locked but temporarily obscured - keep green status
                        # This allows club positioning without losing the "Ready" state
                        # (verbose logging removed to reduce console spam)
                        pass

                    # If ball is locked and disappeared, check if this is IMPACT
                    # Note: Club head can obscure ball during swing, causing brief flickering
                    # We verify by checking if ball STAYS gone for 3+ frames
                    if original_ball is not None and frames_since_seen == 1:
                        # Ball just disappeared - start verification
                        print(f"⚡ Ball disappeared - verifying if shot...")

                    # Check if we should trigger after verifying ball is gone
                    # Reduced from 5 to 3 frames for faster response (0.1s at 30fps, 0.03s at 100fps)
                    if original_ball is not None and frames_since_seen == 3:
                        # Ball has been gone for 3 frames - verify it's a real shot
                        # More lenient criteria: if ball was visible at all in recent frames,
                        # and stays gone for 3 frames, it's likely a shot (not club positioning)
                        if len(detection_history) >= 7:
                            # Look at frames -7 to -4 (before disappearance)
                            # Convert deque to list for slicing (deques don't support slice notation)
                            history_list = list(detection_history)
                            pre_disappearance = history_list[-7:-3]
                            consecutive_before = sum(pre_disappearance)

                            # If ball was visible in 2+ of last 4 frames before disappearing
                            # AND still gone after 3 frames = LIKELY a shot
                            # (More lenient to handle club head obscuration during swing)
                            if consecutive_before >= 2:
                                # CRITICAL CHECK: Is the camera covered (black screen)?
                                # When ball is HIT, you still see the scene (grass, background)
                                # When hand covers camera, screen is BLACK

                                # Use fast C++ brightness check if available
                                if FAST_DETECTION_AVAILABLE:
                                    mean_scene_brightness = fast_detection.get_scene_brightness(frame)
                                else:
                                    gray_check = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
                                    mean_scene_brightness = np.mean(gray_check)

                                if mean_scene_brightness < 10:
                                    # Scene is COMPLETELY dark - camera is covered by hand/object
                                    # Very low threshold (10) because ball leaving naturally reduces brightness
                                    # Only reject if camera is truly covered (pitch black)
                                    print(f"⚠️ Camera appears to be covered (scene brightness: {int(mean_scene_brightness)}) - NOT a shot!")
                                    # Reset the lock since camera is blocked
                                    original_ball = None
                                    stable_frames = 0
                                    prev_ball = None
                                    last_seen_ball = None
                                    frames_since_lock = 0
                                    radius_history.clear()  # Reset radius smoothing
                                    self.statusChanged.emit("No Ball Detected", "red")
                                else:
                                    # Scene is still visible - this is a REAL SHOT
                                    print(f"🏌️ IMPACT CONFIRMED! Ball was visible {consecutive_before}/4 frames, gone for 3 frames - real shot!")
                                    print(f"   Scene brightness: {int(mean_scene_brightness)} - camera not covered, valid shot")
                                    self.statusChanged.emit("Capturing...", "red")

                                    # Capture frames: 5 BEFORE impact (from buffer) + 5 AFTER impact
                                    frames = list(frame_buffer)  # Get pre-impact frames from circular buffer
                                    print(f"   📸 Captured {len(frames)} pre-impact frames from buffer")

                                    # Capture post-impact frames
                                    frame_delay = 1.0 / frame_rate
                                    for i in range(5):
                                        capture_frame = self.picam2.capture_array()
                                        frames.append(capture_frame)
                                        time.sleep(frame_delay)

                                    print(f"   📸 Total: {len(frames)} frames captured (5 before + 5 after impact)")

                                    # Save frames
                                    for i, save_frame in enumerate(frames):
                                        filename = f"shot_{next_shot:03d}_frame_{i:03d}.jpg"
                                        filepath = os.path.join(captures_folder, filename)
                                        cv2.imwrite(filepath, cv2.cvtColor(save_frame, cv2.COLOR_RGB2BGR))

                                    print(f"✅ Shot #{next_shot} saved!")
                                    self.shotCaptured.emit(next_shot)

                                    # Stop after capture
                                    self.picam2.stop()
                                    self.picam2 = None
                                    self.is_running = False
                                    return
                            else:
                                print(f"⚠️ Ball gone but not enough pre-visibility ({consecutive_before}/4 frames) - ignoring")

                    # Ball has been gone too long - reset lock
                    if original_ball is not None and frames_since_seen > 60:
                        print(f"❌ Ball lost for {frames_since_seen} frames - resetting lock")
                        self.statusChanged.emit("No Ball Detected", "red")
                        original_ball = None
                        stable_frames = 0
                        prev_ball = None
                        last_seen_ball = None
                        frames_since_lock = 0
                        radius_history.clear()  # Reset radius smoothing
                    elif original_ball is not None and frames_since_seen <= 60:
                        # Ball is locked but temporarily not visible (club head, hand, etc.)
                        # Keep the "Ready" status - don't turn red
                        # Status remains green from when ball was locked
                        pass
                    elif original_ball is None:
                        # Ball not locked yet - brief tolerance for flickering
                        if frames_since_seen < 5 and last_seen_ball is not None:
                            self.statusChanged.emit("Detecting ball...", "yellow")
                        else:
                            self.statusChanged.emit("No Ball Detected", "red")
                            stable_frames = 0
                            prev_ball = None
                            last_seen_ball = None
                            radius_history.clear()  # Reset radius smoothing

                # === VISUALIZATION RENDERING ===
                # Draw ball tracking circle if detected
                if current_ball is not None:
                    x, y, r = int(current_ball[0]), int(current_ball[1]), int(current_ball[2])
                    # Green circle around detected ball
                    cv2.circle(vis_frame, (x, y), r, (0, 255, 0), 3)
                    # Center point
                    cv2.circle(vis_frame, (x, y), 3, (0, 255, 0), -1)
                    # Position text
                    cv2.putText(vis_frame, f"Ball: ({x}, {y}) r={r}", (x + r + 5, y),
                               cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

                # Draw FPS counter
                cv2.putText(vis_frame, f"FPS: {current_fps}", (10, 30),
                           cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 255), 2)

                # Draw status
                if original_ball is not None:
                    status_text = "LOCKED - Ready to Hit!"
                    status_color = (0, 255, 0)  # Green
                elif current_ball is not None:
                    status_text = f"Detecting... ({stable_frames}/5 frames)"
                    status_color = (0, 255, 255)  # Yellow
                else:
                    status_text = "No Ball Detected"
                    status_color = (0, 0, 255)  # Red

                cv2.putText(vis_frame, status_text, (10, 70),
                           cv2.FONT_HERSHEY_SIMPLEX, 1, status_color, 2)

                # Draw detection info
                if current_ball is not None:
                    info_y = 110
                    cv2.putText(vis_frame, f"Stable frames: {stable_frames}", (10, info_y),
                               cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)
                    cv2.putText(vis_frame, f"Frames since lock: {frames_since_lock}", (10, info_y + 25),
                               cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)

                # Save debug frame every ~1 second (based on frame rate)
                debug_frame_counter += 1
                if debug_frame_counter % max(frame_rate, 10) == 0:  # Every 1 second
                    debug_filename = "debug_detection_latest.jpg"
                    cv2.imwrite(debug_filename, cv2.cvtColor(vis_frame, cv2.COLOR_RGB2BGR))
                    # Print detection info every second
                    if current_ball is not None:
                        print(f"📊 FPS: {current_fps} | Ball: ({x},{y}) r={r} | Stable: {stable_frames}/5 | Status: {'LOCKED' if original_ball is not None else 'Detecting'}")
                    else:
                        print(f"📊 FPS: {current_fps} | Status: No Ball Detected")

                # Adaptive sleep to maintain target frame rate
                loop_elapsed_time = time.time() - loop_start_time
                remaining_time = target_frame_time - loop_elapsed_time

                # Sleep only if we have time remaining (with 0.5ms minimum to prevent CPU spinning)
                if remaining_time > 0.0005:
                    time.sleep(remaining_time)

                # Optional: Log if we're running behind (useful for debugging)
                if remaining_time < 0:
                    # Running behind target frame rate - detection is taking too long
                    # This is normal during initial detection or scene changes
                    pass

        except Exception as e:
            print(f"❌ Capture error: {e}")
            self.errorOccurred.emit(str(e))
        finally:
            try:
                if self.picam2 is not None:
                    self.picam2.stop()
                    self.picam2 = None
                    print("📷 Camera released in cleanup")
            except Exception as e:
                print(f"⚠️ Error releasing camera: {e}")

            self.is_running = False
            self._stopping = False
            self.capture_thread = None
            print("🔓 Capture thread fully stopped and cleaned up")
            print("📺 Debug frames saved to: debug_detection_latest.jpg")

# ============================================
# Sound Manager Class
# ============================================
class SoundManager(QObject):
    """Manages sound effects for the app"""
    
    def __init__(self):
        super().__init__()
        self.click_sound = QSoundEffect()
        self.success_sound = QSoundEffect()
        
        # Set up click sound
        click_path = os.path.join(os.path.dirname(__file__), "sounds", "click.wav")
        if os.path.exists(click_path):
            self.click_sound.setSource(QUrl.fromLocalFile(click_path))
            self.click_sound.setVolume(0.5)
        else:
            print(f"⚠️ Click sound not found at: {click_path}")
        
        # Set up success sound
        success_path = os.path.join(os.path.dirname(__file__), "sounds", "success.wav")
        if os.path.exists(success_path):
            self.success_sound.setSource(QUrl.fromLocalFile(success_path))
            self.success_sound.setVolume(0.7)
        else:
            print(f"⚠️ Success sound not found at: {success_path}")
    
    @Slot()
    def playClick(self):
        """Play button click sound"""
        if self.click_sound.isLoaded():
            self.click_sound.play()
        else:
            print("🔇 Click sound not loaded")
    
    @Slot()
    def playSuccess(self):
        """Play success sound (for shot simulation)"""
        if self.success_sound.isLoaded():
            self.success_sound.play()
        else:
            print("🔇 Success sound not loaded")

# ============================================
# Message Handler
# ============================================
def handler(msg_type, context, message):
    print("QML:", message)

qInstallMessageHandler(handler)

# ============================================
# Main Application
# ============================================
if __name__ == "__main__":
    app = QGuiApplication(sys.argv)

    # Create managers
    settings_manager = SettingsManager()
    camera_manager = CameraManager(settings_manager)
    capture_manager = CaptureManager(settings_manager, camera_manager)
    sound_manager = SoundManager()
    profile_manager = ProfileManager()
    history_manager = HistoryManager()

    # Create QML engine
    engine = QQmlApplicationEngine()

    # Expose managers to QML
    engine.rootContext().setContextProperty("cameraManager", camera_manager)
    engine.rootContext().setContextProperty("captureManager", capture_manager)
    engine.rootContext().setContextProperty("soundManager", sound_manager)
    engine.rootContext().setContextProperty("profileManager", profile_manager)
    engine.rootContext().setContextProperty("historyManager", history_manager)
    engine.rootContext().setContextProperty("settingsManager", settings_manager)
    
    # Load main QML
    engine.load('main.qml')
    
    if not engine.rootObjects():
        print("❌ QML failed to load. See messages above.")
        sys.exit(-1)

    sys.exit(app.exec())