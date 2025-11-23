#!/usr/bin/env python3
"""Advanced K-LD2 test with initialization commands"""
import serial
import time

def test_kld2_with_commands(port='/dev/serial0'):
    """Test K-LD2 with various initialization commands"""

    baudrates = [115200, 256000, 9600, 19200, 38400, 57600]

    # Common radar initialization commands
    init_commands = [
        b'\xAA\x55\x00\x00\x00\x00\xFF\x00\x01\x00',  # Start continuous mode
        b'\x01\x03\x00\x00\x00\x01\x84\x0A',          # Modbus read
        b'AT\r\n',                                     # AT command
        b'\xFF\x00\x01\x00',                           # Simple start
        b'\x53\x59',                                   # Start bytes "SY"
    ]

    for baud in baudrates:
        print(f"\n{'='*60}")
        print(f"Testing baudrate: {baud}")
        print('='*60)

        try:
            ser = serial.Serial(
                port=port,
                baudrate=baud,
                timeout=0.5
            )

            print(f"Port opened at {baud} baud")
            ser.reset_input_buffer()

            # First check for spontaneous data
            print("\n1. Listening for spontaneous data (5 seconds)...")
            start = time.time()
            data_received = False

            while (time.time() - start) < 5:
                if ser.in_waiting > 0:
                    data = ser.read(ser.in_waiting)
                    hex_str = ' '.join([f'{b:02X}' for b in data])
                    print(f"   RX: {hex_str}")
                    data_received = True
                time.sleep(0.1)

            if data_received:
                print(f"\n   SUCCESS! Sensor is transmitting at {baud} baud")
                print("   Run test_kld2.py with this baudrate to see continuous data")
                ser.close()
                return

            print("   No spontaneous data")

            # Try initialization commands
            print("\n2. Trying initialization commands...")
            for i, cmd in enumerate(init_commands):
                hex_str = ' '.join([f'{b:02X}' for b in cmd])
                print(f"\n   Command {i+1}: {hex_str}")

                ser.reset_input_buffer()
                ser.write(cmd)
                time.sleep(0.5)

                if ser.in_waiting > 0:
                    response = ser.read(ser.in_waiting)
                    hex_resp = ' '.join([f'{b:02X}' for b in response])
                    print(f"   Response: {hex_resp}")

                    # Try reading more data after command
                    print("   Listening for continuous data...")
                    start = time.time()
                    while (time.time() - start) < 3:
                        if ser.in_waiting > 0:
                            data = ser.read(ser.in_waiting)
                            hex_data = ' '.join([f'{b:02X}' for b in data])
                            print(f"   Data: {hex_data}")
                        time.sleep(0.1)

                    print(f"\n   SUCCESS! Sensor responded to command {i+1} at {baud} baud")
                    ser.close()
                    return
                else:
                    print("   No response")

            ser.close()

        except Exception as e:
            print(f"Error: {e}")

    print("\n" + "="*60)
    print("NO DATA RECEIVED at any baudrate")
    print("="*60)
    print("\nPossible issues:")
    print("1. TX/RX wires swapped (try switching them)")
    print("2. Sensor requires specific protocol not tested")
    print("3. Sensor is defective")
    print("4. Sensor requires external configuration tool first")
    print("\nCheck K-LD2-RFB-00H-03 datasheet for initialization sequence")

if __name__ == "__main__":
    print("\nK-LD2 Advanced Diagnostic Tool")
    print("Testing multiple baudrates and sending init commands...\n")
    test_kld2_with_commands()
