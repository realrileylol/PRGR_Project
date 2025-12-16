#!/usr/bin/env python3
"""
Test advanced K-LD2 commands to find directional data
"""
import serial
import time

def test_advanced_command(ser, command, description):
    """Send command and show response"""
    print(f"\n{'='*60}")
    print(f"Testing: {description}")
    print(f"Command: {command}")
    print('='*60)

    ser.write(command)
    time.sleep(0.3)

    if ser.in_waiting > 0:
        response = ser.read(ser.in_waiting)
        print(f"Response: {response}")
        print(f"Decoded: {response.decode('ascii', errors='ignore')}")
    else:
        print("No response")

# Connect
print("Connecting to K-LD2...")
ser = serial.Serial('/dev/serial0', baudrate=38400, timeout=1)
print("Connected!\n")

# Set 20480 Hz first
ser.write(b'$S0405\r\n')
time.sleep(0.3)
ser.read(ser.in_waiting)

# Test advanced commands
commands = [
    (b'$I00\r\n', 'Get I/Q data (raw quadrature samples)'),
    (b'$F00\r\n', 'Get frequency shift'),
    (b'$D00\r\n', 'Get direction'),
    (b'$V00\r\n', 'Get velocity (might be signed)'),
    (b'$M00\r\n', 'Get motion data'),
    (b'$T00\r\n', 'Get target info'),
    (b'$A00\r\n', 'Get all data'),
    (b'$R01\r\n', 'Get detection with extended info'),
    (b'$C01\r\n', 'Get speed with direction flag'),
]

for cmd, desc in commands:
    test_advanced_command(ser, cmd, desc)

    # Try moving club and see if response changes
    input("\nMove club TOWARD radar, press Enter...")
    test_advanced_command(ser, cmd, f"{desc} (APPROACHING)")

    input("Move club AWAY from radar, press Enter...")
    test_advanced_command(ser, cmd, f"{desc} (RECEDING)")

    cont = input("\nContinue to next command? (y/n): ")
    if cont.lower() != 'y':
        break

ser.close()
print("\nDone!")
