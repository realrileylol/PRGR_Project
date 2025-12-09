#!/usr/bin/env python3
"""
Standalone K-LD2 Radar Test Script
===================================
Tests the K-LD2 Doppler radar sensor independently from the main GUI.

Model: K-LD2-RFB-00H-02 (RFBEAM MICROWAVE GMBH)
- 38400 baud UART communication
- ASCII command protocol
- Separates approaching (club) from receding (ball) targets

Usage:
    python3 test_radar_standalone.py                    # Basic monitoring
    python3 test_radar_standalone.py --debug            # Show all raw data
    python3 test_radar_standalone.py --mode ball        # Ball-based trigger
    python3 test_radar_standalone.py --mode club        # Club-based trigger
    python3 test_radar_standalone.py --interactive      # Interactive command testing

Requirements:
    pip install pyserial
"""

import serial
import time
import argparse
import sys
import signal
from datetime import datetime
from typing import Optional, Tuple, List
from dataclasses import dataclass


@dataclass
class RadarReading:
    """Single radar reading with timestamp"""
    timestamp: datetime
    approaching_speed: int  # mph - club head (moving toward radar)
    receding_speed: int     # mph - ball (moving away from radar)
    approaching_mag: int    # signal magnitude
    receding_mag: int       # signal magnitude


