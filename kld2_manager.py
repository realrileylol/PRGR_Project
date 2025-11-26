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

    def __init__(self, port='/dev/serial0', baudrate=38400, min_trigger_speed=15.0,
                 min_magnitude_db=0, max_magnitude_db=999,
                 sensitivity=None, sampling_rate=2560, debug_mode=False):
        super().__init__()
        self.port = port
        self.baudrate = baudrate
        self.ser = None
        self.is_running = False
        self.poll_thread = None

        # Detection state
        self.last_detection_state = False
        self.current_speed_mph = 0.0
        self.current_magnitude_db = 0

        # Minimum speed threshold to trigger detection (mph)
        # Prevents false triggers from 0.0 mph detections or slow movements
        self.min_trigger_speed = min_trigger_speed

        # Magnitude (signal strength) filtering range (dB)
        # Allows filtering by BOTH weak (far) and strong (close) signals
        #
        # min_magnitude_db: Reject weak signals below this (noise filtering)
        #   - Lower = detect farther away (weaker signals)
        #   - Higher = only strong signals (closer range)
        #
        # max_magnitude_db: Reject strong signals above this (close-range filtering)
        #   - Lower = ignore nearby movements
        #   - Higher = accept all signal strengths
        #
        # Example for 4+ feet detection:
        #   min_magnitude_db=20 (accept weak far-field signals)
        #   max_magnitude_db=60 (reject strong close-range signals)
        self.min_magnitude_db = min_magnitude_db
        self.max_magnitude_db = max_magnitude_db

        # Sensor sensitivity (0-9, None = don't configure)
        # Higher = more sensitive to weak signals (better far-field detection)
        # Will be set via $D01 command during startup if not None
        self.sensitivity = sensitivity

        # K-LD2 sampling rate (Hz) - default 2560 Hz (S04=02)
        # Used for bin-to-speed conversion
        self.sampling_rate = sampling_rate

        # Debug mode - shows ALL detections even if below threshold
        self.debug_mode = debug_mode

    def _send_command(self, command):
        """Send ASCII command to K-LD2 and get response

        Returns raw response string (may or may not include @ prefix)
        """
        try:
            if not command.endswith('\r'):
                command += '\r'

            self.ser.reset_input_buffer()
            self.ser.write(command.encode('ascii'))
            time.sleep(0.05)  # Brief delay for response

            if self.ser.in_waiting > 0:
                response = self.ser.read(self.ser.in_waiting)
                try:
                    decoded = response.decode('ascii', errors='ignore').strip()
                    # Debug: show what we actually received
                    # print(f"DEBUG _send_command: sent '{command.strip()}' → received '{decoded}'")
                    return decoded
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
        """Parse detection string response ($C00) to extract speed and magnitude

        $C00 Response Format (may or may not have @C00 prefix):
        "@C00DET;SPD;MAG;" or "DET;SPD;MAG;"
        - DET: Detection register value (see R00)
        - SPD: Speed in bin (FFT bin number, 0-127)
        - MAG: Magnitude in dB (signal strength)

        K-LD2 returns speed in "bin" units that must be converted to mph using:
        speed_mph = bin × (sampling_rate / 256 / 44.7) × 0.621371

        Returns: tuple (speed_mph, magnitude_db)
                 (0, 0) if no detection or parse error
        """
        try:
            if not response:
                return (0.0, 0)

            # Handle both formats: "@C00001;076;067;" or "001;076;067;"
            data = response
            if response.startswith('@C00'):
                data = response[4:].strip()

            # Split by semicolon - format is "detection_register;speed_bin;magnitude_dB;"
            values = data.split(';')

            if len(values) < 3:
                if self.debug_mode:
                    print(f"⚠️ K-LD2 parse error: Not enough values (got {len(values)}, need at least 3)")
                return (0.0, 0)

            # Parse second value (speed in bin - this is index 1)
            # Parse third value (magnitude in dB - this is index 2)
            try:
                speed_bin = int(values[1])
                magnitude_db = int(values[2])

                if speed_bin == 0:
                    return (0.0, magnitude_db)

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

                # Only log verbose details in debug mode for speeds >= 5 mph
                if self.debug_mode and abs(speed_mph) >= 5.0:
                    print(f"🔍 K-LD2 Raw Response: '{response}'")
                    print(f"   📊 Data: '{data}'")
                    print(f"   📈 Parsed: {values}")
                    print(f"   🎯 Speed bin: {speed_bin}")
                    print(f"   💪 Magnitude: {magnitude_db} dB")
                    print(f"   📐 Doppler: {doppler_hz:.1f} Hz")
                    print(f"   📐 Speed: {speed_kmh:.1f} km/h = {speed_mph:.1f} mph")

                return (abs(speed_mph), magnitude_db)  # Return absolute speed and magnitude

            except ValueError as e:
                if self.debug_mode:
                    print(f"❌ Failed to parse values: {e}")
                return (0.0, 0)
            except IndexError as e:
                if self.debug_mode:
                    print(f"❌ Values not in response: {e}")
                return (0.0, 0)

        except Exception as e:
            print(f"❌ Error parsing speed: {e}")
            import traceback
            traceback.print_exc()
            return (0.0, 0)

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

            # Configure sensitivity if specified
            if self.sensitivity is not None:
                # Get current sensitivity
                current = self._send_command("$D01")
                if current:
                    print(f"K-LD2 current sensitivity: {current}")

                # Set sensitivity (0-9, higher = more sensitive)
                # Command format: $D01=X where X is 0-9
                set_cmd = f"$D01={self.sensitivity:01d}"
                response = self._send_command(set_cmd)
                if response:
                    print(f"K-LD2 sensitivity set to {self.sensitivity} (0=low, 9=high)")
                else:
                    print(f"Warning: Could not set sensitivity to {self.sensitivity}")

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
                    # Get detection string for speed and magnitude data
                    speed_response = self._send_command("$C00")
                    speed_mph, magnitude_db = self._get_speed_from_detection_string(speed_response)

                    if speed_mph > 0:
                        self.current_speed_mph = speed_mph
                        self.current_magnitude_db = magnitude_db
                        self.speedUpdated.emit(speed_mph)

                        # In debug mode, only show detections >= 5 mph to filter noise
                        if self.debug_mode and speed_mph >= 5.0:
                            print(f"🎯 K-LD2 DETECTED: {speed_mph:.1f} mph, {magnitude_db} dB ({direction}, {speed_range}, micro={micro})")
                        elif not self.debug_mode and poll_count % 10 == 0:  # Throttle logging in normal mode
                            print(f"K-LD2: {speed_mph:.1f} mph, {magnitude_db} dB ({direction}, {speed_range})")

                    # Trigger detection event on RISING EDGE (wasn't detected, now is)
                    # Check speed and magnitude thresholds (both min and max)
                    if not self.last_detection_state:
                        # Check thresholds
                        speed_ok = speed_mph >= self.min_trigger_speed
                        magnitude_min_ok = magnitude_db >= self.min_magnitude_db
                        magnitude_max_ok = magnitude_db <= self.max_magnitude_db
                        magnitude_ok = magnitude_min_ok and magnitude_max_ok

                        if speed_ok and magnitude_ok:
                            print(f"🚀 CAPTURE TRIGGERED! Speed: {speed_mph:.1f} mph, Magnitude: {magnitude_db} dB")
                            self.detectionTriggered.emit()
                        else:
                            # Only show ignored detections if >= 5 mph (reduces noise)
                            if speed_mph >= 5.0:
                                reasons = []
                                if not speed_ok:
                                    reasons.append(f"speed {speed_mph:.1f} < {self.min_trigger_speed:.1f} mph")
                                if not magnitude_min_ok:
                                    reasons.append(f"magnitude {magnitude_db} dB < {self.min_magnitude_db} dB (too weak/far)")
                                if not magnitude_max_ok:
                                    reasons.append(f"magnitude {magnitude_db} dB > {self.max_magnitude_db} dB (too strong/close)")
                                print(f"⚠️ Detection ignored - {', '.join(reasons)}")

                    self.last_detection_state = True
                else:
                    # No detection - only show end message if we logged a detection
                    if self.debug_mode and self.last_detection_state and self.current_speed_mph >= 5.0:
                        print(f"   (detection ended at {self.current_speed_mph:.1f} mph, {self.current_magnitude_db} dB)")
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

    def get_current_magnitude(self):
        """Get the most recent magnitude (signal strength) reading in dB"""
        return self.current_magnitude_db

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

    def set_min_magnitude(self, magnitude_db):
        """Set the minimum magnitude (signal strength) threshold (dB)

        Args:
            magnitude_db: Minimum signal strength to trigger capture

        Higher values require stronger signals (closer range)
        Lower values allow weaker signals (farther range)

        Common values:
            - 0: No filtering (accept all weak signals)
            - 20-30: Accept far-field signals (4+ feet)
            - 40-50: Medium range
        """
        self.min_magnitude_db = magnitude_db
        print(f"K-LD2 minimum magnitude threshold set to {magnitude_db} dB")

    def get_min_magnitude(self):
        """Get the current minimum magnitude threshold"""
        return self.min_magnitude_db

    def set_max_magnitude(self, magnitude_db):
        """Set the maximum magnitude (signal strength) threshold (dB)

        Args:
            magnitude_db: Maximum signal strength to trigger capture

        Lower values reject strong close-range signals
        Higher values accept all signal strengths

        Common values for far-field (4+ feet) detection:
            - 50-60: Reject close-range movements (< 2 feet)
            - 70-80: Reject very close movements (< 1 foot)
            - 999: No maximum filtering (accept all)
        """
        self.max_magnitude_db = magnitude_db
        print(f"K-LD2 maximum magnitude threshold set to {magnitude_db} dB")

    def get_max_magnitude(self):
        """Get the current maximum magnitude threshold"""
        return self.max_magnitude_db

    def set_sensitivity(self, sensitivity):
        """Set the sensor sensitivity (0-9)

        Args:
            sensitivity: Sensor sensitivity level (0=low, 9=high)

        Higher sensitivity detects weaker signals (better far-field detection)
        but may increase false positives.

        Recommended for 4+ feet detection: 7-9
        """
        if sensitivity < 0 or sensitivity > 9:
            print(f"Warning: Sensitivity must be 0-9, got {sensitivity}")
            return

        self.sensitivity = sensitivity
        if self.ser:
            # Apply immediately if sensor is connected
            set_cmd = f"$D01={sensitivity:01d}"
            response = self._send_command(set_cmd)
            if response:
                print(f"K-LD2 sensitivity set to {sensitivity} (0=low, 9=high)")
            else:
                print(f"Warning: Could not set sensitivity to {sensitivity}")
        else:
            print(f"K-LD2 sensitivity will be set to {sensitivity} on next connection")

    def get_sensitivity(self):
        """Get the current sensor sensitivity setting

        Returns the configured sensitivity or queries the sensor if connected
        """
        if self.ser:
            response = self._send_command("$D01")
            if response and response.startswith('@D01'):
                try:
                    return int(response[4:].strip())
                except:
                    pass
        return self.sensitivity
