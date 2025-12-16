#!/usr/bin/env python3
"""
Test script to find the correct K-LD2 commands
"""
import serial
import time

def test_command(ser, command, description):
    """Send a command and print the response"""
    print(f"\n{'='*60}")
    print(f"Testing: {description}")
    print(f"Command: {command}")
    print('='*60)

    # Clear any pending data
    if ser.in_waiting > 0:
        ser.read(ser.in_waiting)

    # Send command
    ser.write(command)
    time.sleep(0.5)

    # Read response
    if ser.in_waiting > 0:
        response = ser.read(ser.in_waiting)
        print(f"Response (raw bytes): {response}")
        print(f"Response (decoded): {response.decode('ascii', errors='ignore')}")
    else:
        print("No response received")

    # Listen for continuous data for 3 seconds
    print("\nListening for continuous data (3 seconds)...")
    start_time = time.time()
    data_count = 0
    while time.time() - start_time < 3:
        if ser.in_waiting > 0:
            data = ser.read(ser.in_waiting)
            data_count += 1
            print(f"Data #{data_count}: {data}")
            print(f"Decoded: {data.decode('ascii', errors='ignore')}")
        time.sleep(0.1)

    if data_count == 0:
        print("No continuous data received")

# Connect to K-LD2
print("Connecting to K-LD2 on /dev/serial0 @ 38400 baud...")
ser = serial.Serial('/dev/serial0', baudrate=38400, timeout=1)
print("Connected!")

# Test different commands
commands_to_test = [
    (b'$S0405\r\n', 'Set 20480 Hz sampling rate'),
    (b'$S00\r\n', 'Start streaming (S00)'),
    (b'$C00\r\n', 'Get speed/magnitude (C00)'),
    (b'$R00\r\n', 'Check detection (R00)'),
    (b'$S01\r\n', 'Start streaming (S01)'),
    (b'$S0200\r\n', 'Start streaming (S0200)'),
]

for cmd, desc in commands_to_test:
    test_command(ser, cmd, desc)

    # Ask if we should continue
    response = input("\nContinue to next command? (y/n, or 's' to swing and test): ").lower()
    if response == 'n':
        break
    elif response == 's':
        print("\n*** SWING NOW! Listening for 10 seconds... ***")
        start_time = time.time()
        while time.time() - start_time < 10:
            if ser.in_waiting > 0:
                data = ser.read(ser.in_waiting)
                print(f"SWING DATA: {data}")
                print(f"Decoded: {data.decode('ascii', errors='ignore')}")
            time.sleep(0.05)

ser.close()
print("\nTest complete!")
