import sys
import os
import subprocess

os.environ["QT_QUICK_CONTROLS_STYLE"] = "Material"

from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType
from PySide6.QtCore import qInstallMessageHandler, QObject, Signal, Slot, QUrl
from PySide6.QtMultimedia import QSoundEffect
from ProfileManager import ProfileManager  # Import the new class

# ============================================
# Camera Manager Class
# ============================================
class CameraManager(QObject):
    """Manages Raspberry Pi camera using rpicam-vid"""

    def __init__(self):
        super().__init__()
        self.camera_process = None

    @Slot()
    def startCamera(self):
        """Start the Raspberry Pi camera preview in a window"""
        if self.camera_process is not None:
            print("⚠️ Camera is already running")
            return

        try:
            # Try rpicam-vid first (newer Raspberry Pi OS)
            # Window size: 480x360 (3-4 inch viewing area on 5" 800x480 screen)
            # Position: centered in the screen
            print("🎥 Starting camera with rpicam-vid...")
            self.camera_process = subprocess.Popen([
                'rpicam-vid',
                '--timeout', '0',      # Run indefinitely
                '--width', '480',      # 3-4 inch width
                '--height', '360',     # Maintain aspect ratio
                '--preview', '160,60,480,360'  # x,y,width,height - centered position
            ])
            print("✅ Camera started successfully")
        except FileNotFoundError:
            try:
                # Fallback to rpicam-hello with same windowed settings
                print("🎥 Starting camera with rpicam-hello...")
                self.camera_process = subprocess.Popen([
                    'rpicam-hello',
                    '--timeout', '0',
                    '--width', '480',
                    '--height', '360',
                    '--preview', '160,60,480,360'
                ])
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
    camera_manager = CameraManager()
    sound_manager = SoundManager()
    profile_manager = ProfileManager()

    # Create QML engine
    engine = QQmlApplicationEngine()

    # Expose managers to QML
    engine.rootContext().setContextProperty("cameraManager", camera_manager)
    engine.rootContext().setContextProperty("soundManager", sound_manager)
    engine.rootContext().setContextProperty("profileManager", profile_manager)
    
    # Load main QML
    engine.load('main.qml')
    
    if not engine.rootObjects():
        print("❌ QML failed to load. See messages above.")
        sys.exit(-1)

    sys.exit(app.exec())