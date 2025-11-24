#!/usr/bin/env python3
"""
Enhanced K-LD2 Protocol Diagnostic Tool
Identifies why sensor returns same response to all commands
"""
import serial
import time
import struct

def analyze_response_pattern(response):
    """Analyze if response looks like noise, echo, or valid data"""
    if not response:
        return "NO_DATA"

    # Check for all zeros or all 0xFF (common noise patterns)
    if all(b == 0x00 for b in response):
        return "ALL_ZEROS"
    if all(b == 0xFF for b in response):
        return "ALL_ONES"

    # Check for repeating pattern
    if len(response) >= 4:
        if response[:2] == response[2:4]:
            return "REPEATING_PATTERN"

    # Check for ASCII (might be in text mode)
    if all(32 <= b < 127 for b in response):
        return f"ASCII_TEXT: {response.decode('ascii')}"

    # Check for valid Modbus
    if len(response) >= 5 and response[0] == 0x01 and response[1] in [0x03, 0x04, 0x06, 0x10]:
        return "VALID_MODBUS"

    return "UNKNOWN_DATA"

def test_echo(ser):
    """Test if device is echoing back commands"""
    print("\n" + "="*70)
    print("TEST 1: Check for Echo/Loopback")
    print("="*70)

    test_patterns = [
        b'\xAA\xAA\xAA\xAA',
        b'\x55\x55\x55\x55',
        b'\x12\x34\x56\x78',
    ]

    for pattern in test_patterns:
        ser.reset_input_buffer()
        ser.write(pattern)
        time.sleep(0.1)

        if ser.in_waiting > 0:
            response = ser.read(ser.in_waiting)
            hex_sent = ' '.join([f'{b:02X}' for b in pattern])
            hex_recv = ' '.join([f'{b:02X}' for b in response])

            if response == pattern:
                print(f"⚠ ECHO DETECTED! Sent = Received")
                print(f"  Sent:     {hex_sent}")
                print(f"  Received: {hex_recv}")
                return True
            else:
                print(f"  Sent:     {hex_sent}")
                print(f"  Received: {hex_recv}")
                if response == b'\x00\x3C\x1C\x3C\xE0\x1C\xFC\x1C\x00\xE0\x00':
                    print(f"  ⚠ Same response as before!")

    return False

def test_continuous_output(ser, duration=3):
    """Check if sensor outputs data continuously without commands"""
    print("\n" + "="*70)
    print(f"TEST 2: Continuous Output (listening for {duration}s)")
    print("="*70)
    print("Not sending anything, just listening...\n")

    ser.reset_input_buffer()
    start = time.time()
    received_data = []

    while (time.time() - start) < duration:
        if ser.in_waiting > 0:
            data = ser.read(ser.in_waiting)
            timestamp = time.time() - start
            received_data.append((timestamp, data))
            hex_str = ' '.join([f'{b:02X}' for b in data])
            print(f"[{timestamp:.2f}s] {len(data):3d} bytes: {hex_str}")
        time.sleep(0.1)

    if received_data:
        print(f"\n✓ Sensor outputs data continuously!")
        print(f"  Total bursts: {len(received_data)}")

        # Check if all bursts are identical
        all_data = [d for _, d in received_data]
        if all(d == all_data[0] for d in all_data):
            print(f"  ⚠ All bursts are IDENTICAL (might be stuck/error state)")
        else:
            print(f"  ✓ Data is changing (good!)")

        return True
    else:
        print("  No continuous output detected")
        return False

def test_different_baudrates(port='/dev/serial0'):
    """Try different baud rates"""
    print("\n" + "="*70)
    print("TEST 3: Try Different Baud Rates")
    print("="*70)

    baudrates = [9600, 19200, 38400, 57600, 115200, 230400, 256000, 460800]

    for baud in baudrates:
        try:
            print(f"\nTrying {baud} baud...")
            ser = serial.Serial(port=port, baudrate=baud, timeout=0.5)
            ser.reset_input_buffer()

            # Send Modbus read command
            cmd = b'\x01\x03\x00\x00\x00\x01\x84\x0A'
            ser.write(cmd)
            time.sleep(0.2)

            if ser.in_waiting > 0:
                response = ser.read(ser.in_waiting)
                hex_resp = ' '.join([f'{b:02X}' for b in response])
                analysis = analyze_response_pattern(response)

                print(f"  Response: {hex_resp}")
                print(f"  Analysis: {analysis}")

                if analysis == "VALID_MODBUS":
                    print(f"  ✓✓✓ VALID MODBUS AT {baud}! ✓✓✓")
                    ser.close()
                    return baud
            else:
                print(f"  No response")

            ser.close()
        except Exception as e:
            print(f"  Error: {e}")

    return None

