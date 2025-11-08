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
        """Stop the capture process"""
        self.is_running = False
        if self.capture_thread:
            self.capture_thread.join(timeout=2)
        print("🛑 Capture stopped")

    def _detect_ball(self, frame):
        """Detect golf ball in frame using circle detection"""
        gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
        blurred = cv2.GaussianBlur(gray, (9, 9), 2)

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
            return circles[0, 0]  # x, y, radius
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
            picam2 = Picamera2()
            config = picam2.create_video_configuration(
                main={"size": (640, 480), "format": "RGB888"},
                controls={
                    "FrameRate": frame_rate,
                    "ExposureTime": shutter_speed,
                    "AnalogueGain": gain
                }
            )
            picam2.configure(config)
            picam2.start()
            time.sleep(2)

            self.statusChanged.emit("Detecting ball...", "yellow")

            original_ball = None
            stable_frames = 0
            last_seen_ball = None
            frames_since_seen = 0
            prev_ball = None

            while self.is_running:
                frame = picam2.capture_array()
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
                            self.statusChanged.emit("Ready - Hit Ball!", "green")
                            print(f"🎯 Ball locked at ({x}, {y}) with radius {r}px")
                            stable_frames = 0
                            prev_ball = None

                    # Ball is locked, check for FAST motion (velocity-based)
                    elif self._is_same_ball(original_ball, current_ball) and self._ball_has_moved(original_ball, current_ball, threshold=50):
                        # Ball moved significantly - verify it's SUSTAINED fast movement
                        # Require ball to be VISIBLE and STILL MOVING in next frame
                        # (if it disappears, it's likely blocked, not hit)
                        time.sleep(0.016)  # 1 frame at 60fps
                        verify_frame = picam2.capture_array()
                        verify_ball = self._detect_ball(verify_frame)

                        # Verify we're still tracking the same ball AND it's still moving
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
                        elif self._ball_has_moved(current_ball, verify_ball, threshold=30):
                            # Same ball, STILL visible, moved another >30px = real shot!
                            is_fast_shot = True
                        else:
                            # Ball visible but not moving fast enough in frame 2
                            print(f"⚠️ Movement slowed down - not a shot")
                            original_ball = last_seen_ball
                            is_fast_shot = False

                        if is_fast_shot:
                            self.statusChanged.emit("Capturing...", "red")
                            print(f"🚀 Fast motion detected - Shot #{next_shot}")

                            # Capture frames
                            frames = []
                            frame_delay = 1.0 / frame_rate
                            for i in range(10):
                                capture_frame = picam2.capture_array()
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
                            picam2.stop()
                            self.is_running = False
                            return
                        else:
                            # False alarm - slow movement or different object, reset to locked state
                            if not is_fast_shot:
                                print("⚠️ Slow movement detected, ignoring")
                            original_ball = last_seen_ball

                    # Detected a ball but radius doesn't match locked ball
                    elif original_ball is not None and not self._is_same_ball(original_ball, current_ball):
                        print(f"⚠️ Detected different circle (radius {r}px vs locked {int(original_ball[2])}px) - maintaining lock")
                        # Keep original lock, ignore this detection

                else:
                    # Ball not detected
                    frames_since_seen += 1

                    # Tolerate brief detection losses (up to 5 frames)
                    if frames_since_seen < 5 and last_seen_ball is not None:
                        # Keep status as is, use last known position
                        if original_ball is None:
                            self.statusChanged.emit("Detecting ball...", "yellow")
                        # else keep green status
                    else:
                        # Lost ball for too long
                        self.statusChanged.emit("No Ball Detected", "red")
                        original_ball = None
                        stable_frames = 0
                        prev_ball = None

                time.sleep(0.03)

        except Exception as e:
            print(f"❌ Capture error: {e}")
            self.errorOccurred.emit(str(e))
        finally:
            try:
                picam2.stop()
            except:
                pass
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