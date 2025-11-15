import sys
import os
import subprocess
import threading
import time
import numpy as np
from collections import deque
from datetime import datetime

os.environ["QT_QUICK_CONTROLS_STYLE"] = "Material"

from PySide6.QtGui import QGuiApplication, QImage, QPixmap
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType, QQmlImageProviderBase
from PySide6.QtQuick import QQuickImageProvider
from PySide6.QtCore import qInstallMessageHandler, QObject, Signal, Slot, QUrl, QSize, QMutex, QMutexLocker
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

# Try to import PIL for GIF creation
try:
    from PIL import Image as PILImage
    GIF_AVAILABLE = True
except ImportError:
    GIF_AVAILABLE = False
    print("⚠️ PIL/Pillow not available - install with: pip install Pillow")

# Try to import fast C++ detection module (3-5x speedup)
try:
    import fast_detection
    FAST_DETECTION_AVAILABLE = True
    print("✅ Fast C++ detection loaded - using optimized ball detection")
except ImportError:
    FAST_DETECTION_AVAILABLE = False
    print("⚠️ Fast C++ detection not available - using Python fallback (build with: ./build_fast_detection.sh)")

# ============================================
# Frame Provider Class (for high-FPS Qt preview)
# ============================================
class FrameProvider(QQuickImageProvider):
    """Provides camera frames to QML Image components for smooth high-FPS preview"""

    def __init__(self):
        super().__init__(QQmlImageProviderBase.ImageType.Pixmap)
        self.pixmap = QPixmap(640, 480)
        self.pixmap.fill(0x000000)  # Black initial frame
        self.mutex = QMutex()

    def requestPixmap(self, id, size, requestedSize):
        """Called by QML Image to get the latest frame"""
        with QMutexLocker(self.mutex):
            return self.pixmap

    def updateFrame(self, frame):
        """Update the frame from numpy array (called from capture thread)"""
        try:
            # Make a copy of the frame to ensure data stays valid
            frame_copy = frame.copy()

            # Convert numpy array to QImage
            if len(frame_copy.shape) == 2:
                # Grayscale (H, W)
                height, width = frame_copy.shape
                bytes_per_line = width
                # Use tobytes() to ensure data is copied
                data = frame_copy.tobytes()
                qimage = QImage(data, width, height, bytes_per_line, QImage.Format.Format_Grayscale8).copy()
            elif len(frame_copy.shape) == 3:
                height, width, channels = frame_copy.shape
                if channels == 1:
                    # Grayscale (H, W, 1) - squeeze to 2D
                    bytes_per_line = width
                    data = frame_copy[:, :, 0].tobytes()
                    qimage = QImage(data, width, height, bytes_per_line, QImage.Format.Format_Grayscale8).copy()
                elif channels == 3:
                    # RGB (H, W, 3)
                    bytes_per_line = width * 3
                    data = frame_copy.tobytes()
                    qimage = QImage(data, width, height, bytes_per_line, QImage.Format.Format_RGB888).copy()
                elif channels == 4:
                    # RGBA/XBGR (H, W, 4)
                    bytes_per_line = width * 4
                    data = frame_copy.tobytes()
                    qimage = QImage(data, width, height, bytes_per_line, QImage.Format.Format_RGBA8888).copy()
                else:
                    print(f"❌ Unsupported channel count: {channels}")
                    return
            else:
                print(f"❌ Unsupported frame shape: {frame_copy.shape}")
                return

            # Convert to pixmap and store (thread-safe)
            with QMutexLocker(self.mutex):
                self.pixmap = QPixmap.fromImage(qimage)
        except Exception as e:
            print(f"❌ Frame update error: {e}")

