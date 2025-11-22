#!/usr/bin/env python3
"""Test K-LD2 LiDAR sensor connection and data reading"""
import serial
import time
import struct

def test_kld2(port='/dev/serial0', baudrate=115200):
    """
    Test K-LD2 LiDAR sensor

    K-LD2 protocol:
    - Default baudrate: 115200
    - Data format varies by firmware, typically sends distance in mm
    """

    print("=== K-LD2 LiDAR Sensor Test ===\n")
    print(f"Port: {port}")
    print(f"Baudrate: {baudrate}\n")

    try:
        # Open serial connection
        ser = serial.Serial(
            port=port,
            baudrate=baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1
        )

        print("✓ Serial port opened successfully")
        print("Waiting for data...\n")

        # Clear buffer
        ser.reset_input_buffer()

        # Read data continuously
        frame_count = 0
        while frame_count < 50:  # Read 50 samples
            if ser.in_waiting > 0:
                # Read raw bytes
                raw_data = ser.read(ser.in_waiting)

                # Display as hex
                hex_str = ' '.join([f'{b:02X}' for b in raw_data])
                print(f"Frame {frame_count}: {hex_str}")

                # Try to parse as common K-LD2 formats
                if len(raw_data) >= 4:
                    # Common format: some sensors send 4-byte frames
                    # This varies by firmware version
                    print(f"  Raw bytes: {raw_data}")
                    print(f"  Length: {len(raw_data)} bytes")

                frame_count += 1
                time.sleep(0.1)

        ser.close()
        print("\n✓ Test complete!")

    except serial.SerialException as e:
        print(f"✗ Serial error: {e}")
        print("\nTroubleshooting:")
        print("1. Check if UART is enabled: sudo raspi-config")
        print("2. Check if serial console is disabled")
        print("3. Verify wiring: TX->RX, RX->TX, 5V->VCC, GND->GND")
        print("4. Check permissions: sudo chmod 666 /dev/serial0")
        return False

    except KeyboardInterrupt:
        print("\n\nTest interrupted by user")
        ser.close()
        return False

    except Exception as e:
        print(f"✗ Error: {e}")
        return False

    return True

if __name__ == "__main__":
    print("Starting K-LD2 test...\n")

    # Test different baudrates if needed
    baudrates = [115200, 256000, 9600]

    for baud in baudrates:
        print(f"\nTrying baudrate: {baud}")
        if test_kld2(baudrate=baud):
            print(f"\n✓ Success with baudrate: {baud}")
            break
        time.sleep(1)
