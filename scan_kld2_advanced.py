#!/usr/bin/env python3
"""Advanced K-LD2 Modbus Scanner - Try multiple function codes and ranges"""
import serial
import time
import struct

def calculate_modbus_crc(data):
    """Calculate Modbus RTU CRC16"""
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 0x0001:
                crc = (crc >> 1) ^ 0xA001
            else:
                crc >>= 1
    return crc

def create_modbus_command(function_code, address, num_registers=1):
    """Create Modbus RTU read command"""
    frame = bytearray([
        0x01,                    # Slave ID
        function_code,           # Function code
        (address >> 8) & 0xFF,   # Register address high byte
        address & 0xFF,          # Register address low byte
        (num_registers >> 8) & 0xFF,
        num_registers & 0xFF
    ])

    crc = calculate_modbus_crc(frame)
    frame.append(crc & 0xFF)
    frame.append((crc >> 8) & 0xFF)

    return bytes(frame)

def scan_with_function_code(ser, function_code, name):
    """Scan registers using specific Modbus function code"""

    print(f"\n{'='*70}")
    print(f"Scanning with Function Code 0x{function_code:02X} ({name})")
    print('='*70)

    # Extended register ranges
    register_ranges = [
        (0x0000, 0x0020),  # 0-31
        (0x0020, 0x0040),  # 32-63
        (0x0040, 0x0060),  # 64-95
        (0x0100, 0x0120),  # 256-287
        (0x1000, 0x1020),  # 4096-4127
    ]

    results = {}

    # First pass
    print("\nPass 1: Reading all registers...")
    for start, end in register_ranges:
        for addr in range(start, end):
            cmd = create_modbus_command(function_code, addr, 1)

            ser.reset_input_buffer()
            ser.write(cmd)
            time.sleep(0.05)

            if ser.in_waiting > 0:
                response = ser.read(ser.in_waiting)

                # Check for valid response
                if len(response) >= 5 and response[0] == 0x01 and response[1] == function_code:
                    byte_count = response[2]
                    if len(response) >= 3 + byte_count + 2:
                        data = response[3:3+byte_count]
                        results[addr] = data

                        hex_data = ' '.join([f'{b:02X}' for b in data])

                        # Decode as uint16
                        if len(data) == 2:
                            uint16 = struct.unpack('>H', data)[0]
                            int16 = struct.unpack('>h', data)[0]
                            if addr % 8 == 0:  # Print every 8th to reduce clutter
                                print(f"  0x{addr:04X}: {hex_data}  (u16={uint16:5d}, i16={int16:6d})")

            time.sleep(0.02)

    if not results:
        print("  No valid responses")
        return []

    print(f"\nFound {len(results)} readable registers")

    # Second pass - detect changes
    print("\n" + "="*70)
    print("Pass 2: Detecting changes...")
    print("WAVE YOUR HAND IN FRONT OF THE SENSOR NOW!")
    print("="*70)

    time.sleep(2)

    changing = []

    for addr in results.keys():
        cmd = create_modbus_command(function_code, addr, 1)

        ser.reset_input_buffer()
        ser.write(cmd)
        time.sleep(0.05)

        if ser.in_waiting > 0:
            response = ser.read(ser.in_waiting)

            if len(response) >= 5 and response[0] == 0x01 and response[1] == function_code:
                byte_count = response[2]
                if len(response) >= 3 + byte_count + 2:
                    new_data = response[3:3+byte_count]

                    if new_data != results[addr]:
                        changing.append(addr)

                        old_hex = ' '.join([f'{b:02X}' for b in results[addr]])
                        new_hex = ' '.join([f'{b:02X}' for b in new_data])

                        # Decode as integers
                        if len(new_data) == 2 and len(results[addr]) == 2:
                            old_uint = struct.unpack('>H', results[addr])[0]
                            new_uint = struct.unpack('>H', new_data)[0]
                            diff = new_uint - old_uint
                            print(f"  CHANGED! 0x{addr:04X}: {old_uint} -> {new_uint} (diff: {diff:+d})")
                        else:
                            print(f"  CHANGED! 0x{addr:04X}: {old_hex} -> {new_hex}")

        time.sleep(0.02)

    return changing

def try_initialization_commands(ser):
    """Try various commands that might enable measurement mode"""

    print("\n" + "="*70)
    print("Trying initialization/trigger commands...")
    print("="*70)

    # Common radar sensor commands
    init_commands = [
        (b'\x01\x06\x00\x00\x00\x01\x48\x0A', "Write single register - Start"),
        (b'\x01\x10\x00\x00\x00\x01\x02\x00\x01\xB8\x44', "Write multiple - Enable continuous"),
        (b'\xAA\x55\x00\x01', "Start measurement (radar common)"),
    ]

    for cmd, desc in init_commands:
        hex_str = ' '.join([f'{b:02X}' for b in cmd])
        print(f"\nSending: {desc}")
        print(f"  Command: {hex_str}")

        ser.reset_input_buffer()
        ser.write(cmd)
        time.sleep(0.2)

        if ser.in_waiting > 0:
            response = ser.read(ser.in_waiting)
            hex_resp = ' '.join([f'{b:02X}' for b in response])
            print(f"  Response: {hex_resp}")
        else:
            print("  No response")

def main():
    print("\n=== K-LD2 Advanced Modbus Scanner ===")
    print("Testing multiple function codes and initialization sequences\n")

    try:
        ser = serial.Serial(port='/dev/serial0', baudrate=115200, timeout=0.5)
        print(f"Connected to K-LD2 at 115200 baud\n")

        # Try initialization commands first
        try_initialization_commands(ser)

        time.sleep(1)

        # Try both function codes
        function_codes = [
            (0x03, "Read Holding Registers"),
            (0x04, "Read Input Registers"),
        ]

        all_changing = {}

        for func_code, name in function_codes:
            changing = scan_with_function_code(ser, func_code, name)
            if changing:
                all_changing[name] = changing

        # Final summary
        print("\n\n" + "="*70)
        print("FINAL RESULTS:")
        print("="*70)

        if all_changing:
            for func_name, addrs in all_changing.items():
                print(f"\n{func_name}:")
                for addr in addrs:
                    print(f"  - 0x{addr:04X} (decimal {addr})")
            print("\nUpdate kld2_reader.py to use these registers!")
        else:
            print("\nNo changing registers found with any function code.")
            print("\nPossible next steps:")
            print("1. Sensor may need Windows configuration tool first")
            print("2. Try reading multiple consecutive registers at once")
            print("3. Sensor might use proprietary protocol, not standard Modbus")
            print("4. Check if sensor has physical mode switch or button")

        ser.close()

    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