class KLD2RadarTester:
    """
    Standalone K-LD2 radar tester - no Qt/GUI dependencies.

    Implements the same detection logic as KLD2Manager.cpp:
    - Ball-based mode: Triggers when receding (ball) speed exceeds threshold
    - Club-based mode: Tracks club approach → peak → impact (speed drop)
    """

    # K-LD2 Protocol constants
    BAUD_RATE = 38400
    CMD_SET_SAMPLING = b'$S0405\r\n'  # 20480 Hz for golf speeds (up to ~144 mph)
    CMD_GET_SPEED = b'$C01\r\n'       # Get directional speed data

    # Default thresholds (can be adjusted)
    DEFAULT_CLUB_TRIGGER = 50.0   # mph - minimum club speed to start tracking
    DEFAULT_BALL_TRIGGER = 12.0   # mph - minimum ball speed to trigger

    # Serial port candidates (Raspberry Pi GPIO UART)
    PORT_CANDIDATES = ['/dev/serial0', '/dev/ttyAMA0', '/dev/ttyS0']

    def __init__(self,
                 trigger_mode: str = "ball",
                 min_club_trigger: float = DEFAULT_CLUB_TRIGGER,
                 min_ball_trigger: float = DEFAULT_BALL_TRIGGER,
                 debug: bool = False):
        """
        Initialize the radar tester.

        Args:
            trigger_mode: "ball" (simple) or "club" (complex state machine)
            min_club_trigger: Minimum club speed to start tracking (mph)
            min_ball_trigger: Minimum ball speed to trigger capture (mph)
            debug: Show all raw radar data
        """
        self.serial_port: Optional[serial.Serial] = None
        self.trigger_mode = trigger_mode
        self.min_club_trigger = min_club_trigger
        self.min_ball_trigger = min_ball_trigger
        self.debug = debug

        # Swing state machine (club-based mode)
        self.in_swing = False
        self.max_club_speed = 0.0

        # Ball detection state (ball-based mode)
        self.ball_detected = False

        # Statistics
        self.readings: List[RadarReading] = []
        self.impacts_detected = 0
        self.max_club_seen = 0.0
        self.max_ball_seen = 0.0

        self._running = False

    def find_and_connect(self) -> bool:
        """Find and connect to K-LD2 radar on available serial ports."""
        for port in self.PORT_CANDIDATES:
            try:
                print(f"Trying K-LD2 on {port}...")
                self.serial_port = serial.Serial(
                    port=port,
                    baudrate=self.BAUD_RATE,
                    timeout=1.0,
                    bytesize=serial.EIGHTBITS,
                    parity=serial.PARITY_NONE,
                    stopbits=serial.STOPBITS_ONE
                )
                print(f"  ✓ Connected on {port} @ {self.BAUD_RATE} baud")
                return True
            except serial.SerialException as e:
                print(f"  ✗ {port} failed: {e}")
                continue

        print("\n❌ K-LD2 radar not found on any port!")
        print("   Check wiring: GPIO14 (RXD) → Radar TX, GPIO15 (TXD) → Radar RX")
        return False

    def configure(self) -> bool:
        """Configure the radar with optimal sampling rate."""
        if not self.serial_port or not self.serial_port.is_open:
            return False

        try:
            time.sleep(0.2)  # Let radar wake up

            # Set 20480 Hz sampling rate (good for golf swing speeds up to ~144 mph)
            print("Configuring sampling rate (20480 Hz)...")
            self.serial_port.write(self.CMD_SET_SAMPLING)
            self.serial_port.flush()
            time.sleep(0.3)

            # Read and show response
            if self.serial_port.in_waiting > 0:
                response = self.serial_port.read(self.serial_port.in_waiting)
                if self.debug:
                    print(f"  Config response: {response}")

            print("  ✓ Radar configured")
            return True

        except Exception as e:
            print(f"  ✗ Configuration failed: {e}")
            return False

    def read_once(self) -> Optional[RadarReading]:
        """Send command and read single radar response."""
        if not self.serial_port or not self.serial_port.is_open:
            return None

        try:
            # Send speed query command
            self.serial_port.write(self.CMD_GET_SPEED)
            self.serial_port.flush()
            time.sleep(0.05)  # 50ms poll interval

            # Read response
            if self.serial_port.in_waiting > 0:
                data = self.serial_port.read(self.serial_port.in_waiting)
                line = data.decode('ascii', errors='ignore').strip()

                # Parse K-LD2 $C01 response: approaching;receding;app_mag;rec_mag;
                # Skip command echoes and acknowledgments
                for part in line.split('\n'):
                    part = part.strip()
                    if part and not part.startswith('$') and not part.startswith('@'):
                        return self._parse_response(part)

            return None

        except Exception as e:
            if self.debug:
                print(f"Read error: {e}")
            return None

    def _parse_response(self, line: str) -> Optional[RadarReading]:
        """Parse K-LD2 response into RadarReading."""
        try:
            parts = line.split(';')
            if len(parts) >= 4:
                reading = RadarReading(
                    timestamp=datetime.now(),
                    approaching_speed=int(parts[0]),
                    receding_speed=int(parts[1]),
                    approaching_mag=int(parts[2]),
                    receding_mag=int(parts[3])
                )
                return reading
        except (ValueError, IndexError) as e:
            if self.debug:
                print(f"Parse error: {line} ({e})")
        return None

    def process_reading(self, reading: RadarReading) -> Optional[str]:
        """
        Process a radar reading and detect impacts.
        Returns event string if something significant happened.
        """
        self.readings.append(reading)

        # Track max speeds seen
        if reading.approaching_speed > self.max_club_seen:
            self.max_club_seen = reading.approaching_speed
        if reading.receding_speed > self.max_ball_seen:
            self.max_ball_seen = reading.receding_speed

        # === BALL-BASED TRIGGER MODE (Recommended) ===
        if self.trigger_mode == "ball":
            if reading.receding_speed >= self.min_ball_trigger:
                if not self.ball_detected:
                    self.ball_detected = True
                    self.impacts_detected += 1
                    return f"🎯 IMPACT! Ball: {reading.receding_speed} mph"
            else:
                # Reset when speed drops (ready for next shot)
                if self.ball_detected:
                    self.ball_detected = False
                    return "  (Reset - ready for next shot)"
            return None

        # === CLUB-BASED TRIGGER MODE (Legacy) ===
        if self.trigger_mode == "club":
            # Club approaching above threshold?
            if reading.approaching_speed >= self.min_club_trigger:
                if not self.in_swing:
                    # Swing starting
                    self.in_swing = True
                    self.max_club_speed = reading.approaching_speed
                    return f"⛳ SWING START: Club {reading.approaching_speed} mph"
                else:
                    # Track peak speed during swing
                    if reading.approaching_speed > self.max_club_speed:
                        self.max_club_speed = reading.approaching_speed
                    return None

            elif self.in_swing:
                # Club speed dropped - impact detected!
                self.impacts_detected += 1
                event = f"🏌️ IMPACT! Peak club: {self.max_club_speed} mph → {reading.approaching_speed} mph"

                # Reset for next swing
                self.in_swing = False
                self.max_club_speed = 0.0
                return event

        return None

    def run_monitor(self, duration: Optional[float] = None):
        """
        Run continuous monitoring mode.

        Args:
            duration: Run for N seconds, or None for indefinite (Ctrl+C to stop)
        """
        print("\n" + "="*60)
        print("K-LD2 RADAR MONITOR")
        print("="*60)
        print(f"Trigger mode: {self.trigger_mode.upper()}")
        if self.trigger_mode == "ball":
            print(f"Ball trigger threshold: {self.min_ball_trigger} mph")
        else:
            print(f"Club trigger threshold: {self.min_club_trigger} mph")
        print(f"Debug: {'ON' if self.debug else 'OFF'}")
        print("-"*60)
        print("Press Ctrl+C to stop\n")

        self._running = True
        start_time = time.time()
        last_print = 0

        try:
            while self._running:
                reading = self.read_once()

                if reading:
                    event = self.process_reading(reading)

                    # Show events immediately
                    if event:
                        print(event)

                    # Show debug output for any speed
                    elif self.debug and (reading.approaching_speed > 0 or reading.receding_speed > 0):
                        now = time.time()
                        if now - last_print > 0.1:  # Rate limit debug output
                            parts = []
                            if reading.approaching_speed > 0:
                                parts.append(f"Club: {reading.approaching_speed} mph (mag {reading.approaching_mag})")
                            if reading.receding_speed > 0:
                                parts.append(f"Ball: {reading.receding_speed} mph (mag {reading.receding_mag})")
                            print(f"  {' | '.join(parts)}")
                            last_print = now

                # Check duration limit
                if duration and (time.time() - start_time) >= duration:
                    break

        except KeyboardInterrupt:
            print("\n\nStopping...")

        self._running = False
        self._print_summary()

    def run_interactive(self):
        """Run interactive command testing mode."""
        print("\n" + "="*60)
        print("K-LD2 INTERACTIVE TEST MODE")
        print("="*60)
        print("Commands:")
        print("  r  - Read single speed measurement")
        print("  m  - Monitor continuously (Ctrl+C to stop)")
        print("  c  - Send custom command")
        print("  s  - Show statistics")
        print("  q  - Quit")
        print("-"*60)

        while True:
            try:
                cmd = input("\nCommand> ").strip().lower()

                if cmd == 'q':
                    break

                elif cmd == 'r':
                    reading = self.read_once()
                    if reading:
                        print(f"  Approaching: {reading.approaching_speed} mph (mag {reading.approaching_mag})")
                        print(f"  Receding:    {reading.receding_speed} mph (mag {reading.receding_mag})")
                    else:
                        print("  No data received")

                elif cmd == 'm':
                    self.run_monitor()

                elif cmd == 'c':
                    custom = input("  Enter command (e.g., $C01): ").strip()
                    if not custom.startswith('$'):
                        custom = '$' + custom
                    if not custom.endswith('\r\n'):
                        custom += '\r\n'

                    self.serial_port.write(custom.encode('ascii'))
                    self.serial_port.flush()
                    time.sleep(0.3)

                    if self.serial_port.in_waiting > 0:
                        response = self.serial_port.read(self.serial_port.in_waiting)
                        print(f"  Response: {response}")
                        print(f"  Decoded:  {response.decode('ascii', errors='ignore')}")
                    else:
                        print("  No response")

                elif cmd == 's':
                    self._print_summary()

                else:
                    print("  Unknown command. Use r/m/c/s/q")

            except KeyboardInterrupt:
                print("\n")
                continue

    def _print_summary(self):
        """Print session statistics."""
        print("\n" + "-"*60)
        print("SESSION SUMMARY")
        print("-"*60)
        print(f"Total readings:     {len(self.readings)}")
        print(f"Impacts detected:   {self.impacts_detected}")
        print(f"Max club speed:     {self.max_club_seen} mph")
        print(f"Max ball speed:     {self.max_ball_seen} mph")
        print("-"*60)

    def close(self):
        """Clean up and close serial connection."""
        self._running = False
        if self.serial_port and self.serial_port.is_open:
            self.serial_port.close()
            print("Serial port closed")