# ============================================
# Camera Manager Class
# ============================================
class CameraManager(QObject):
    """Manages Raspberry Pi camera using rpicam-vid"""

    snapshotSaved = Signal(str)  # Signal emitted when snapshot is saved (with filename)
    trainingModeProgress = Signal(int, int)  # Signal (current_count, total_count) for training progress
    recordingSaved = Signal(str)  # Signal emitted when recording is saved (with filename)
    testResults = Signal(float, float, str)  # Signal (actual_fps, brightness, recommendation)
    frameReady = Signal()  # Signal emitted when new preview frame is available

    def __init__(self, settings_manager=None, frame_provider=None):
        super().__init__()
        self.camera_process = None
        self.settings_manager = settings_manager
        self.training_thread = None
        self.training_active = False
        self.recording_process = None
        self.is_recording = False
        self.current_recording_path = None
        self.frame_provider = frame_provider

        # Preview state (direct Qt rendering)
        self.preview_active = False
        self.preview_thread = None
        self.preview_picam2 = None
        self._preview_stopping = False

    @Slot()
    def startPreview(self):
        """Start high-FPS camera preview with direct Qt rendering (no rpicam-vid lag)"""
        if not CAMERA_AVAILABLE:
            print("❌ Camera not available")
            return

        if self.preview_active:
            print("⚠️ Preview already running")
            return

        if self._preview_stopping:
            print("⚠️ Previous preview still stopping - wait a moment")
            return

        self.preview_active = True
        self.preview_thread = threading.Thread(target=self._preview_loop, daemon=True)
        self.preview_thread.start()
        print("🎥 High-FPS preview started (direct Qt rendering)")

    @Slot()
    def stopPreview(self):
        """Stop the high-FPS preview"""
        if not self.preview_active:
            print("⚠️ Preview not running")
            return

        print("🛑 Stopping preview...")
        self._preview_stopping = True
        self.preview_active = False

        # Stop camera
        if self.preview_picam2 is not None:
            try:
                self.preview_picam2.stop()
                self.preview_picam2.close()
                print("   Camera stopped and closed")
            except Exception as e:
                print(f"   Warning stopping camera: {e}")
            self.preview_picam2 = None

        # Wait for thread
        if self.preview_thread is not None:
            print("   Waiting for preview thread...")
            self.preview_thread.join(timeout=2.0)
            if self.preview_thread.is_alive():
                print("   ⚠️ Thread still running (will exit naturally)")
            else:
                print("   ✅ Thread finished")
            self.preview_thread = None

        self._preview_stopping = False
        print("✅ Preview stopped")

    def _preview_loop(self):
        """Background thread for high-FPS preview rendering"""
        try:
            # Load camera settings - optimized for smooth preview
            # Use 60 FPS for preview (good balance of smoothness vs CPU usage)
            # Can go up to 100 FPS if needed
            shutter_speed = 8500   # 8.5ms for indoor
            gain = 5.0             # Good indoor gain
            frame_rate = 60        # Smooth preview (can increase to 100)

            if self.settings_manager:
                shutter_speed = int(self.settings_manager.getNumber("cameraShutterSpeed") or 8500)
                gain = float(self.settings_manager.getNumber("cameraGain") or 5.0)
                # Use slightly lower FPS for preview to reduce CPU load
                # Ball capture still uses 100 FPS for detection
                frame_rate = 60

            print(f"📷 Preview settings: Shutter={shutter_speed}µs, Gain={gain}x, FPS={frame_rate}")

            # Initialize camera
            self.preview_picam2 = Picamera2()
            config = self.preview_picam2.create_video_configuration(
                main={"size": (640, 480)},
                controls={
                    "FrameRate": frame_rate,
                    "ExposureTime": shutter_speed,
                    "AnalogueGain": gain
                }
            )
            self.preview_picam2.configure(config)
            self.preview_picam2.start()

            # Warmup
            print("   Warming up camera...")
            time.sleep(0.5)
            for i in range(5):
                _ = self.preview_picam2.capture_array()
                time.sleep(0.02)
            print("   ✅ Camera ready")

            # Calculate target frame time
            target_frame_time = 1.0 / frame_rate

            # FPS counter
            fps_counter = 0
            fps_start = time.time()
            current_fps = 0

            # Main preview loop
            while self.preview_active:
                loop_start = time.time()

                # Capture frame
                frame = self.preview_picam2.capture_array()

                # Update frame provider (thread-safe)
                if self.frame_provider is not None:
                    self.frame_provider.updateFrame(frame)
                    self.frameReady.emit()  # Signal QML to refresh

                # FPS tracking
                fps_counter += 1
                if time.time() - fps_start >= 1.0:
                    current_fps = fps_counter
                    print(f"📊 Preview FPS: {current_fps}")
                    fps_counter = 0
                    fps_start = time.time()

                # Frame rate control
                loop_elapsed = time.time() - loop_start
                remaining = target_frame_time - loop_elapsed
                if remaining > 0.001:
                    time.sleep(remaining)

            print("🔓 Preview loop finished")

        except Exception as e:
            print(f"❌ Preview error: {e}")
        finally:
            if self.preview_picam2 is not None:
                try:
                    self.preview_picam2.stop()
                    self.preview_picam2.close()
                except:
                    pass
                self.preview_picam2 = None

            self.preview_active = False
            self._preview_stopping = False
            print("✅ Preview cleanup complete")

    @Slot()
    def startCamera(self):
        """Start the Raspberry Pi camera preview embedded in the UI (OLD - uses rpicam-vid)"""
        if self.camera_process is not None:
            print("⚠️ Camera is already running")
            return

        # Load camera settings from SettingsManager
        # OPTIMIZED: 45 FPS matches Pi ISP hardware limit (prevents lag)
        shutter_speed = 10000  # 10ms for indoor lighting
        gain = 6.0             # Higher gain for indoor
        ev_compensation = 0.0
        frame_rate = 45        # Match Pi ISP hardware limit

        if self.settings_manager:
            shutter_speed = int(self.settings_manager.getNumber("cameraShutterSpeed") or 10000)
            gain = float(self.settings_manager.getNumber("cameraGain") or 6.0)
            ev_compensation = float(self.settings_manager.getNumber("cameraEV") or 0.0)
            frame_rate = int(self.settings_manager.getNumber("cameraFrameRate") or 45)
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

    @Slot()
    def takeSnapshot(self):
        """Capture a single frame and save to BallSnapshotTest folder"""
        import os
        import time
        from datetime import datetime

        # Create BallSnapshotTest folder if it doesn't exist
        snapshot_folder = "BallSnapshotTest"
        os.makedirs(snapshot_folder, exist_ok=True)

        # Generate filename with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"snapshot_{timestamp}.jpg"
        filepath = os.path.join(snapshot_folder, filename)

        print(f"📸 Taking snapshot...")

        # Remember if preview was running
        preview_was_running = self.camera_process is not None

        try:
            if not CAMERA_AVAILABLE:
                print("❌ Camera not available - cannot take snapshot")
                return

            # Load camera settings - optimized for Pi ISP limit + indoor
            shutter_speed = 10000  # 10ms for indoor
            gain = 6.0             # Higher gain for brightness
            frame_rate = 45        # Match hardware limit
            ev_compensation = 0.0

            if self.settings_manager:
                shutter_speed = int(self.settings_manager.getNumber("cameraShutterSpeed") or 10000)
                gain = float(self.settings_manager.getNumber("cameraGain") or 6.0)
                frame_rate = int(self.settings_manager.getNumber("cameraFrameRate") or 45)
                ev_compensation = float(self.settings_manager.getNumber("cameraEV") or 0.0)

            # Stop camera preview if running (to release camera)
            if preview_was_running:
                print("   Stopping preview to release camera...")
                self.stopCamera()
                time.sleep(1)  # Give camera time to fully release

            # Use Picamera2 to capture a single frame
            picam2 = Picamera2()
            config = picam2.create_still_configuration(
                main={"size": (640, 480)},
                controls={
                    "FrameRate": frame_rate,
                    "ExposureTime": shutter_speed,
                    "AnalogueGain": gain
                }
            )
            picam2.configure(config)
            picam2.start()
            time.sleep(0.5)  # Let camera stabilize

            # Capture and save
            picam2.capture_file(filepath)
            picam2.stop()
            picam2.close()

            print(f"✅ Snapshot saved: {filepath}")
            self.snapshotSaved.emit(filename)

        except Exception as e:
            print(f"❌ Failed to take snapshot: {e}")

        finally:
            # Restart preview if it was running before
            if preview_was_running:
                print("   Restarting preview...")
                time.sleep(0.5)  # Brief pause before restarting
                self.startCamera()

    @Slot(int)
    def startTrainingMode(self, num_frames=100):
        """
        Rapid capture mode for collecting ML training data
        Captures num_frames images at max speed (1-2 per second)
        """
        if self.training_active:
            print("⚠️ Training mode already running")
            return

        if not CAMERA_AVAILABLE:
            print("❌ Camera not available")
            return

        self.training_active = True
        self.training_thread = threading.Thread(
            target=self._training_capture_loop,
            args=(num_frames,),
            daemon=True
        )
        self.training_thread.start()
        print(f"🎓 Training mode started - will capture {num_frames} frames")

    def _training_capture_loop(self, num_frames):
        """Background thread for rapid training data capture"""
        import os
        from datetime import datetime

        # Create training data folder with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        training_folder = f"training_data/session_{timestamp}"
        os.makedirs(training_folder, exist_ok=True)

        # Create metadata file
        metadata_path = os.path.join(training_folder, "metadata.txt")

        # Remember if preview was running
        preview_was_running = self.camera_process is not None

        try:
            # Load camera settings - optimized for Pi ISP limit + indoor
            shutter_speed = 10000  # 10ms for indoor
            gain = 6.0             # Higher gain for brightness
            frame_rate = 45        # Match hardware limit

            if self.settings_manager:
                shutter_speed = int(self.settings_manager.getNumber("cameraShutterSpeed") or 10000)
                gain = float(self.settings_manager.getNumber("cameraGain") or 6.0)
                frame_rate = int(self.settings_manager.getNumber("cameraFrameRate") or 45)

            # Write metadata
            with open(metadata_path, 'w') as f:
                f.write(f"Training Session: {timestamp}\n")
                f.write(f"Camera Settings:\n")
                f.write(f"  Shutter: {shutter_speed}µs\n")
                f.write(f"  Gain: {gain}x\n")
                f.write(f"  Frame Rate: {frame_rate} FPS\n")
                f.write(f"  Target Frames: {num_frames}\n\n")
                f.write(f"Instructions for labeling:\n")
                f.write(f"1. Use Roboflow or LabelImg to label images\n")
                f.write(f"2. Classes: ball_stationary, ball_moving, club_stationary, club_swinging\n")
                f.write(f"3. Export in YOLO format for training\n\n")

            # Stop preview if running
            if preview_was_running:
                self.stopCamera()
                time.sleep(1)

            # Initialize camera
            picam2 = Picamera2()
            config = picam2.create_still_configuration(
                main={"size": (640, 480)},
                controls={
                    "FrameRate": frame_rate,
                    "ExposureTime": shutter_speed,
                    "AnalogueGain": gain
                }
            )
            picam2.configure(config)
            picam2.start()
            time.sleep(0.5)

            print(f"📸 Capturing {num_frames} training frames...")

            # Capture frames
            for i in range(num_frames):
                if not self.training_active:
                    print("⚠️ Training mode cancelled")
                    break

                filename = f"frame_{i:04d}.jpg"
                filepath = os.path.join(training_folder, filename)

                picam2.capture_file(filepath)

                # Emit progress
                self.trainingModeProgress.emit(i + 1, num_frames)

                # Log every 10 frames
                if (i + 1) % 10 == 0:
                    print(f"   Captured {i + 1}/{num_frames} frames...")

                # Brief delay between captures (captures ~2 per second)
                time.sleep(0.5)

            picam2.stop()
            picam2.close()

            print(f"✅ Training data captured: {training_folder}")
            print(f"   Next steps:")
            print(f"   1. Label images in Roboflow (https://roboflow.com)")
            print(f"   2. Export in YOLO format")
            print(f"   3. Train YOLOv8 model on Google Colab")

        except Exception as e:
            print(f"❌ Training capture error: {e}")

        finally:
            # Restart preview if it was running
            if preview_was_running:
                time.sleep(0.5)
                self.startCamera()

            self.training_active = False
            self.training_thread = None
            self.trainingModeProgress.emit(num_frames, num_frames)  # Signal completion

    @Slot()
    def stopTrainingMode(self):
        """Stop training mode capture"""
        if self.training_active:
            print("🛑 Stopping training mode...")
            self.training_active = False

    @Slot()
    def startRecording(self):
        """Start recording video to file"""
        if self.is_recording:
            print("⚠️ Already recording")
            return

        # Create Videos folder if it doesn't exist
        videos_folder = "Videos"
        os.makedirs(videos_folder, exist_ok=True)

        # Generate filename with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"video_{timestamp}.h264"
        filepath = os.path.join(videos_folder, filename)
        self.current_recording_path = filepath

        # Load camera settings - optimized for Pi ISP limit + indoor
        shutter_speed = 10000  # 10ms for indoor
        gain = 6.0             # Higher gain for brightness
        frame_rate = 45        # Match hardware limit

        if self.settings_manager:
            shutter_speed = int(self.settings_manager.getNumber("cameraShutterSpeed") or 10000)
            gain = float(self.settings_manager.getNumber("cameraGain") or 6.0)
            frame_rate = int(self.settings_manager.getNumber("cameraFrameRate") or 45)

        try:
            print(f"🎬 Starting video recording: {filename}")

            # Stop camera preview if running
            if self.camera_process is not None:
                self.stopCamera()
                time.sleep(0.5)

            # Start recording with rpicam-vid
            cmd = [
                'rpicam-vid',
                '--timeout', '0',  # Run indefinitely until stopped
                '--width', '640',
                '--height', '480',
                '--framerate', str(frame_rate),
                '--shutter', str(shutter_speed),
                '--gain', str(gain),
                '--output', filepath,
                '--codec', 'h264',
                '--preview', '22,82,756,254'  # Show preview while recording
            ]

            self.recording_process = subprocess.Popen(cmd)
            self.is_recording = True
            print(f"✅ Recording started: {filepath}")

        except Exception as e:
            print(f"❌ Failed to start recording: {e}")
            self.is_recording = False
            self.current_recording_path = None

    @Slot()
    def stopRecording(self):
        """Stop recording and save video"""
        if not self.is_recording or self.recording_process is None:
            print("⚠️ Not currently recording")
            return

        try:
            print("🛑 Stopping recording...")
            self.recording_process.terminate()
            self.recording_process.wait(timeout=2)
            self.recording_process = None
            self.is_recording = False

            if self.current_recording_path and os.path.exists(self.current_recording_path):
                # Get file size for confirmation
                file_size = os.path.getsize(self.current_recording_path) / (1024 * 1024)  # MB
                print(f"✅ Recording saved: {self.current_recording_path} ({file_size:.1f} MB)")
                self.recordingSaved.emit(os.path.basename(self.current_recording_path))

            self.current_recording_path = None

        except Exception as e:
            print(f"❌ Error stopping recording: {e}")
            self.is_recording = False
            self.recording_process = None
            self.current_recording_path = None

    @Slot(int, int, float)
    def testCameraSettings(self, fps, shutter, gain):
        """Test camera performance with given settings"""
        if not CAMERA_AVAILABLE:
            self.testResults.emit(0, 0, "Camera not available on this system")
            return

        def run_test():
            try:
                print(f"🧪 Testing camera: {fps} FPS, {shutter}µs shutter, {gain}x gain")

                from picamera2 import Picamera2
                picam2 = Picamera2()

                config = picam2.create_video_configuration(
                    main={"size": (640, 480)},
                    controls={
                        "FrameRate": fps,
                        "ExposureTime": shutter,
                        "AnalogueGain": gain
                    }
                )
                picam2.configure(config)
                picam2.start()
                time.sleep(1)  # Warmup

                # Measure actual FPS over 5 seconds
                frame_times = []
                brightness_values = []
                start_time = time.time()
                last_time = start_time

                while time.time() - start_time < 5.0:
                    frame = picam2.capture_array()
                    current_time = time.time()

                    # Record frame timing
                    frame_times.append(current_time - last_time)
                    last_time = current_time

                    # Measure brightness
                    if len(frame.shape) == 3:
                        if frame.shape[2] == 1:
                            gray = frame[:, :, 0]
                        elif frame.shape[2] == 4:
                            gray = np.mean(frame[:, :, :3], axis=2)
                        else:
                            gray = np.mean(frame, axis=2)
                    else:
                        gray = frame

                    brightness_values.append(np.mean(gray))

                picam2.stop()
                picam2.close()

                # Calculate results
                actual_fps = len(frame_times) / 5.0
                avg_brightness = np.mean(brightness_values) / 255.0 * 100  # As percentage

                # Generate recommendation
                recommendation = ""

                # FPS Analysis
                if actual_fps >= 42:
                    recommendation += f"✓ Good FPS: {actual_fps:.0f} FPS\n"
                    recommendation += "NOTE: ~45 FPS is the practical maximum\n"
                    recommendation += "with this resolution due to Pi ISP limits.\n"
                else:
                    recommendation += f"⚠️ Low FPS: {actual_fps:.0f} FPS\n"
                    recommendation += "• System struggling - reduce load\n"

                # Brightness Analysis
                if avg_brightness < 20:
                    recommendation += "\n⚠️ Image too dark\n"
                    recommendation += "• Increase gain or shutter speed\n"
                    recommendation += "• Add more lighting\n"
                elif avg_brightness > 80:
                    recommendation += "\n⚠️ Image too bright\n"
                    recommendation += "• Decrease gain or shutter speed\n"
                else:
                    recommendation += f"\n✓ Good brightness: {avg_brightness:.0f}%\n"

                # Specific recommendations
                if avg_brightness < 30:
                    recommendation += "\n💡 For indoor: Try Gain 7.0x, Shutter 12ms"
                elif avg_brightness > 60:
                    recommendation += "\n💡 For bright conditions: Gain 3.0x, Shutter 5ms"

                # Reality check
                if actual_fps < 40:
                    recommendation += "\n\n⚠️ PERFORMANCE ISSUE:"
                    recommendation += "\n• Close other programs"
                    recommendation += "\n• Reduce system load"
                    recommendation += "\n• Check CPU temperature"

                print(f"✅ Test complete: {actual_fps:.1f} FPS, {avg_brightness:.1f}% brightness")
                print(f"   NOTE: RPi ISP limits 640x480 to ~45 FPS max")
                self.testResults.emit(actual_fps, avg_brightness, recommendation)

            except Exception as e:
                error_msg = f"Test failed: {str(e)}\n\nMake sure camera is not in use by another process."
                print(f"❌ {error_msg}")
                self.testResults.emit(0, 0, error_msg)

        # Run test in background thread
        test_thread = threading.Thread(target=run_test, daemon=True)
        test_thread.start()

    def __del__(self):
        """Cleanup on destruction"""
        self.stopCamera()
        if self.is_recording:
            self.stopRecording()

