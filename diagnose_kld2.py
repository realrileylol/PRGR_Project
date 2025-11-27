#!/usr/bin/env python3
"""
K-LD2 Full Diagnostic - Check all sensor settings
"""
import serial
import time

def send_command(ser, command):
    """Send command and get response"""
    if not command.endswith('\r'):
        command += '\r'

    ser.reset_input_buffer()
    ser.write(command.encode('ascii'))
    time.sleep(0.1)

    if ser.in_waiting > 0:
        response = ser.read(ser.in_waiting)
        try:
            return response.decode('ascii', errors='ignore').strip()
        except:
            return None
    return None

def main():
    print("\n" + "="*70)
    print("  K-LD2 Full Diagnostic")
    print("="*70)

    port = '/dev/serial0'
    baudrate = 38400

    try:
        ser = serial.Serial(port=port, baudrate=baudrate, timeout=0.5)
        print(f"\nConnected to {port} at {baudrate} baud\n")

        commands = [
            ("$F00", "Firmware version"),
            ("$F01", "Device type"),
            ("$R04", "Operation state (0=startup, 1=learn, 2=run)"),
            ("$R00", "Detection register"),
            ("$R03", "Noise level"),
            ("$S04", "Sampling rate"),
            ("$D01", "Sensitivity (0-9)"),
            ("$D00", "Hold time"),
            ("$C00", "Detection string"),
        ]

        print("Current Sensor Settings:")
        print("-" * 70)

        for cmd, desc in commands:
            response = send_command(ser, cmd)
            if response:
                print(f"{desc:40s} {cmd:8s} → {response}")
            else:
                print(f"{desc:40s} {cmd:8s} → NO RESPONSE")

        print("\n" + "="*70)
        print("Recommendations:")
        print("="*70)

        # Check operation state
        state_resp = send_command(ser, "$R04")
        if state_resp:
            state = state_resp.replace('@R04', '').strip()
            if state != '02':
                print(f"⚠️  Sensor not in RUN mode (current: {state}, should be: 02)")
                print("   Try power cycling the sensor")

        # Check sensitivity
        sens_resp = send_command(ser, "$D01")
        if sens_resp:
            sens = sens_resp.replace('@D01', '').strip()
            try:
                sens_val = int(sens)
                if sens_val < 7:
                    print(f"⚠️  Sensitivity is {sens_val} (recommend 9 for far-field)")
            except:
                pass

        # Check noise level
        noise_resp = send_command(ser, "$R03")
        if noise_resp:
            noise = noise_resp.replace('@R03', '').strip()
            print(f"\nℹ️  Current noise level: {noise}")
            print("   High noise can interfere with detection")

        ser.close()

    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
