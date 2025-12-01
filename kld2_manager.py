"""
K-LD2 Radar Manager - Detects club head speed using K-LD2 Doppler radar sensor

Model: K-LD2-RFB-00H-02 (RFBEAM MICROWAVE GMBH)
- Uses 38400 baud rate (not 115200!)
- ASCII command protocol with $ commands and @ responses
- Commands: $S0405 (set 20480 Hz sampling), $C01 (get speed with direction)
- Response format: approaching_speed;receding_speed;approaching_mag;receding_mag;
- Can separate approaching (toward radar) from receding (away from radar)
- Detects RECEDING targets only (ball moving away after impact)
- 20480 Hz sampling rate for golf swing speeds (max ~144 mph)
"""

import serial
import time
import threading
from PySide6.QtCore import QObject, Signal, Slot, Property

class KLD2Manager(QObject):
    """Manages K-LD2 radar sensor for ball speed detection (receding targets only)"""

    # Signals
    speedUpdated = Signal(float)  # Speed in MPH (for display)
    clubSpeedUpdated = Signal(float)  # Club head speed (approaching)
    ballSpeedUpdated = Signal(float)  # Ball speed (receding)
    statusChanged = Signal(str, str)  # (message, color)
    detectionTriggered = Signal()  # Emitted when trigger condition met
    isRunningChanged = Signal()  # Notify when is_running changes

    def __init__(self, min_trigger_speed=10.0, debug_mode=False, trigger_mode="club"):
        super().__init__()
        self.serial_port = None
        self._is_running = False
        self.read_thread = None
        self.min_trigger_speed = min_trigger_speed  # Minimum speed to trigger detection
        self.debug_mode = debug_mode
        self.trigger_mode = trigger_mode  # "club" or "ball" - what triggers camera

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
                # Poll the radar by sending $C01 command (returns directional data)
                self.serial_port.write(b'$C01\r\n')
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

                        # Parse K-LD2 $C01 response format: approaching;receding;app_mag;rec_mag;
                        # Example: "040;000;072;000;" = 40 mph approaching, 0 receding
                        # Example: "000;010;000;075;" = 0 approaching, 10 mph receding
                        if line and not line.startswith('$') and not line.startswith('@'):
                            try:
                                # Split by semicolon
                                parts = line.split(';')
                                if len(parts) >= 4:
                                    approaching_speed = int(parts[0])
                                    receding_speed = int(parts[1])
                                    approaching_mag = int(parts[2])
                                    receding_mag = int(parts[3])

                                    # Debug: show both speeds
                                    if self.debug_mode:
                                        if approaching_speed > 0:
                                            print(f"K-LD2: {approaching_speed} mph CLUB (approaching, mag {approaching_mag})")
                                        if receding_speed > 0:
                                            print(f"K-LD2: {receding_speed} mph BALL (receding, mag {receding_mag})")

                                    # Emit separate signals for club and ball speeds
                                    if approaching_speed > 0:
                                        self.clubSpeedUpdated.emit(float(approaching_speed))
                                    if receding_speed > 0:
                                        self.ballSpeedUpdated.emit(float(receding_speed))

                                    # Trigger based on mode (for camera capture timing)
                                    if self.trigger_mode == "club":
                                        # Trigger on CLUB HEAD (approaching) - catches swing BEFORE impact
                                        # This allows camera to capture pre-impact frames!
                                        if approaching_speed >= self.min_trigger_speed:
                                            print(f"CAMERA TRIGGER: Club {approaching_speed} mph (before impact)")
                                            self.speedUpdated.emit(float(approaching_speed))
                                            self.detectionTriggered.emit()
                                    else:  # trigger_mode == "ball"
                                        # Trigger on BALL (receding) - happens AFTER impact
                                        # Too late for pre-impact camera frames!
                                        if receding_speed >= self.min_trigger_speed:
                                            print(f"CAMERA TRIGGER: Ball {receding_speed} mph (after impact)")
                                            self.speedUpdated.emit(float(receding_speed))
                                            self.detectionTriggered.emit()

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
