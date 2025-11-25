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

    def __init__(self, port='/dev/serial0', baudrate=38400, min_trigger_speed=15.0, sampling_rate=2560):
        super().__init__()
        self.port = port
        self.baudrate = baudrate
        self.ser = None
        self.is_running = False
        self.poll_thread = None

        # Detection state
        self.last_detection_state = False
        self.current_speed_mph = 0.0

        # Minimum speed threshold to trigger detection (mph)
        # Prevents false triggers from 0.0 mph detections or slow movements
        self.min_trigger_speed = min_trigger_speed

        # K-LD2 sampling rate (Hz) - default 2560 Hz (S04=02)
        # Used for bin-to-speed conversion
        self.sampling_rate = sampling_rate

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

        $C00 Format: "DET;SPD;MAG;" (detection_register;speed_bin;magnitude_dB)
        - DET: Detection register value (see R00)
        - SPD: Speed in bin (FFT bin number, 0-127)
        - MAG: Magnitude in dB

        K-LD2 returns speed in "bin" units that must be converted to mph using:
        speed_mph = bin × (sampling_rate / 256 / 44.7) × 0.621371

        Returns: speed in mph (0 if no detection)
        """
        try:
            # DEBUG: Log raw response
            print(f"🔍 K-LD2 Raw Response: '{response}'")

            if not response or not response.startswith('@C00'):
                print(f"   ⚠️ Invalid response format (expected @C00...)")
                return 0.0

            # Extract data portion after @C00
            data = response[4:].strip()
            print(f"   📊 Data portion: '{data}'")

            # Split by semicolon - format is "detection_register;speed_bin;magnitude_dB;"
            values = data.split(';')
            print(f"   📈 Parsed values: {values} (detection_reg;speed_bin;magnitude)")

            if len(values) < 2:
                print(f"   ⚠️ Not enough values (got {len(values)}, need at least 2)")
                return 0.0

            # Parse second value (speed in bin - this is index 1)
            try:
                speed_bin = int(values[1])
                print(f"   🎯 Raw speed bin value: {speed_bin}")

                if speed_bin == 0:
                    print(f"   ⚠️ Speed bin is 0 - no motion detected by sensor")
                    return 0.0

                # K-LD2 Speed Conversion (from datasheet page 11):
                # speed_km/h = bin × (sampling_rate / 256) / 44.7
                # speed_mph = speed_km/h × 0.621371
                #
                # Combined formula:
                # speed_mph = bin × (sampling_rate / 256 / 44.7) × 0.621371
                #
                # With default sampling rate 2560 Hz (S04=02):
                # speed_mph = bin × 0.139

                doppler_hz = speed_bin * (self.sampling_rate / 256.0)
                speed_kmh = doppler_hz / 44.7
                speed_mph = speed_kmh * 0.621371

                print(f"   📐 Doppler: {doppler_hz:.1f} Hz")
                print(f"   📐 Speed: {speed_kmh:.1f} km/h = {speed_mph:.1f} mph")
                print(f"   ✅ Converted speed: {speed_mph:.1f} mph (bin {speed_bin} @ {self.sampling_rate}Hz)")

                return abs(speed_mph)  # Return absolute value

            except ValueError as e:
                print(f"   ❌ Failed to parse speed bin value: {e}")
                return 0.0
            except IndexError as e:
                print(f"   ❌ Speed bin not in response (index 1): {e}")
                return 0.0

        except Exception as e:
            print(f"❌ Error parsing speed: {e}")
            import traceback
            traceback.print_exc()
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
                    # ONLY if speed exceeds minimum threshold (prevents 0.0 mph false triggers)
                    if not self.last_detection_state:
                        if speed_mph >= self.min_trigger_speed:
                            print(f"✅ DETECTION TRIGGER - Speed: {speed_mph:.1f} mph (threshold: {self.min_trigger_speed:.1f})")
                            self.detectionTriggered.emit()
                        else:
                            print(f"⚠️ Detection ignored - Speed {speed_mph:.1f} mph below threshold ({self.min_trigger_speed:.1f} mph)")

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

    def set_min_trigger_speed(self, speed_mph):
        """Set the minimum speed threshold for trigger detection (mph)

        Args:
            speed_mph: Minimum club head speed to trigger capture (typically 15-30 mph)

        Common values:
            - 15 mph: Very sensitive, may catch slow practice swings
            - 20 mph: Good balance for most users
            - 30 mph: Only full-speed shots
        """
        self.min_trigger_speed = speed_mph
        print(f"K-LD2 minimum trigger speed set to {speed_mph:.1f} mph")

    def get_min_trigger_speed(self):
        """Get the current minimum trigger speed threshold"""
        return self.min_trigger_speed
