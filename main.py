import sys
import os
import subprocess
import threading
import time
import numpy as np

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

    @Slot()
    def startCapture(self):
        """Start the capture process in a background thread"""
        if not CAMERA_AVAILABLE:
            self.errorOccurred.emit("Camera not available on this system")
            return

        if self.is_running:
            print("⚠️ Capture already running")
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
        darker objects like shoes, clubs, etc.
        """
        # Convert to grayscale for initial processing
        gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)

        # Create a mask for bright/white regions (golf balls are typically white or yellow)
        # This filters out dark objects like shoes, clubs, shadows
        # Golf ball should be bright - threshold at 120+ on 0-255 scale
        _, white_mask = cv2.threshold(gray, 120, 255, cv2.THRESH_BINARY)

        # Apply mask to grayscale image
        masked_gray = cv2.bitwise_and(gray, gray, mask=white_mask)

        # Blur for better circle detection
        blurred = cv2.GaussianBlur(masked_gray, (9, 9), 2)

        # Detect circles in the bright-region-only image
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

            # Validate detected circles by checking brightness
            # Golf ball should have consistently bright pixels in its area
            for circle in circles[0]:
                x, y, r = int(circle[0]), int(circle[1]), int(circle[2])

                # Extract region around detected circle
                # Make sure we don't go out of bounds
                y1, y2 = max(0, y - r), min(gray.shape[0], y + r)
                x1, x2 = max(0, x - r), min(gray.shape[1], x + r)

                ball_region = gray[y1:y2, x1:x2]

                # Check average brightness of the region
                # Golf ball should have mean brightness > 100 (on 0-255 scale)
                if ball_region.size > 0:
                    mean_brightness = np.mean(ball_region)

                    if mean_brightness > 100:  # Bright enough to be a golf ball
                        return circle  # x, y, radius
                    else:
                        print(f"   Rejected circle at ({x},{y}) - too dark (brightness: {int(mean_brightness)})")

        return None

    def _ball_has_moved(self, prev_ball, curr_ball, threshold=40):
        """Check if ball has moved significantly"""
        if prev_ball is None or curr_ball is None:
            return False

        dx = int(curr_ball[0]) - int(prev_ball[0])
        dy = int(curr_ball[1]) - int(prev_ball[1])
        distance = np.sqrt(dx**2 + dy**2)

        return distance > threshold

    def _is_same_ball(self, ball1, ball2, radius_tolerance=0.3):
        """Check if two detections are the same ball based on radius"""
        if ball1 is None or ball2 is None:
            return False

        r1 = int(ball1[2])
        r2 = int(ball2[2])

        # Radius should be within 30% of original
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

            # Initialize camera
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

            self.statusChanged.emit("Detecting ball...", "yellow")

            original_ball = None
            stable_frames = 0
            last_seen_ball = None
            frames_since_seen = 0
            prev_ball = None

            while self.is_running:
                frame = self.picam2.capture_array()
                current_ball = self._detect_ball(frame)

                if current_ball is not None:
                    x, y, r = int(current_ball[0]), int(current_ball[1]), int(current_ball[2])

                    # Validate this is the same ball (not a person/other object)
                    if last_seen_ball is not None and not self._is_same_ball(last_seen_ball, current_ball):
                        print(f"⚠️ Detected circle with different radius ({r}px vs {int(last_seen_ball[2])}px) - ignoring")
                        # Skip this detection, likely a different object
                        continue

                    last_seen_ball = current_ball
                    frames_since_seen = 0

                    # Check if ball has been stable
                    if original_ball is None:
                        # Check radius consistency with previous frame
                        if prev_ball is not None:
                            if not self._is_same_ball(prev_ball, current_ball):
                                # Radius changed too much, probably different object
                                print(f"⚠️ Radius inconsistency during lock - resetting")
                                stable_frames = 0
                                prev_ball = None
                                continue
                            elif self._ball_has_moved(prev_ball, current_ball, threshold=10):
                                # Ball moved too much, reset stability counter
                                stable_frames = 0
                            else:
                                stable_frames += 1
                        else:
                            stable_frames += 1

                        prev_ball = current_ball

                        if stable_frames >= 15:  # Reduced from 20 for faster lock
                            original_ball = current_ball
                            # Calculate hit box size for display
                            ball_radius_px = int(current_ball[2])
                            pixels_per_inch = ball_radius_px / 0.84
                            hitbox_radius_px = 3.0 * pixels_per_inch  # 3 inches radius (6" diameter)
                            self.statusChanged.emit("Ready - Hit Ball!", "green")
                            print(f"🎯 Ball locked at ({x}, {y}) with radius {r}px")
                            print(f"   Hit box: 6x6 inches (±{int(hitbox_radius_px)}px from center)")
                            print(f"   Ball can move freely within hit box without triggering")
                            stable_frames = 0
                            prev_ball = None

                    # Ball is locked, check if it EXITED the hit box zone
                    elif self._is_same_ball(original_ball, current_ball) and self._ball_exited_hitbox(original_ball, current_ball):
                        # Ball exited hit box - verify it's continuing to move (real shot vs momentary exit)
                        # Require ball to be VISIBLE and STILL MOVING AWAY in next frame
                        dx_initial = int(current_ball[0]) - int(original_ball[0])
                        dy_initial = int(current_ball[1]) - int(original_ball[1])
                        dist_initial = np.sqrt(dx_initial**2 + dy_initial**2)

                        time.sleep(0.016)  # 1 frame at 60fps
                        verify_frame = self.picam2.capture_array()
                        verify_ball = self._detect_ball(verify_frame)

                        # Verify ball is continuing to move away from original position
                        is_fast_shot = False
                        if verify_ball is None:
                            # Ball disappeared - likely blocked by club/hand, NOT a shot
                            print(f"⚠️ Ball disappeared (probably blocked) - not triggering")
                            original_ball = last_seen_ball
                            is_fast_shot = False
                        elif not self._is_same_ball(current_ball, verify_ball):
                            # Different object detected - false alarm
                            print(f"⚠️ Detected different object (radius changed) - ignoring motion")
                            original_ball = last_seen_ball
                            is_fast_shot = False
                        else:
                            # Check if ball is moving FURTHER away from original position
                            dx_verify = int(verify_ball[0]) - int(original_ball[0])
                            dy_verify = int(verify_ball[1]) - int(original_ball[1])
                            dist_verify = np.sqrt(dx_verify**2 + dy_verify**2)

                            if dist_verify > dist_initial:
                                # Ball is continuing to move away = real shot!
                                print(f"🏌️ Ball exited hit box and continuing away ({int(dist_initial)}px → {int(dist_verify)}px)")
                                is_fast_shot = True
                            else:
                                # Ball came back or stopped - not a shot
                                print(f"⚠️ Ball exited hit box but came back - ignoring")
                                original_ball = last_seen_ball
                                is_fast_shot = False

                        if is_fast_shot:
                            self.statusChanged.emit("Capturing...", "red")
                            print(f"🚀 Fast motion detected - Shot #{next_shot}")

                            # Capture frames
                            frames = []
                            frame_delay = 1.0 / frame_rate
                            for i in range(10):
                                capture_frame = self.picam2.capture_array()
                                frames.append(capture_frame)
                                time.sleep(frame_delay)

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

                    # Ball is within hit box - allow free movement without triggering
                    elif original_ball is not None and self._is_same_ball(original_ball, current_ball):
                        # Ball is same, but still within hit box - no action needed
                        # This allows ball to roll/move freely within the safe zone
                        pass

                    # Detected a ball but radius doesn't match locked ball
                    elif original_ball is not None and not self._is_same_ball(original_ball, current_ball):
                        print(f"⚠️ Detected different circle (radius {r}px vs locked {int(original_ball[2])}px) - maintaining lock")
                        # Keep original lock, ignore this detection

                else:
                    # Ball not detected - could be obscured by club
                    frames_since_seen += 1

                    # If ball is locked and obscured, this might be IMPACT
                    # Golf club obscures ball during downswing/impact for ~8-15 frames at 60fps
                    if original_ball is not None:
                        if frames_since_seen == 10:
                            print(f"⚠️ Ball obscured (club in position?) - maintaining lock")

                        # IMPACT DETECTION: Ball obscured for 8-12 frames = club impact!
                        # Trigger capture immediately - ball is being hit RIGHT NOW
                        if 8 <= frames_since_seen <= 12:
                            print(f"🏌️ IMPACT DETECTED! Ball obscured for {frames_since_seen} frames - triggering capture!")
                            self.statusChanged.emit("Capturing...", "red")

                            # Capture frames immediately (ball is in flight now)
                            frames = []
                            frame_delay = 1.0 / frame_rate
                            for i in range(10):
                                capture_frame = self.picam2.capture_array()
                                frames.append(capture_frame)
                                time.sleep(frame_delay)

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

                        # Still within tolerance - keep waiting
                        if frames_since_seen < 60:  # 1 second tolerance
                            # Keep green status
                            pass
                        else:
                            # Lost ball for too long (not a shot, just lost detection)
                            print(f"❌ Ball lost for {frames_since_seen} frames - resetting lock")
                            self.statusChanged.emit("No Ball Detected", "red")
                            original_ball = None
                            stable_frames = 0
                            prev_ball = None
                            last_seen_ball = None
                    else:
                        # Ball not locked yet - brief tolerance for flickering
                        if frames_since_seen < 5 and last_seen_ball is not None:
                            self.statusChanged.emit("Detecting ball...", "yellow")
                        else:
                            self.statusChanged.emit("No Ball Detected", "red")
                            stable_frames = 0
                            prev_ball = None
                            last_seen_ball = None

                time.sleep(0.03)

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