def main():
    parser = argparse.ArgumentParser(
        description="Standalone K-LD2 Radar Test Script",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 test_radar_standalone.py                    # Basic monitoring
  python3 test_radar_standalone.py --debug            # Show all raw data
  python3 test_radar_standalone.py --mode ball        # Ball-based trigger (default)
  python3 test_radar_standalone.py --mode club        # Club-based trigger
  python3 test_radar_standalone.py --interactive      # Interactive command testing
  python3 test_radar_standalone.py --duration 30      # Run for 30 seconds
        """
    )

    parser.add_argument('--mode', '-m',
                        choices=['ball', 'club'],
                        default='ball',
                        help='Trigger mode: ball (simple) or club (state machine)')

    parser.add_argument('--ball-threshold', '-b',
                        type=float,
                        default=12.0,
                        help='Minimum ball speed to trigger (mph, default: 12)')

    parser.add_argument('--club-threshold', '-c',
                        type=float,
                        default=50.0,
                        help='Minimum club speed to start tracking (mph, default: 50)')

    parser.add_argument('--debug', '-d',
                        action='store_true',
                        help='Show all raw radar data')

    parser.add_argument('--interactive', '-i',
                        action='store_true',
                        help='Interactive command testing mode')

    parser.add_argument('--duration', '-t',
                        type=float,
                        default=None,
                        help='Run for N seconds (default: indefinite)')

    parser.add_argument('--port', '-p',
                        type=str,
                        default=None,
                        help='Specific serial port to use (e.g., /dev/serial0)')

    args = parser.parse_args()

    print("="*60)
    print("K-LD2 DOPPLER RADAR TEST TOOL")
    print("Model: K-LD2-RFB-00H-02 (RFBEAM)")
    print("="*60)

    # Create tester
    tester = KLD2RadarTester(
        trigger_mode=args.mode,
        min_club_trigger=args.club_threshold,
        min_ball_trigger=args.ball_threshold,
        debug=args.debug
    )

    # Handle specific port
    if args.port:
        tester.PORT_CANDIDATES = [args.port]

    # Setup signal handler for clean exit
    def signal_handler(sig, frame):
        print("\n\nCaught interrupt, cleaning up...")
        tester.close()
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)

    try:
        # Connect to radar
        if not tester.find_and_connect():
            sys.exit(1)

        # Configure radar
        if not tester.configure():
            tester.close()
            sys.exit(1)

        # Run appropriate mode
        if args.interactive:
            tester.run_interactive()
        else:
            tester.run_monitor(duration=args.duration)

    finally:
        tester.close()

    print("\nDone!")


if __name__ == "__main__":
    main()
