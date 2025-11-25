#!/usr/bin/env python3
"""
K-LD2 Sensor Manager
Manages continuous polling of K-LD2 radar sensor for:
- Club head speed detection
- Detection trigger signal for camera capture
"""
import serial
import time
import threading
from PySide6.QtCore import QObject, Signal


class KLD2Manager(QObject):
    """Manages K-LD2 radar sensor for speed and detection"""

    # Signals
    speedUpdated = Signal(float)  # Club head speed in mph
    detectionTriggered = Signal()  # Detection event (ball was hit)
    statusChanged = Signal(str, str)  # (status_message, color)

    def __init__(self, port='/dev/serial0', baudrate=38400):
        super().__init__()
        self.port = port
        self.baudrate = baudrate
        self.ser = None
        self.is_running = False
        self.poll_thread = None

        # Detection state
        self.last_detection_state = False
        self.current_speed_mph = 0.0

    def _send_command(self, command):
        """Send ASCII command to K-LD2 and get response"""
        try:
            if not command.endswith('\r'):
                command += '\r'

            self.ser.reset_input_buffer()
            self.ser.write(command.encode('ascii'))
            time.sleep(0.05)  # Brief delay for response

            if self.ser.in_waiting > 0:
                response = self.ser.read(self.ser.in_waiting)
                try:
                    return response.decode('ascii', errors='ignore').strip()
                except:
                    return None
            return None
        except Exception as e:
            print(f"K-LD2 command error: {e}")
            return None

    def _parse_detection_register(self, response):
        """Parse detection register response (@R00XX)

        Returns tuple: (detected, direction, speed_range, micro_detection)

        Bit 0: Detection (0=no, 1=yes)
        Bit 1: Direction (0=receding, 1=approaching)
        Bit 2: Speed range (0=low, 1=high)
        Bit 3: Micro detection (0=no, 1=yes)
        """
        try:
            if not response or not response.startswith('@R00'):
                return (False, None, None, False)

            # Extract hex value
            hex_val = response[4:].strip()
            if not hex_val:
                return (False, None, None, False)

            val = int(hex_val, 16)

            detected = (val & 0x01) != 0
            direction = "approaching" if (val & 0x02) else "receding"
            speed_range = "high" if (val & 0x04) else "low"
            micro = (val & 0x08) != 0

            return (detected, direction, speed_range, micro)
        except Exception as e:
            print(f"Error parsing detection register: {e}")
            return (False, None, None, False)

    def _get_speed_from_detection_string(self, response):
        """Parse detection string response ($C00) to extract speed

        Format: "XXX;XXX;XXX;" where values are velocity data
        K-LD2 returns speed in internal units - needs conversion

        Returns: speed in mph (0 if no detection)
        """
        try:
            if not response or not response.startswith('@C00'):
                return 0.0

            # Extract data portion after @C00
            data = response[4:].strip()

            # Split by semicolon
            values = data.split(';')
            if len(values) < 3:
                return 0.0

            # Parse first value (main velocity reading)
            try:
                raw_value = int(values[0])

                # K-LD2 velocity conversion (datasheet specific)
                # This is sensor-specific - may need calibration
                # Assuming linear relationship: raw_value → mph
                # You may need to adjust this based on your sensor's datasheet

                if raw_value == 0:
                    return 0.0

                # Example conversion (adjust based on actual calibration):
                # K-LD2 typically outputs in m/s or km/h units internally
                # This is a placeholder - CHECK YOUR DATASHEET!
                speed_mph = raw_value * 0.1  # Placeholder conversion factor

                return abs(speed_mph)  # Return absolute value

            except ValueError:
                return 0.0

        except Exception as e:
            print(f"Error parsing speed: {e}")
            return 0.0

    def start(self):
        """Start continuous K-LD2 polling"""
        if self.is_running:
            print("K-LD2 already running")
            return False

        try:
            # Open serial port
            print(f"Connecting to K-LD2 on {self.port} at {self.baudrate} baud...")
            self.ser = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                timeout=0.5
            )

            # Test connection with firmware version command
            response = self._send_command("$F00")
            if response and response.startswith('@F00'):
                firmware = response[4:].strip()
                print(f"K-LD2 connected - Firmware: {firmware}")
                self.statusChanged.emit("K-LD2 Connected", "green")
            else:
                print("Warning: K-LD2 did not respond properly")
                self.statusChanged.emit("K-LD2 No Response", "yellow")

            # Start polling thread
            self.is_running = True
            self.poll_thread = threading.Thread(target=self._poll_loop, daemon=True)
            self.poll_thread.start()

            print("K-LD2 polling started")
            return True

        except Exception as e:
            print(f"Failed to start K-LD2: {e}")
            self.statusChanged.emit(f"K-LD2 Error: {e}", "red")
            if self.ser:
                try:
                    self.ser.close()
                except:
                    pass
                self.ser = None
            return False

    def stop(self):
        """Stop K-LD2 polling"""
        print("Stopping K-LD2...")
        self.is_running = False

        # Wait for thread to finish
        if self.poll_thread:
            self.poll_thread.join(timeout=2.0)
            self.poll_thread = None

        # Close serial port
        if self.ser:
            try:
                self.ser.close()
            except:
                pass
            self.ser = None

        print("K-LD2 stopped")
        self.statusChanged.emit("K-LD2 Stopped", "gray")

    def _poll_loop(self):
        """Background thread for continuous K-LD2 polling"""
        try:
            poll_count = 0

            while self.is_running:
                poll_start = time.time()

                # Poll detection register ($R00) - check if something was detected
                detection_response = self._send_command("$R00")
                detected, direction, speed_range, micro = self._parse_detection_register(detection_response)

                # If detection occurred, get speed data
                if detected:
                    # Get detection string for speed data
                    speed_response = self._send_command("$C00")
                    speed_mph = self._get_speed_from_detection_string(speed_response)

                    if speed_mph > 0:
                        self.current_speed_mph = speed_mph
                        self.speedUpdated.emit(speed_mph)

                        # Only print significant speed changes (every 5 mph)
                        if poll_count % 10 == 0:  # Throttle logging
                            print(f"K-LD2: {speed_mph:.1f} mph ({direction}, {speed_range})")

                    # Trigger detection event on RISING EDGE (wasn't detected, now is)
                    if not self.last_detection_state:
                        print(f"DETECTION TRIGGER - Speed: {speed_mph:.1f} mph")
                        self.detectionTriggered.emit()

                    self.last_detection_state = True
                else:
                    # No detection
                    self.last_detection_state = False

                poll_count += 1

                # Poll at ~20 Hz (50ms interval) for responsive detection
                # K-LD2 can handle up to 100Hz polling if needed
                elapsed = time.time() - poll_start
                sleep_time = max(0.05 - elapsed, 0.001)  # 50ms target, minimum 1ms
                time.sleep(sleep_time)

        except Exception as e:
            print(f"K-LD2 poll loop error: {e}")
            import traceback
            traceback.print_exc()
        finally:
            self.is_running = False
            print("K-LD2 poll loop exited")

    def get_current_speed(self):
        """Get the most recent speed reading (for manual query)"""
        return self.current_speed_mph
