#!/usr/bin/env python3
"""Debug K-LD2 LiDAR connection issues"""
import serial
import serial.tools.list_ports
import time
import os

def list_serial_ports():
    """List all available serial ports"""
    print("=== Available Serial Ports ===")
    ports = serial.tools.list_ports.comports()
    for port in ports:
        print(f"  {port.device} - {port.description}")

    # Also check common RPi serial devices
    common_ports = ['/dev/serial0', '/dev/ttyAMA0', '/dev/ttyS0', '/dev/ttyUSB0']
    print("\n=== Checking Common RPi Ports ===")
    for port in common_ports:
        exists = os.path.exists(port)
        print(f"  {port}: {'EXISTS' if exists else 'NOT FOUND'}")
    print()

def check_uart_config():
    """Check UART configuration"""
    print("=== UART Configuration ===")

    # Check if serial console is disabled
    try:
        with open('/boot/cmdline.txt', 'r') as f:
            cmdline = f.read()
            has_console = 'console=serial0' in cmdline or 'console=ttyAMA0' in cmdline
            print(f"  Serial console in cmdline.txt: {'ENABLED (BAD)' if has_console else 'DISABLED (GOOD)'}")
    except:
        print("  Could not read /boot/cmdline.txt")

    # Check config.txt
    try:
        with open('/boot/config.txt', 'r') as f:
            config = f.read()
            has_uart = 'enable_uart=1' in config
            print(f"  enable_uart in config.txt: {'YES (GOOD)' if has_uart else 'NO (BAD)'}")
    except:
        print("  Could not read /boot/config.txt")
    print()

def test_port_raw(port='/dev/serial0', baudrate=115200, duration=5):
    """Test port with raw byte reading"""
    print(f"=== Testing {port} at {baudrate} baud ===")
    print(f"Reading for {duration} seconds...\n")

    try:
        ser = serial.Serial(
            port=port,
            baudrate=baudrate,
            timeout=0.1
        )

        print(f"✓ Port opened")
        print(f"  DSR: {ser.dsr}")
        print(f"  CTS: {ser.cts}")
        print(f"  RI: {ser.ri}")
        print(f"  CD: {ser.cd}")
        print()

        ser.reset_input_buffer()

        start = time.time()
        bytes_received = 0

        while (time.time() - start) < duration:
            if ser.in_waiting > 0:
                data = ser.read(ser.in_waiting)
                bytes_received += len(data)
                hex_str = ' '.join([f'{b:02X}' for b in data])
                ascii_str = ''.join([chr(b) if 32 <= b < 127 else '.' for b in data])
                print(f"[{time.time()-start:.2f}s] {len(data)} bytes: {hex_str}")
                print(f"         ASCII: {ascii_str}")
            time.sleep(0.1)

        ser.close()
        print(f"\nTotal bytes received: {bytes_received}")
        return bytes_received > 0

    except Exception as e:
        print(f"✗ Error: {e}")
        return False

def send_config_commands(port='/dev/serial0', baudrate=115200):
    """Try sending configuration commands to K-LD2"""
    print(f"=== Sending Config Commands to {port} ===\n")

    # Common K-LD2/HLK-LD2 commands (these vary by model)
    commands = [
        b'\x01\x03\x00\x00\x00\x01\x84\x0A',  # Read register
        b'AT\r\n',  # AT command
    ]

    try:
        ser = serial.Serial(port=port, baudrate=baudrate, timeout=1)

        for i, cmd in enumerate(commands):
            print(f"Sending command {i+1}: {' '.join([f'{b:02X}' for b in cmd])}")
            ser.write(cmd)
            time.sleep(0.5)

            if ser.in_waiting > 0:
                response = ser.read(ser.in_waiting)
                print(f"  Response: {' '.join([f'{b:02X}' for b in response])}")
            else:
                print(f"  No response")
            print()

        ser.close()

    except Exception as e:
        print(f"✗ Error: {e}")

if __name__ == "__main__":
    print("K-LD2 LiDAR Debug Tool\n")

    # Step 1: List ports
    list_serial_ports()

    # Step 2: Check UART config
    check_uart_config()

    # Step 3: Test primary port
    ports_to_test = [
        ('/dev/serial0', 115200),
        ('/dev/ttyAMA0', 115200),
        ('/dev/ttyS0', 115200),
        ('/dev/serial0', 256000),
        ('/dev/serial0', 9600),
    ]

    for port, baud in ports_to_test:
        if os.path.exists(port):
            if test_port_raw(port, baud, duration=3):
                print(f"\n✓✓✓ SUCCESS! Data received on {port} at {baud} baud ✓✓✓\n")
                break
            print()

    # Step 4: Try sending commands
    if os.path.exists('/dev/serial0'):
        send_config_commands('/dev/serial0')

    print("\n=== Troubleshooting Tips ===")
    print("1. Check wiring:")
    print("   - K-LD2 TX → Pi RX (GPIO15, Pin 10)")
    print("   - K-LD2 RX → Pi TX (GPIO14, Pin 8)")
    print("   - K-LD2 VCC → Pi 5V (Pin 2 or 4)")
    print("   - K-LD2 GND → Pi GND (Pin 6)")
    print()
    print("2. Disable serial console:")
    print("   sudo raspi-config")
    print("   Interface Options → Serial Port")
    print("   Login shell: NO, Hardware: YES")
    print()
    print("3. Try swapping TX/RX wires if still no data")
    print()
    print("4. Check if K-LD2 LED is blinking (indicates it's powered)")
