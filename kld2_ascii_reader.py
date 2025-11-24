#!/usr/bin/env python3
"""
K-LD2 Proper ASCII Protocol Reader
Based on datasheet specifications
"""
import serial
import time
import struct

def send_command(ser, command):
    """Send ASCII command to K-LD2 and get response"""
    # Commands must end with <CR> (0x0D)
    if not command.endswith('\r'):
        command += '\r'

    ser.reset_input_buffer()
    ser.write(command.encode('ascii'))
    time.sleep(0.1)

    if ser.in_waiting > 0:
        response = ser.read(ser.in_waiting)
        try:
            return response.decode('ascii', errors='ignore')
        except:
            # Return hex if not ASCII
            return ' '.join([f'{b:02X}' for b in response])
    return None

def test_basic_commands(ser):
    """Test basic K-LD2 ASCII commands"""
    print("\n" + "="*70)
    print("Testing K-LD2 ASCII Protocol Commands")
    print("="*70)

    commands = [
        ("$F00", "Get firmware version"),
        ("$F01", "Get device type (should be 0001 for K-LD2)"),
        ("$R04", "Get operation state (0=startup, 1=learn, 2=run)"),
        ("$R00", "Get detection register"),
        ("$R03", "Get noise level"),
        ("$S04", "Get sampling rate"),
        ("$D01", "Get sensitivity setting"),
        ("$D00", "Get hold time setting"),
        ("$C00", "Get detection string"),
    ]

    results = {}

    for cmd, desc in commands:
        print(f"\n{desc}")
        print(f"  Command: {cmd}")
        response = send_command(ser, cmd)

        if response:
            print(f"  Response: {response.strip()}")
            results[cmd] = response.strip()
        else:
            print(f"  No response")
            results[cmd] = None

    return results

def decode_detection_register(value):
    """Decode detection register bits"""
    try:
        val = int(value, 16)
        det = (val & 0x01) != 0
        direction = "Approaching" if (val & 0x02) else "Receding"
        speed_range = "High" if (val & 0x04) else "Low"
        micro = (val & 0x08) != 0

        return {
            'detection': det,
            'direction': direction if det else "N/A",
            'speed_range': speed_range if det else "N/A",
            'micro_detection': micro
        }
    except:
        return None

def read_continuous_data(ser, duration=5):
    """Read any continuous data output from K-LD2"""
    print("\n" + "="*70)
    print(f"Listening for continuous data ({duration}s)")
    print("="*70)

    ser.reset_input_buffer()
    start = time.time()
    data_count = 0

    while (time.time() - start) < duration:
        if ser.in_waiting > 0:
            data = ser.read(ser.in_waiting)
            data_count += 1

            # Try ASCII first
            try:
                ascii_str = data.decode('ascii', errors='ignore')
                if ascii_str.strip():
                    print(f"[{time.time()-start:.2f}s] ASCII: {ascii_str.strip()}")
            except:
                pass

            # Also show hex
            hex_str = ' '.join([f'{b:02X}' for b in data])
            print(f"[{time.time()-start:.2f}s] HEX: {hex_str}")

        time.sleep(0.1)

    print(f"\nReceived {data_count} data bursts")

def analyze_mystery_bytes(data_hex):
    """Analyze the mystery response"""
    print("\n" + "="*70)
    print("Analyzing Mystery Response")
    print("="*70)

    # Parse hex string to bytes
    if isinstance(data_hex, str):
        bytes_data = bytes([int(x, 16) for x in data_hex.split()])
    else:
        bytes_data = data_hex

    print(f"Raw hex: {' '.join([f'{b:02X}' for b in bytes_data])}")
    print(f"Length: {len(bytes_data)} bytes")

    # Check for ASCII
    try:
        ascii_str = bytes_data.decode('ascii')
        if all(32 <= b < 127 for b in bytes_data):
            print(f"ASCII: {ascii_str}")
    except:
        print("Not valid ASCII")

    # Try as uint16 values
    print("\nAs uint16 (big-endian):")
    for i in range(0, len(bytes_data)-1, 2):
        val = struct.unpack('>H', bytes_data[i:i+2])[0]
        print(f"  Bytes {i:2d}-{i+1:2d}: {val:5d} (0x{val:04X})")

    print("\nAs uint16 (little-endian):")
    for i in range(0, len(bytes_data)-1, 2):
        val = struct.unpack('<H', bytes_data[i:i+2])[0]
        print(f"  Bytes {i:2d}-{i+1:2d}: {val:5d} (0x{val:04X})")

def test_different_baudrates(port='/dev/serial0'):
    """Try different baud rates to find the right one"""
    print("\n" + "="*70)
    print("Testing Different Baud Rates")
    print("="*70)

    baudrates = [9600, 19200, 38400, 57600, 115200, 230400, 460800]

    for baud in baudrates:
        try:
            print(f"\n--- Testing {baud} baud ---")
            ser = serial.Serial(port=port, baudrate=baud, timeout=0.5)

            # Try firmware version command
            response = send_command(ser, "$F00")

            if response and response.startswith('@'):
                print(f"  ✓ VALID RESPONSE AT {baud} BAUD!")
                print(f"  Response: {response.strip()}")
                ser.close()
                return baud
            elif response:
                print(f"  Response: {response.strip()}")
            else:
                print(f"  No response")

            ser.close()
        except Exception as e:
            print(f"  Error: {e}")

    return None

def main():
    print("\n" + "="*70)
    print("  K-LD2 ASCII Protocol Reader")
    print("  Using correct protocol from datasheet")
    print("="*70)

    port = '/dev/serial0'

    # First, test different baud rates to find the right one
    print("\nStep 1: Find correct baud rate...")
    correct_baud = test_different_baudrates(port)

    if correct_baud:
        print(f"\n✓✓✓ Found working baud rate: {correct_baud} ✓✓✓")
        baudrate = correct_baud
    else:
        print("\nNo valid response at any baud rate, defaulting to 38400 (datasheet default)")
        baudrate = 38400

    try:
        # Open serial port
        ser = serial.Serial(port=port, baudrate=baudrate, timeout=0.5)
        print(f"\n✓ Connected to {port} at {baudrate} baud\n")

        # Test basic commands
        results = test_basic_commands(ser)

        # Decode detection register if available
        if results.get('$R00'):
            reg_val = results['$R00'].replace('@R00', '').strip()
            decoded = decode_detection_register(reg_val)
            if decoded:
                print("\n" + "="*70)
                print("Detection Register Decoded:")
                print("="*70)
                for key, val in decoded.items():
                    print(f"  {key}: {val}")

        # Listen for continuous data
        read_continuous_data(ser, duration=3)

        # Analyze the mystery bytes from your output
        print("\n" + "="*70)
        print("Analyzing Original Mystery Response")
        print("="*70)
        mystery = "00 3C 1C 3C E0 1C FC 1C 00 E0 00"
        analyze_mystery_bytes(mystery)

        ser.close()

        print("\n" + "="*70)
        print("ANALYSIS COMPLETE")
        print("="*70)
        print("""
If you got '@' responses:
  ✓ Sensor is working with ASCII protocol
  - Use commands like $R00, $F00, etc.
  - Update other scripts to use ASCII protocol

If no '@' responses:
  - Sensor might be in wrong mode
  - Try power cycling the sensor
  - Check TX/RX wiring (K-LD2 TX→Pi RX, K-LD2 RX→Pi TX)
  - Sensor might need configuration via Windows tool first
        """)

    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