def test_proprietary_protocols(ser):
    """Try K-LD2 proprietary command formats"""
    print("\n" + "="*70)
    print("TEST 4: Proprietary K-LD2 Protocol Commands")
    print("="*70)

    # Common K-LD2/HLK-LD2450 protocols
    commands = [
        # Format: (command_bytes, description)
        (b'\xFD\xFC\xFB\xFA\x02\x00\x01\x00\x04\x03\x02\x01', "K-LD2450 enable config"),
        (b'\xFD\xFC\xFB\xFA\x04\x00\x02\x01\x04\x03\x02\x01', "K-LD2450 read version"),
        (b'\xFD\xFC\xFB\xFA\x02\x00\x61\x00\x04\x03\x02\x01', "K-LD2450 start"),
        (b'\xAA\x00\x00\x00\x00\x00', "Generic radar start"),
        (b'\xFF\x00\x01\x00', "Alt start command"),
        (b'AT\r\n', "AT command (text mode)"),
        (b'AT+START\r\n', "AT start"),
        (b'read\r\n', "Text read command"),
    ]

    for cmd, desc in commands:
        print(f"\n{desc}")
        hex_cmd = ' '.join([f'{b:02X}' for b in cmd])
        print(f"  Command: {hex_cmd}")

        ser.reset_input_buffer()
        ser.write(cmd)
        time.sleep(0.3)

        if ser.in_waiting > 0:
            response = ser.read(ser.in_waiting)
            hex_resp = ' '.join([f'{b:02X}' for b in response])
            analysis = analyze_response_pattern(response)

            print(f"  Response: {hex_resp}")
            print(f"  Analysis: {analysis}")

            if response != b'\x00\x3C\x1C\x3C\xE0\x1C\xFC\x1C\x00\xE0\x00':
                print(f"  ✓ DIFFERENT RESPONSE! This might work!")
        else:
            print(f"  No response")

def test_timing_variations(ser):
    """Test if different timing helps"""
    print("\n" + "="*70)
    print("TEST 5: Timing Variations")
    print("="*70)

    cmd = b'\x01\x03\x00\x00\x00\x01\x84\x0A'  # Modbus read

    delays = [0.01, 0.05, 0.1, 0.5, 1.0]

    for delay in delays:
        print(f"\nDelay: {delay}s")
        ser.reset_input_buffer()
        ser.write(cmd)
        time.sleep(delay)

        if ser.in_waiting > 0:
            response = ser.read(ser.in_waiting)
            hex_resp = ' '.join([f'{b:02X}' for b in response])
            print(f"  Response: {hex_resp}")
            print(f"  Bytes: {len(response)}")

def decode_mystery_response(response):
    """Try to decode the mystery response pattern"""
    print("\n" + "="*70)
    print("TEST 6: Decode Mystery Response")
    print("="*70)

    hex_str = ' '.join([f'{b:02X}' for b in response])
    print(f"Response: {hex_str}")
    print(f"Length: {len(response)} bytes\n")

    # Try different interpretations
    print("Possible interpretations:")

    # As uint16 values (big-endian)
    print("\n1. As uint16 (big-endian):")
    for i in range(0, len(response)-1, 2):
        val = struct.unpack('>H', response[i:i+2])[0]
        print(f"   Bytes {i}-{i+1}: {val:5d} (0x{val:04X})")

    # As uint16 values (little-endian)
    print("\n2. As uint16 (little-endian):")
    for i in range(0, len(response)-1, 2):
        val = struct.unpack('<H', response[i:i+2])[0]
        print(f"   Bytes {i}-{i+1}: {val:5d} (0x{val:04X})")

    # As float
    if len(response) >= 4:
        try:
            val = struct.unpack('>f', response[:4])[0]
            print(f"\n3. First 4 bytes as float (big-endian): {val}")
            val = struct.unpack('<f', response[:4])[0]
            print(f"   First 4 bytes as float (little-endian): {val}")
        except:
            pass

    # Check for patterns
    print("\n4. Pattern analysis:")
    print(f"   Binary: {' '.join([f'{b:08b}' for b in response])}")

    # Check if it's a counter
    if len(response) > 2:
        differences = [response[i+1] - response[i] for i in range(len(response)-1)]
        print(f"   Byte differences: {differences}")

def main():
    print("\n" + "="*70)
    print("    K-LD2 Enhanced Protocol Diagnostic Tool")
    print("="*70)
    print("\nThis tool will identify why the sensor returns the same response\n")

    port = '/dev/serial0'
    baudrate = 115200

    try:
        # Open serial port
        ser = serial.Serial(port=port, baudrate=baudrate, timeout=0.5)
        print(f"✓ Connected to {port} at {baudrate} baud\n")

        # Run diagnostic tests
        test_echo(ser)
        test_continuous_output(ser)
        test_proprietary_protocols(ser)
        test_timing_variations(ser)

        # Decode the mystery response
        mystery = b'\x00\x3C\x1C\x3C\xE0\x1C\xFC\x1C\x00\xE0\x00'
        decode_mystery_response(mystery)

        ser.close()

        # Try different baudrates (this opens/closes port multiple times)
        test_different_baudrates(port)

        # Final recommendations
        print("\n" + "="*70)
        print("DIAGNOSTIC COMPLETE - RECOMMENDATIONS")
        print("="*70)
        print("""
Based on the tests above, here are the next steps:

1. If ECHO DETECTED:
   → TX and RX wires are swapped or shorted
   → Swap the TX/RX connections

2. If CONTINUOUS OUTPUT:
   → Sensor might be in streaming mode
   → Try parsing the continuous stream instead of command/response

3. If DIFFERENT RESPONSE from proprietary commands:
   → Sensor uses proprietary protocol, not Modbus
   → Use that command format instead

4. If ALL RESPONSES IDENTICAL:
   → Sensor might be in error/boot state
   → Try power cycling the sensor
   → Check if sensor needs Windows config tool first
   → Verify 5V power supply is stable

5. If NO RESPONSE at all baudrates:
   → Wiring issue (check TX→RX, RX→TX)
   → Sensor not powered (check for LED)
   → Wrong sensor model (verify it's actually K-LD2)

6. If the mystery bytes decode to meaningful numbers:
   → Sensor might be sending unsolicited data
   → Parse format shown in decode section
""")

    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