# ============================================
# Capture Manager Class
# ============================================
class CaptureManager(QObject):
    """Manages automatic ball capture with motion detection"""

    # Signals to update UI
    statusChanged = Signal(str, str)  # (status, color) - e.g. ("Ball Locked", "green")
    shotCaptured = Signal(int)  # shot_number
    errorOccurred = Signal(str)  # error_message
    replayReady = Signal(str)  # gif_filepath - emitted when replay GIF is ready to display

    def __init__(self, settings_manager=None, camera_manager=None):
        super().__init__()
        self.settings_manager = settings_manager
        self.camera_manager = camera_manager
        self.is_running = False
        self.capture_thread = None
        self.picam2 = None  # Store camera instance for cleanup
        self._stopping = False  # Flag to track if we're in the process of stopping

        # Edge velocity tracking state
        self.prev_gray = None  # Previous frame for optical flow
        self.ball_motion_history = deque(maxlen=10)  # Track ball velocity over time

    @Slot()
    def startCapture(self):
        """Start the capture process in a background thread"""
        if not CAMERA_AVAILABLE:
            self.errorOccurred.emit("Camera not available on this system")
            return

        if self.is_running:
            print("⚠️ Capture already running")
            return

        # Safety check - stopCapture should have cleared these
        if self._stopping or self.capture_thread is not None:
            print("⚠️ Previous capture cleanup incomplete - forcing reset")
            self._stopping = False
            self.capture_thread = None

        # Stop camera preview if it's running
        if self.camera_manager:
            print("🛑 Stopping camera preview before capture...")
            self.camera_manager.stopCamera()
            time.sleep(1)  # Give camera time to release

        self.is_running = True
        self.capture_thread = threading.Thread(target=self._capture_loop, daemon=True)
        self.capture_thread.start()
        print("🎥 Capture started", flush=True)

    @Slot()
    def stopCapture(self):
        """Stop the capture process and wait for cleanup"""
        print("🛑 Stopping capture...")
        self._stopping = True
        self.is_running = False

        # Stop camera if running
        if self.picam2 is not None:
            try:
                self.picam2.stop()
                self.picam2.close()
                print("   Camera stopped and closed")
            except Exception as e:
                print(f"   Warning stopping camera: {e}")
            self.picam2 = None

        # Wait for background thread to finish (with timeout)
        if self.capture_thread is not None:
            print("   Waiting for capture thread to finish...")
            self.capture_thread.join(timeout=2.0)  # Wait up to 2 seconds
            if self.capture_thread.is_alive():
                print("   ⚠️ Thread still running after timeout (will exit naturally)")
            else:
                print("   ✅ Thread finished")
            self.capture_thread = None

        # Clear stopping flag immediately after cleanup attempt
        self._stopping = False

        self.statusChanged.emit("Stopped", "gray")
        print("✅ Capture stopped")

    def _save_frame(self, filename, frame):
        """Save frame to file, handling all image formats (grayscale, RGB, RGBA)"""
        if len(frame.shape) == 3:
            if frame.shape[2] == 1:
                # Single channel (native Y) - squeeze to 2D
                cv2.imwrite(filename, frame[:, :, 0])
            elif frame.shape[2] == 4:
                # 4-channel (RGBA/BGRA) - convert to BGR
                cv2.imwrite(filename, cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR))
            elif frame.shape[2] == 3:
                # 3-channel (RGB) - convert to BGR
                cv2.imwrite(filename, cv2.cvtColor(frame, cv2.COLOR_RGB2BGR))
        else:
            # Already 2D grayscale
            cv2.imwrite(filename, frame)

    def _detect_ball(self, frame):
        """Detect golf ball in frame using color-filtered circle detection

        Focuses specifically on white/bright colored balls and ignores
        darker objects like shoes, clubs, metallic reflections, etc.

        Uses fast C++ implementation if available (3-5x speedup),
        otherwise falls back to Python version.
        """
        # Disable C++ detection for now - doesn't support 4-channel XBGR8888 format
        # Will re-enable after updating C++ module to handle 4-channel images
        # if FAST_DETECTION_AVAILABLE:
        #     result = fast_detection.detect_ball(frame)
        #     if result is not None:
        #         # C++ returns tuple (x, y, radius)
        #         return np.array([result[0], result[1], result[2]], dtype=np.uint16)
        #     return None

        # Python fallback - OPTIMIZED for OV9281 monochrome camera
        # Works on both color and grayscale cameras

        # Convert to grayscale (handles all formats: native Y, RGB, RGBA/XBGR)
        if len(frame.shape) == 3:
            if frame.shape[2] == 1:
                # Single channel (native Y format from OV9281) - squeeze to 2D
                gray = frame[:, :, 0]
            elif frame.shape[2] == 4:
                # 4-channel (XBGR8888) - convert to grayscale
                gray = cv2.cvtColor(frame, cv2.COLOR_BGRA2GRAY)
            elif frame.shape[2] == 3:
                # 3-channel RGB
                gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
            else:
                raise ValueError(f"Unexpected image format. Expected 1, 3, or 4 channels, got {frame.shape[2]}")
        elif len(frame.shape) == 2:
            gray = frame  # Already grayscale (H,W)
        else:
            raise ValueError(f"Unexpected image format. Expected (H,W), (H,W,1), (H,W,3), or (H,W,4), got shape {frame.shape}")

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

            # === SMART FILTERING - Reject dark false detections ===
            # In ultra-dark scenes, HoughCircles detects noise patterns as circles
            # Filter to find the BRIGHT ball on the mat, not dark noise circles
            best_circle = None
            best_score = 0

            for circle in filtered_circles:
                x, y, r = int(circle[0]), int(circle[1]), int(circle[2])

                # Validate bounds
                if x - r < 0 or x + r >= gray.shape[1]:
                    continue
                if y - r < 0 or y + r >= gray.shape[0]:
                    continue

                # Ball size filtering - golf ball should be 20-100px radius at typical distance
                if r < 20 or r > 100:
                    continue

                # Extract ball region for validation
                y1 = max(0, y - r)
                y2 = min(gray.shape[0], y + r)
                x1 = max(0, x - r)
                x2 = min(gray.shape[1], x + r)

                region = gray[y1:y2, x1:x2]

                if region.size == 0:
                    continue

                # === BRIGHTNESS FILTERING ===
                # Reject circles in pitch-black areas (noise patterns)
                region_brightness = region.mean()

                # Ball brightness with diagnostic settings (100 FPS, 1500µs, 8x): ~60-65
                # Using same threshold as diagnostic
                if region_brightness < 50:
                    continue

                # === CIRCULARITY CHECK ===
                # Ball has bright center from light reflection
                # Mat texture is grainy and uniform
                max_brightness = region.max()
                brightness_contrast = max_brightness - region_brightness

                # Diagnostic showed ball contrast ~190-200
                # Keep lenient threshold
                if brightness_contrast < 30:
                    continue

                # === SMART SCORING ===
                # Prioritize: peak brightness > circularity > position > size
                score = 0

                # Peak brightness score (ball has bright center from light reflection)
                score += max_brightness * 1.5

                # Brightness contrast score (smooth ball vs grainy mat)
                score += brightness_contrast * 2.0

                # Mean brightness score
                score += region_brightness * 1.0

                # Position score (ball is usually in bottom 2/3 of frame on hitting mat)
                # Higher Y = bottom of frame = higher score
                position_score = (y / gray.shape[0]) * 30
                score += position_score

                # Size score (ideal ball radius is 30-60px)
                if 30 <= r <= 60:
                    score += 30

                if score > best_score:
                    best_score = score
                    best_circle = circle

            # Return best circle immediately (skip refinement for ultra-fast detection)
            if best_circle is not None:
                return best_circle

        return None

    def _detect_ball_with_motion(self, frame, prev_frame=None):
        """
        EDGE VELOCITY TRACKING - Motion-based ball detection

        Uses optical flow to track movement patterns and distinguish:
        - Ball: Small, bright, stationary (then sudden motion on impact)
        - Club: Large, elongated, continuous motion during swing
        - Mat/Hands: Large, low contrast, irregular motion

        Returns: (ball_position, velocity, motion_state)
        - ball_position: (x, y, r) or None
        - velocity: pixels per frame
        - motion_state: "STATIONARY", "MOVING", or "IMPACT"
        """

        # Convert to grayscale (handle all formats)
        if len(frame.shape) == 3:
            if frame.shape[2] == 1:
                gray = frame[:, :, 0]  # Native Y format - squeeze to 2D
            elif frame.shape[2] == 4:
                gray = cv2.cvtColor(frame, cv2.COLOR_BGRA2GRAY)
            elif frame.shape[2] == 3:
                gray = cv2.cvtColor(frame, cv2.COLOR_RGB2GRAY)
        else:
            gray = frame  # Already grayscale

        # First pass: Detect potential balls using traditional method
        ball = self._detect_ball(frame)

        if ball is None or prev_frame is None:
            return (ball, 0, "UNKNOWN")

        # Convert previous frame to grayscale (handle all formats)
        if len(prev_frame.shape) == 3:
            if prev_frame.shape[2] == 1:
                prev_gray = prev_frame[:, :, 0]  # Native Y format - squeeze to 2D
            elif prev_frame.shape[2] == 4:
                prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_BGRA2GRAY)
            elif prev_frame.shape[2] == 3:
                prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_RGB2GRAY)
        else:
            prev_gray = prev_frame  # Already grayscale

        # === OPTICAL FLOW - Track motion between frames ===
        try:
            flow = cv2.calcOpticalFlowFarneback(
                prev_gray, gray, None,
                pyr_scale=0.5,   # Image pyramid scale
                levels=3,        # Number of pyramid layers
                winsize=15,      # Averaging window size
                iterations=3,    # Iterations at each pyramid level
                poly_n=5,        # Polynomial expansion size
                poly_sigma=1.2,  # Gaussian standard deviation
                flags=0
            )

            # Calculate magnitude and angle of flow vectors
            magnitude, angle = cv2.cartToPolar(flow[..., 0], flow[..., 1])

            # Extract ball region's motion
            x, y, r = int(ball[0]), int(ball[1]), int(ball[2])

            # Get motion in ball region (expand slightly for better coverage)
            y1 = max(0, y - r - 10)
            y2 = min(gray.shape[0], y + r + 10)
            x1 = max(0, x - r - 10)
            x2 = min(gray.shape[1], x + r + 10)

            ball_motion = magnitude[y1:y2, x1:x2]

            if ball_motion.size == 0:
                return (ball, 0, "UNKNOWN")

            # Calculate ball velocity (mean motion in ball region)
            ball_velocity = ball_motion.mean()

            # === MOTION STATE CLASSIFICATION ===
            # Stationary: Very low velocity (<2 px/frame)
            # Moving: Moderate velocity (2-20 px/frame)
            # Impact: High velocity (>20 px/frame)

            if ball_velocity < 2.0:
                motion_state = "STATIONARY"
            elif ball_velocity < 20.0:
                motion_state = "MOVING"
            else:
                motion_state = "IMPACT"

            return (ball, ball_velocity, motion_state)

        except Exception as e:
            # Optical flow failed - fall back to ball detection only
            return (ball, 0, "UNKNOWN")

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

    def _is_same_ball(self, ball1, ball2, radius_tolerance=0.6):
        """Check if two detections are the same ball based on position and radius

        Uses relaxed radius tolerance (60%) because HoughCircles can vary
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

    def _create_replay_gif(self, frames, output_path, fps=60, speed_multiplier=0.5):
        """Create animated GIF from captured frames (Snapchat-style replay)

        Args:
            frames: List of frames to convert to GIF
            output_path: Path to save the GIF
            fps: Original capture frame rate
            speed_multiplier: Playback speed (0.5 = half speed, 1.0 = normal, 2.0 = double speed)
        """
        if not GIF_AVAILABLE:
            print("⚠️ PIL not available - cannot create GIF")
            return None

        try:
            print(f"🎬 Creating replay GIF with {len(frames)} frames at {speed_multiplier}x speed...")

            # Convert frames to PIL Images
            pil_frames = []
            for frame in frames:
                # Convert frame to RGB for GIF (handle all formats)
                if len(frame.shape) == 2:
                    # Grayscale (H, W) - convert to RGB
                    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_GRAY2RGB)
                elif len(frame.shape) == 3:
                    if frame.shape[2] == 1:
                        # Grayscale (H, W, 1) - squeeze and convert to RGB
                        rgb_frame = cv2.cvtColor(frame[:, :, 0], cv2.COLOR_GRAY2RGB)
                    elif frame.shape[2] == 3:
                        # RGB - keep as-is
                        rgb_frame = frame
                    elif frame.shape[2] == 4:
                        # RGBA/XBGR - convert to RGB
                        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2RGB)
                else:
                    print(f"❌ Unsupported frame shape for GIF: {frame.shape}")
                    continue

                # Convert numpy array to PIL Image
                pil_frame = PILImage.fromarray(rgb_frame)
                pil_frames.append(pil_frame)

            if len(pil_frames) == 0:
                print("❌ No valid frames to create GIF")
                return None

            # Calculate frame duration in milliseconds
            # Slower speed = longer duration between frames
            base_duration = int(1000 / fps)  # ms per frame at original speed
            frame_duration = int(base_duration / speed_multiplier)  # Adjust for speed

            print(f"   Frame duration: {frame_duration}ms per frame (original: {base_duration}ms)")
            print(f"   Total frames: {len(pil_frames)} frames")

            # Create explicit duration list for EACH frame (absolute consistency)
            # This ensures Qt AnimatedImage doesn't optimize or vary timing
            durations = [frame_duration] * len(pil_frames)

            # Save as animated GIF with explicit per-frame durations
            pil_frames[0].save(
                output_path,
                save_all=True,
                append_images=pil_frames[1:],
                duration=durations,  # Explicit duration for each frame
                loop=0,  # Loop forever
                optimize=False,  # Don't optimize - preserve exact timing
                disposal=1  # Do not dispose (keep each frame)
            )

            print(f"✅ Replay GIF saved: {output_path}")
            return output_path

        except Exception as e:
            print(f"❌ Failed to create GIF: {e}")
            return None

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
            # Capture mode: Direct sensor access (no ISP display conversion)
            # Camera sensor can do 100 FPS - ISP limit only affects preview/recording
            # ULTRA-HIGH-SPEED MODE: 300+ FPS for impact capture
            shutter_speed = 500    # 0.5ms ultra-fast shutter for crisp motion freeze
            gain = 12.0            # Max gain to compensate for fast shutter
            frame_rate = 300       # 300 FPS for super high-speed capture (3.3ms between frames)

            print(f"📷 Using ultra-high-speed capture: Shutter={shutter_speed}µs, Gain={gain}x, FPS={frame_rate}", flush=True)

            # Force cleanup of any lingering camera instances
            try:
                from picamera2 import Picamera2
                # Close any existing global camera instances
                print("🧹 Cleaning up any existing camera instances...", flush=True)
                time.sleep(0.5)
            except Exception as e:
                print(f"   Camera cleanup check: {e}")

            # Initialize camera with retry logic (camera hardware may need time to release)
            camera_initialized = False
            for attempt in range(3):
                try:
                    if attempt > 0:
                        print(f"   Retry attempt {attempt + 1}/3...")
                        time.sleep(3)  # Wait longer between retries (was 2, now 3)

                    self.picam2 = Picamera2()
                    # Use native monochrome format - OV9281 outputs Y (grayscale)
                    # RGB888 conversion is broken/slow, causing black images and FPS drop
                    config = self.picam2.create_video_configuration(
                        main={"size": (640, 480)},  # Let camera use native Y format
                        controls={
                            "FrameRate": frame_rate,
                            "ExposureTime": shutter_speed,
                            "AnalogueGain": gain
                        }
                    )
                    self.picam2.configure(config)
                    self.picam2.start()

                    # Extended warmup - let camera stabilize and discard first frames
                    print("   Warming up camera (5 seconds)...", flush=True)
                    time.sleep(2)
                    # Capture and discard first 10 frames (often dark/unstable)
                    for i in range(10):
                        _ = self.picam2.capture_array()
                        time.sleep(0.05)
                    print("   Camera warmed up", flush=True)
                    camera_initialized = True
                    print("✅ Camera initialized successfully", flush=True)
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

            # === IMMEDIATE DEBUG - Save first frame to see what camera is capturing ===
            print("🔍 Capturing first frame for diagnosis...", flush=True)
            first_frame = self.picam2.capture_array()

            # Save first frame for diagnosis
            self._save_frame("capture_first_frame.jpg", first_frame)

            print(f"   Frame shape: {first_frame.shape}", flush=True)
            print(f"   Frame dtype: {first_frame.dtype}", flush=True)
            print(f"   Frame min/max: {first_frame.min()}/{first_frame.max()}", flush=True)

            # Test detection on first frame
            test_ball = self._detect_ball(first_frame)
            if test_ball is not None:
                print(f"   ✅ Ball detected on first frame: ({test_ball[0]}, {test_ball[1]}) r={test_ball[2]}", flush=True)
                self.statusChanged.emit("Ball found - Locking on...", "yellow")
            else:
                print(f"   ❌ No ball detected on first frame", flush=True)
                self.statusChanged.emit("No Ball Detected", "red")
                # Save debug images (handle all formats)
                if len(first_frame.shape) == 3:
                    if first_frame.shape[2] == 1:
                        gray = first_frame[:, :, 0]  # Native Y - squeeze to 2D
                    elif first_frame.shape[2] == 4:
                        gray = cv2.cvtColor(first_frame, cv2.COLOR_BGRA2GRAY)
                    elif first_frame.shape[2] == 3:
                        gray = cv2.cvtColor(first_frame, cv2.COLOR_RGB2GRAY)
                else:
                    gray = first_frame  # Already 2D grayscale
                cv2.imwrite("capture_gray.jpg", gray)
                clahe = cv2.createCLAHE(clipLimit=6.0, tileGridSize=(6, 6))
                enhanced = clahe.apply(gray)
                cv2.imwrite("capture_clahe.jpg", enhanced)
                print(f"   Gray stats: min={gray.min()}, max={gray.max()}, mean={gray.mean():.1f}", flush=True)
                print(f"   Debug images saved: capture_first_frame.jpg, capture_gray.jpg, capture_clahe.jpg", flush=True)

            original_ball = None
            stable_frames = 0
            last_seen_ball = None
            frames_since_seen = 0
            consecutive_frames_seen = 0  # Track consecutive frames ball is visible (for debouncing)
            prev_ball = None
            frames_since_lock = 0  # Track how long ball has been locked
            detection_history = deque(maxlen=10)  # Track last 10 frames: True=detected, False=not detected
            radius_history = deque(maxlen=5)  # Track last 5 radius values for smoothing
            frame_buffer = deque(maxlen=15)  # Circular buffer for 15 pre-impact frames

            # Calculate target frame time for adaptive sleep
            target_frame_time = 1.0 / frame_rate
            print(f"🎯 Target frame time: {target_frame_time*1000:.1f}ms ({frame_rate} FPS)")

            # FPS tracking for visualization
            fps_counter = 0
            fps_start_time = time.time()
            current_fps = 0

            # Debug frame saving (saves periodically for diagnostics)
            debug_frame_counter = 0
            print("📺 Edge Velocity Tracking enabled - Motion-based ball detection", flush=True)

            # Edge velocity tracking state
            prev_frame_for_motion = None

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

                # Create visualization frame (convert grayscale to BGR for colored annotations)
                if len(frame.shape) == 2:
                    # 2D grayscale - convert to BGR for colored circles/text
                    vis_frame = cv2.cvtColor(frame, cv2.COLOR_GRAY2BGR)
                elif len(frame.shape) == 3 and frame.shape[2] == 1:
                    # 1-channel 3D grayscale - convert to BGR
                    vis_frame = cv2.cvtColor(frame[:, :, 0], cv2.COLOR_GRAY2BGR)
                elif len(frame.shape) == 3 and frame.shape[2] == 3:
                    # RGB - convert to BGR for cv2
                    vis_frame = cv2.cvtColor(frame.copy(), cv2.COLOR_RGB2BGR)
                else:
                    # Already BGR or other format
                    vis_frame = frame.copy()

                # === EDGE VELOCITY TRACKING ===
                # Detect ball with motion analysis
                ball_result, velocity, motion_state = self._detect_ball_with_motion(frame, prev_frame_for_motion)
                current_ball = ball_result

                # Store frame for next iteration
                prev_frame_for_motion = frame.copy()

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
                                print(f"⚠️ Radius changed: {prev_ball[2]}px → {smoothed_ball[2]}px - resetting ({stable_frames} frames)")
                                stable_frames = 0
                                prev_ball = None
                                radius_history.clear()  # Reset radius smoothing
                                continue
                            else:
                                # Radius is consistent - that's all we need for locking
                                stable_frames += 1
                                if stable_frames <= 3:  # Only print first few frames
                                    print(f"✓ Stable frame {stable_frames}/3 - Ball at ({x}, {y}) r={r}px")
                        else:
                            stable_frames += 1
                            print(f"✓ First stable frame - Ball at ({x}, {y}) r={r}px")

                        prev_ball = smoothed_ball  # Use smoothed radius for consistency

                        if stable_frames >= 3:  # Only 3 stable frames needed for ULTRA-FAST locking (50ms @ 60fps)
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

                        # Calculate velocity in pixels/second
                        velocity_px_per_sec = displacement * frame_rate

                        # VELOCITY-BASED HIT DETECTION
                        # Backswing/clubhead movement is slow (~20-30 px/frame = 4000-6000 px/sec @ 200fps)
                        # Ball hit is FAST (should be 60+ px/frame = 12000+ px/sec @ 200fps)
                        # Picking up/dropping ball is moderate (~40 px/frame = 8000 px/sec @ 200fps)
                        # Set threshold at 15000 px/sec (~75 px/frame @ 200fps) to ignore hand movements
                        velocity_threshold = 15000  # px/sec (approximately 75+ mph ball speed)

                        if velocity_px_per_sec > velocity_threshold:  # FAST movement = HIT!
                            # Ball is moving fast - this is a shot!
                            print(f"🏌️ BALL HIT DETECTED!")
                            print(f"   Velocity: {velocity_px_per_sec:.0f} px/sec ({displacement:.1f} px/frame)")
                            print(f"   Threshold: {velocity_threshold} px/sec (backswing ignored)")
                            self.statusChanged.emit("Capturing...", "red")

                            # Capture frames: 15 BEFORE impact (from buffer) + 15 AFTER impact
                            frames = list(frame_buffer)  # Get pre-impact frames from circular buffer
                            print(f"   📸 Captured {len(frames)} pre-impact frames from buffer")

                            # Capture post-impact frames
                            frame_delay = 1.0 / frame_rate
                            for i in range(15):
                                capture_frame = self.picam2.capture_array()
                                frames.append(capture_frame)
                                time.sleep(frame_delay)

                            print(f"   📸 Total: {len(frames)} frames captured (15 before + 15 after impact)")

                            # Save frames (COMMENTED OUT - testing GIF settings)
                            # for i, save_frame in enumerate(frames):
                            #     filename = f"shot_{next_shot:03d}_frame_{i:03d}.jpg"
                            #     filepath = os.path.join(captures_folder, filename)
                            #     self._save_frame(filepath, save_frame)

                            print(f"✅ Shot #{next_shot} saved!")
                            self.shotCaptured.emit(next_shot)

                            # Create replay GIF (Snapchat-style: 15 before + 15 after at 0.5x speed)
                            # Use all 30 frames for smooth slow-motion replay
                            replay_frames = frames  # All frames (15 before + 15 after impact)
                            gif_filename = f"shot_{next_shot:03d}_replay.gif"
                            gif_path = os.path.join(captures_folder, gif_filename)
                            gif_result = self._create_replay_gif(replay_frames, gif_path, fps=frame_rate, speed_multiplier=0.5)

                            if gif_result:
                                print(f"🎬 Replay GIF created: {gif_filename}")
                                # Convert to absolute path for QML
                                abs_gif_path = os.path.abspath(gif_result)
                                print(f"📂 Absolute path: {abs_gif_path}")
                                self.replayReady.emit(abs_gif_path)  # Signal QML to show popup

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

                        # Calculate velocity
                        velocity_px_per_sec = displacement * frame_rate

                        # Even if radius doesn't match, check for rapid movement (velocity-based)
                        # Ball being hit can cause radius variation due to motion blur
                        # Use VERY high threshold since radius changed (more uncertainty)
                        if velocity_px_per_sec > 20000:  # Very high threshold for mismatched radius (100 px/frame @ 200fps)
                            print(f"🏌️ BALL HIT DETECTED (radius mismatch - motion blur)!")
                            print(f"   Velocity: {velocity_px_per_sec:.0f} px/sec ({displacement:.1f} px/frame)")
                            print(f"   Radius changed: {original_ball[2]}px → {current_ball[2]}px")
                            self.statusChanged.emit("Capturing...", "red")

                            # Capture frames: 15 BEFORE impact (from buffer) + 15 AFTER impact
                            frames = list(frame_buffer)
                            print(f"   📸 Captured {len(frames)} pre-impact frames from buffer")

                            # Capture post-impact frames
                            frame_delay = 1.0 / frame_rate
                            for i in range(15):
                                capture_frame = self.picam2.capture_array()
                                frames.append(capture_frame)
                                time.sleep(frame_delay)

                            print(f"   📸 Total: {len(frames)} frames captured (15 before + 15 after impact)")

                            # Save frames (COMMENTED OUT - testing GIF settings)
                            # for i, save_frame in enumerate(frames):
                            #     filename = f"shot_{next_shot:03d}_frame_{i:03d}.jpg"
                            #     filepath = os.path.join(captures_folder, filename)
                            #     self._save_frame(filepath, save_frame)

                            print(f"✅ Shot #{next_shot} saved!")
                            self.shotCaptured.emit(next_shot)

                            # Create replay GIF (Snapchat-style: 15 before + 15 after at 0.5x speed)
                            replay_frames = frames  # All frames (15 before + 15 after impact)
                            gif_filename = f"shot_{next_shot:03d}_replay.gif"
                            gif_path = os.path.join(captures_folder, gif_filename)
                            gif_result = self._create_replay_gif(replay_frames, gif_path, fps=frame_rate, speed_multiplier=0.5)

                            if gif_result:
                                print(f"🎬 Replay GIF created: {gif_filename}")
                                # Convert to absolute path for QML
                                abs_gif_path = os.path.abspath(gif_result)
                                print(f"📂 Absolute path: {abs_gif_path}")
                                self.replayReady.emit(abs_gif_path)  # Signal QML to show popup

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

                                    # Capture frames: 15 BEFORE impact (from buffer) + 15 AFTER impact
                                    frames = list(frame_buffer)  # Get pre-impact frames from circular buffer
                                    print(f"   📸 Captured {len(frames)} pre-impact frames from buffer")

                                    # Capture post-impact frames
                                    frame_delay = 1.0 / frame_rate
                                    for i in range(15):
                                        capture_frame = self.picam2.capture_array()
                                        frames.append(capture_frame)
                                        time.sleep(frame_delay)

                                    print(f"   📸 Total: {len(frames)} frames captured (15 before + 15 after impact)")

                                    # Save frames (COMMENTED OUT - testing GIF settings)
                                    # for i, save_frame in enumerate(frames):
                                    #     filename = f"shot_{next_shot:03d}_frame_{i:03d}.jpg"
                                    #     filepath = os.path.join(captures_folder, filename)
                                    #     cv2.imwrite(filepath, cv2.cvtColor(save_frame, cv2.COLOR_RGB2BGR))

                                    print(f"✅ Shot #{next_shot} saved!")
                                    self.shotCaptured.emit(next_shot)

                                    # Create replay GIF (Snapchat-style: 15 before + 15 after at 0.5x speed)
                                    # Use all 30 frames for smooth slow-motion replay
                                    replay_frames = frames  # All frames (15 before + 15 after impact)
                                    gif_filename = f"shot_{next_shot:03d}_replay.gif"
                                    gif_path = os.path.join(captures_folder, gif_filename)
                                    gif_result = self._create_replay_gif(replay_frames, gif_path, fps=frame_rate, speed_multiplier=0.5)

                                    if gif_result:
                                        print(f"🎬 Replay GIF created: {gif_filename}")
                                        # Convert to absolute path for QML
                                        abs_gif_path = os.path.abspath(gif_result)
                                        print(f"📂 Absolute path: {abs_gif_path}")
                                        self.replayReady.emit(abs_gif_path)  # Signal QML to show popup

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

                    # Color code by motion state
                    if motion_state == "STATIONARY":
                        circle_color = (0, 255, 0)  # Green = stationary (locked)
                    elif motion_state == "MOVING":
                        circle_color = (0, 255, 255)  # Yellow = moving
                    elif motion_state == "IMPACT":
                        circle_color = (0, 0, 255)  # Red = impact detected
                    else:
                        circle_color = (255, 255, 255)  # White = unknown

                    # Ball circle
                    cv2.circle(vis_frame, (x, y), r, circle_color, 3)
                    # Center point
                    cv2.circle(vis_frame, (x, y), 3, circle_color, -1)
                    # Position + velocity text
                    cv2.putText(vis_frame, f"Ball: ({x}, {y}) r={r} v={velocity:.1f}px/f", (x + r + 5, y),
                               cv2.FONT_HERSHEY_SIMPLEX, 0.5, circle_color, 2)

                # Draw FPS counter
                cv2.putText(vis_frame, f"FPS: {current_fps}", (10, 30),
                           cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 255), 2)

                # Draw status with motion state
                if original_ball is not None:
                    status_text = f"LOCKED - {motion_state}"
                    status_color = (0, 255, 0)  # Green
                elif current_ball is not None:
                    status_text = f"Detecting ({stable_frames}/5) - {motion_state}"
                    status_color = (0, 255, 255)  # Yellow
                else:
                    status_text = "No Ball Detected"
                    status_color = (0, 0, 255)  # Red

                cv2.putText(vis_frame, status_text, (10, 70),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.8, status_color, 2)

                # Draw edge velocity tracking info
                if current_ball is not None:
                    info_y = 110
                    cv2.putText(vis_frame, f"Velocity: {velocity:.2f} px/frame", (10, info_y),
                               cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)
                    cv2.putText(vis_frame, f"Motion: {motion_state}", (10, info_y + 25),
                               cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)
                    cv2.putText(vis_frame, f"Stable: {stable_frames}/5", (10, info_y + 50),
                               cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)

                # Save debug frame every ~5 seconds (based on frame rate)
                debug_frame_counter += 1
                if debug_frame_counter % (frame_rate * 5) == 0:  # Every 5 seconds
                    self._save_frame("debug_detection_latest.jpg", vis_frame)
                    # Print detection info periodically
                    if current_ball is not None:
                        lock_status = 'LOCKED' if original_ball is not None else 'Detecting'
                        if original_ball is not None:
                            # Show velocity if locked (for monitoring backswing vs hit)
                            vel_px_sec = velocity * frame_rate
                            print(f"📊 FPS: {current_fps} | Ball: ({x},{y}) r={r} | {lock_status} | Vel: {vel_px_sec:.0f}px/s (hit@4000+)", flush=True)
                        else:
                            print(f"📊 FPS: {current_fps} | Ball: ({x},{y}) r={r} | {lock_status}", flush=True)
                    else:
                        print(f"📊 FPS: {current_fps} | No Ball", flush=True)

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
                    self.picam2.close()  # Properly close camera, not just stop
                    self.picam2 = None
                    print("📷 Camera released and closed in cleanup")
            except Exception as e:
                print(f"⚠️ Error releasing camera: {e}")
                # Force set to None even if close fails
                self.picam2 = None

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

    # Create QML engine
    engine = QQmlApplicationEngine()

    # Create frame provider for high-FPS preview
    frame_provider = FrameProvider()
    engine.addImageProvider("frame", frame_provider)

    # Create managers
    settings_manager = SettingsManager()
    camera_manager = CameraManager(settings_manager, frame_provider)
    capture_manager = CaptureManager(settings_manager, camera_manager)
    sound_manager = SoundManager()
    profile_manager = ProfileManager()
    history_manager = HistoryManager()

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