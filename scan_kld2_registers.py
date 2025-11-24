#!/usr/bin/env python3
"""K-LD2 Modbus Register Scanner - Find measurement data registers"""
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

def create_modbus_read_command(address, num_registers=1):
    """Create Modbus RTU read holding registers command (function code 0x03)"""
    # Modbus frame: [slave_id, function, addr_hi, addr_lo, count_hi, count_lo]
    frame = bytearray([
        0x01,                    # Slave ID
        0x03,                    # Function code: Read Holding Registers
        (address >> 8) & 0xFF,   # Register address high byte
        address & 0xFF,          # Register address low byte
        (num_registers >> 8) & 0xFF,  # Number of registers high byte
        num_registers & 0xFF     # Number of registers low byte
    ])

    # Calculate and append CRC
    crc = calculate_modbus_crc(frame)
    frame.append(crc & 0xFF)         # CRC low byte
    frame.append((crc >> 8) & 0xFF)  # CRC high byte

    return bytes(frame)

def scan_registers(port='/dev/serial0', baudrate=115200):
    """Scan Modbus registers to find measurement data"""

    print("\n=== K-LD2 Modbus Register Scanner ===")
    print("Scanning for registers with changing values (motion/distance data)\n")

    try:
        ser = serial.Serial(port=port, baudrate=baudrate, timeout=0.5)
        print(f"Connected to K-LD2 at {baudrate} baud\n")

        # Registers to scan - common ranges for sensor data
        register_ranges = [
            (0x0000, 0x0010, "Status/Config"),     # 0-15
            (0x0010, 0x0020, "Measurement A"),     # 16-31
            (0x0020, 0x0030, "Measurement B"),     # 32-47
            (0x0030, 0x0040, "Measurement C"),     # 48-63
            (0x0100, 0x0110, "Extended Range"),    # 256-271
        ]

        results = {}

        # First pass - read all registers
        print("Pass 1: Reading all registers...")
        for start, end, name in register_ranges:
            print(f"\nScanning {name} (0x{start:04X}-0x{end-1:04X}):")
            for addr in range(start, end):
                cmd = create_modbus_read_command(addr, 1)

                ser.reset_input_buffer()
                ser.write(cmd)
                time.sleep(0.05)

                if ser.in_waiting > 0:
                    response = ser.read(ser.in_waiting)

                    # Valid response should be at least 7 bytes
                    # [slave, func, byte_count, data..., crc_lo, crc_hi]
                    if len(response) >= 7 and response[0] == 0x01 and response[1] == 0x03:
                        byte_count = response[2]
                        data = response[3:3+byte_count]
                        hex_data = ' '.join([f'{b:02X}' for b in data])

                        # Store for comparison
                        results[addr] = data

                        # Decode as different types
                        if len(data) == 2:
                            uint16 = struct.unpack('>H', data)[0]
                            int16 = struct.unpack('>h', data)[0]
                            print(f"  0x{addr:04X}: {hex_data}  (uint16={uint16}, int16={int16})")
                        else:
                            print(f"  0x{addr:04X}: {hex_data}")

                time.sleep(0.02)

        # Second pass - detect changes
        print("\n\n" + "="*60)
        print("Pass 2: Detecting changing registers...")
        print("Wave your hand in front of the sensor NOW!")
        print("="*60 + "\n")

        time.sleep(2)  # Give user time to start waving

        changing_registers = []

        for addr in results.keys():
            cmd = create_modbus_read_command(addr, 1)

            ser.reset_input_buffer()
            ser.write(cmd)
            time.sleep(0.05)

            if ser.in_waiting > 0:
                response = ser.read(ser.in_waiting)

                if len(response) >= 7 and response[0] == 0x01 and response[1] == 0x03:
                    byte_count = response[2]
                    new_data = response[3:3+byte_count]

                    # Compare with first reading
                    if new_data != results[addr]:
                        changing_registers.append(addr)
                        old_hex = ' '.join([f'{b:02X}' for b in results[addr]])
                        new_hex = ' '.join([f'{b:02X}' for b in new_data])
                        print(f"CHANGED! 0x{addr:04X}: {old_hex} -> {new_hex}")

            time.sleep(0.02)

        # Summary
        print("\n\n" + "="*60)
        print("RESULTS:")
        print("="*60)

        if changing_registers:
            print(f"\nFound {len(changing_registers)} register(s) with changing values:")
            for addr in changing_registers:
                print(f"  - 0x{addr:04X} (decimal {addr})")
            print("\nThese registers likely contain motion/distance measurements!")
            print("Update kld2_reader.py to read these registers.")
        else:
            print("\nNo changing registers detected.")
            print("Possible reasons:")
            print("  1. Sensor may need calibration or initialization sequence")
            print("  2. Different Modbus function code needed (try 0x04 Input Registers)")
            print("  3. Sensor requires specific trigger command before measuring")
            print("  4. Data may be in registers outside scanned range")

        ser.close()

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    scan_registers()
