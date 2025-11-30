"""
K-LD2 Radar Manager - Detects ball speed using K-LD2 Doppler radar sensor

Uses 20480 Hz sampling rate for better speed detection (was 2560 Hz before)
Detects receding speeds (ball moving away from radar)
"""

import serial
import time
import threading
from PySide6.QtCore import QObject, Signal

class KLD2Manager(QObject):
    """Manages K-LD2 radar sensor for ball speed detection"""

    # Signals
    speedUpdated = Signal(float)  # Speed in MPH
    statusChanged = Signal(str, str)  # (message, color)
    detectionTriggered = Signal()  # Emitted when ball is detected

    def __init__(self, min_trigger_speed=10.0, debug_mode=False):
        super().__init__()
        self.serial_port = None
        self.is_running = False
        self.read_thread = None
        self.min_trigger_speed = min_trigger_speed  # Minimum speed to trigger detection
        self.debug_mode = debug_mode

    def start(self):
        """Start the K-LD2 sensor"""
        try:
            # Find K-LD2 serial port (usually /dev/ttyUSB0 or /dev/ttyACM0)
            port_candidates = ['/dev/ttyUSB0', '/dev/ttyACM0', '/dev/ttyUSB1']

            for port in port_candidates:
                try:
                    self.serial_port = serial.Serial(
                        port=port,
                        baudrate=115200,
                        timeout=1
                    )
                    print(f"K-LD2 connected on {port}")
                    break
                except:
                    continue

            if self.serial_port is None:
                print("K-LD2 not found on any port")
                self.statusChanged.emit("K-LD2 not found", "red")
                return False

            # Configure K-LD2 for 20480 Hz sampling rate (was 2560 Hz)
            # This provides better speed detection accuracy
            time.sleep(0.1)
            self.serial_port.write(b'$S0405\r\n')  # Set 20480 Hz sampling rate
            time.sleep(0.1)

            # Start reading thread
            self.is_running = True
            self.read_thread = threading.Thread(target=self._read_loop, daemon=True)
            self.read_thread.start()

            self.statusChanged.emit("K-LD2 ready", "green")
            print(f"K-LD2 started with 20480 Hz sampling rate (min trigger: {self.min_trigger_speed} mph)")
            return True

        except Exception as e:
            print(f"Failed to start K-LD2: {e}")
            self.statusChanged.emit(f"K-LD2 error: {e}", "red")
            return False

    def stop(self):
        """Stop the K-LD2 sensor"""
        self.is_running = False

        if self.read_thread is not None:
            self.read_thread.join(timeout=2.0)
            self.read_thread = None

        if self.serial_port is not None:
            self.serial_port.close()
            self.serial_port = None

        self.statusChanged.emit("K-LD2 stopped", "gray")
        print("K-LD2 stopped")

    def _read_loop(self):
        """Background thread to read speed data from K-LD2"""
        buffer = ""

        while self.is_running:
            try:
                if self.serial_port.in_waiting > 0:
                    # Read data from serial port
                    data = self.serial_port.read(self.serial_port.in_waiting)
                    buffer += data.decode('ascii', errors='ignore')

                    # Process complete lines
                    while '\n' in buffer:
                        line, buffer = buffer.split('\n', 1)
                        line = line.strip()

                        # Parse K-LD2 speed data (format: speed in m/s)
                        if line and not line.startswith('$'):
                            try:
                                speed_ms = float(line)

                                # Convert m/s to mph
                                speed_mph = abs(speed_ms * 2.23694)

                                # Detect receding speeds (negative values = ball moving away)
                                # K-LD2 returns negative for receding targets
                                # We use absolute value for speed display

                                if self.debug_mode:
                                    # In debug mode, show all detections above 5 mph
                                    if speed_mph >= 5.0:
                                        print(f"K-LD2: {speed_mph:.1f} mph (raw: {speed_ms:.2f} m/s)")

                                # Emit speed update
                                self.speedUpdated.emit(speed_mph)

                                # Trigger detection if speed exceeds threshold
                                if speed_mph >= self.min_trigger_speed:
                                    print(f"K-LD2 DETECTION: {speed_mph:.1f} mph")
                                    self.detectionTriggered.emit()

                            except ValueError:
                                # Invalid speed data, skip
                                pass

                time.sleep(0.01)  # 10ms sleep to prevent CPU spinning

            except Exception as e:
                if self.is_running:  # Only print if we didn't intentionally stop
                    print(f"K-LD2 read error: {e}")
                    time.sleep(0.1)

    def __del__(self):
        """Cleanup on destruction"""
        self.stop()
