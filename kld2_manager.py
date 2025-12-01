"""
K-LD2 Radar Manager - Detects ball speed using K-LD2 Doppler radar sensor

Model: K-LD2-RFB-00H-02 (RFBEAM MICROWAVE GMBH)
- Uses 38400 baud rate (not 115200!)
- ASCII command protocol with $ commands and @ responses
- Commands: $R00 (check detection), $C00 (get speed/magnitude)
- Response format: speed_bin;speed_mph;magnitude;
- Uses 20480 Hz sampling rate for golf swing speeds (max ~144 mph)
"""

import serial
import time
import threading
from PySide6.QtCore import QObject, Signal, Slot, Property

class KLD2Manager(QObject):
    """Manages K-LD2 radar sensor for ball speed detection"""

    # Signals
    speedUpdated = Signal(float)  # Speed in MPH
    statusChanged = Signal(str, str)  # (message, color)
    detectionTriggered = Signal()  # Emitted when ball is detected
    isRunningChanged = Signal()  # Notify when is_running changes

    def __init__(self, min_trigger_speed=10.0, debug_mode=False):
        super().__init__()
        self.serial_port = None
        self._is_running = False
        self.read_thread = None
        self.min_trigger_speed = min_trigger_speed  # Minimum speed to trigger detection
        self.debug_mode = debug_mode

    @Property(bool, notify=isRunningChanged)
    def is_running(self):
        """Property to expose is_running state to QML"""
        return self._is_running

    @Slot()
    def start(self):
        """Start the K-LD2 sensor"""
        try:
            # K-LD2 connected via GPIO UART pins (not USB)
            # Pin 8 (GPIO14/RXD) -> Radar TX, Pin 10 (GPIO15/TXD) -> Radar RX
            port_candidates = ['/dev/serial0', '/dev/ttyAMA0', '/dev/ttyS0']

            for port in port_candidates:
                try:
                    print(f"Trying K-LD2 on {port}...")
                    # K-LD2 uses 38400 baud rate, not 115200!
                    self.serial_port = serial.Serial(
                        port=port,
                        baudrate=38400,  # CORRECT baud rate for K-LD2
                        timeout=1
                    )
                    print(f"✓ K-LD2 connected on {port} @ 38400 baud")
                    break
                except Exception as e:
                    print(f"✗ {port} failed: {e}")
                    continue

            if self.serial_port is None:
                print("K-LD2 not found on any port")
                self.statusChanged.emit("K-LD2 not found", "red")
                return False

            # Wake up radar and configure
            time.sleep(0.2)

            # Set 20480 Hz sampling rate for golf swing speeds (max ~144 mph)
            self.serial_port.write(b'$S0405\r\n')
            time.sleep(0.2)

            # Read response
            if self.serial_port.in_waiting > 0:
                response = self.serial_port.read(self.serial_port.in_waiting)
                print(f"Sampling rate set response: {response}")

            # Start reading thread
            self._is_running = True
            self.isRunningChanged.emit()  # Notify QML that state changed
            self.read_thread = threading.Thread(target=self._read_loop, daemon=True)
            self.read_thread.start()

            self.statusChanged.emit("K-LD2 ready", "green")
            print(f"K-LD2 started with 20480 Hz sampling rate (min trigger: {self.min_trigger_speed} mph)")
            return True

        except Exception as e:
            print(f"Failed to start K-LD2: {e}")
            self.statusChanged.emit(f"K-LD2 error: {e}", "red")
            return False

    @Slot()
    def stop(self):
        """Stop the K-LD2 sensor"""
        self._is_running = False
        self.isRunningChanged.emit()  # Notify QML that state changed

        if self.read_thread is not None:
            self.read_thread.join(timeout=2.0)
            self.read_thread = None

        if self.serial_port is not None:
            self.serial_port.close()
            self.serial_port = None

        self.statusChanged.emit("K-LD2 stopped", "gray")
        print("K-LD2 stopped")

    def _read_loop(self):
        """Background thread to poll K-LD2 for speed data"""
        buffer = ""

        while self._is_running:
            try:
                # Poll the radar by sending $C00 command
                self.serial_port.write(b'$C00\r\n')
                time.sleep(0.05)  # 50ms between polls = 20Hz polling rate

                # Read response
                if self.serial_port.in_waiting > 0:
                    # Read data from serial port
                    data = self.serial_port.read(self.serial_port.in_waiting)

                    buffer += data.decode('ascii', errors='ignore')

                    # Process complete lines
                    while '\n' in buffer:
                        line, buffer = buffer.split('\n', 1)
                        line = line.strip()

                        # Parse K-LD2 ASCII response format: speed_bin;speed_mph;magnitude;
                        # Example: "001;001;066;" = speed bin 1, 1 mph, magnitude 66
                        # Example: "009;003;074;" = speed bin 9, 3 mph, magnitude 74
                        if line and not line.startswith('$') and not line.startswith('@'):
                            try:
                                # Split by semicolon
                                parts = line.split(';')
                                if len(parts) >= 3:
                                    speed_bin = int(parts[0])
                                    speed_mph_raw = int(parts[1])  # Can be negative for receding
                                    magnitude = int(parts[2])

                                    # Skip zero speed readings (no motion)
                                    if speed_mph_raw == 0:
                                        continue

                                    # CLUB HEAD SPEED MODE: Detect APPROACHING speeds (club moving toward radar)
                                    # Setup: [pillows] <--4-5ft-- [golfer/ball] <--4-5ft-- [RADAR]
                                    # Approaching (positive) = club head moving toward radar (WANT THIS!)
                                    # Receding (negative) = follow-through moving away (IGNORE!)

                                    is_approaching = speed_mph_raw > 0
                                    speed_mph = abs(speed_mph_raw)

                                    # Debug output for non-zero speeds
                                    if self.debug_mode and speed_mph > 0:
                                        direction = "APPROACHING (club head)" if is_approaching else "RECEDING (follow-through)"
                                        print(f"K-LD2: {speed_mph} mph {direction} (bin {speed_bin}, mag {magnitude})")

                                    # Only emit and trigger on APPROACHING targets (club head)
                                    if is_approaching:
                                        # Emit speed update
                                        self.speedUpdated.emit(float(speed_mph))

                                        # Trigger detection if speed exceeds threshold
                                        if speed_mph >= self.min_trigger_speed:
                                            print(f"K-LD2 DETECTION: {speed_mph} mph (club head speed)")
                                            self.detectionTriggered.emit()
                                    else:
                                        # Ignore receding targets (follow-through)
                                        if self.debug_mode and speed_mph >= 5:
                                            print(f"   Ignored follow-through: {speed_mph} mph (receding)")

                            except (ValueError, IndexError) as e:
                                # Invalid data format, skip
                                if self.debug_mode:
                                    print(f"K-LD2 parse error: {line} ({e})")
                                pass

            except Exception as e:
                if self._is_running:  # Only print if we didn't intentionally stop
                    print(f"K-LD2 read error: {e}")
                    time.sleep(0.1)

    def __del__(self):
        """Cleanup on destruction"""
        self.stop()
