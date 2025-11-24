#!/usr/bin/env python3
"""K-LD2 Modbus Reader - Continuous polling"""
import serial
import time
import struct

class KLD2Reader:
    def __init__(self, port='/dev/serial0', baudrate=115200):
        self.port = port
        self.baudrate = baudrate
        self.ser = None

        # Modbus read command that worked
        self.read_command = bytes([0x01, 0x03, 0x00, 0x00, 0x00, 0x01, 0x84, 0x0A])

    def connect(self):
        """Open serial connection"""
        try:
            self.ser = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                timeout=0.5
            )
            print(f"Connected to K-LD2 at {self.baudrate} baud")
            return True
        except Exception as e:
            print(f"Connection failed: {e}")
            return False

    def read_sensor(self):
        """Send Modbus request and read response"""
        if not self.ser:
            return None

        try:
            # Clear buffer
            self.ser.reset_input_buffer()

            # Send read command
            self.ser.write(self.read_command)

            # Wait for response
            time.sleep(0.05)

            if self.ser.in_waiting > 0:
                response = self.ser.read(self.ser.in_waiting)
                return response
            else:
                return None

        except Exception as e:
            print(f"Read error: {e}")
            return None

    def parse_response(self, data):
        """Parse K-LD2 response data"""
        if not data or len(data) < 3:
            return None

        # Display raw hex for now (need datasheet to properly decode)
        hex_str = ' '.join([f'{b:02X}' for b in data])
        return hex_str

    def close(self):
        """Close serial connection"""
        if self.ser:
            self.ser.close()
            print("Connection closed")

def main():
    print("\n=== K-LD2 Modbus Reader ===")
    print("Reading sensor data continuously...")
    print("Press Ctrl+C to stop\n")

    reader = KLD2Reader()

    if not reader.connect():
        return

    try:
        count = 0
        while True:
            response = reader.read_sensor()

            if response:
                parsed = reader.parse_response(response)
                count += 1
                print(f"[{count:04d}] Data: {parsed}")
            else:
                print("No response")

            time.sleep(0.1)  # Poll at ~10Hz

    except KeyboardInterrupt:
        print("\n\nStopped by user")
    finally:
        reader.close()

if __name__ == "__main__":
    main()
