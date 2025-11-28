#!/usr/bin/env python3
"""
K-LD2 Frame Capture Diagnostic
Captures detailed frame-by-frame data during motion to diagnose speed ceiling issue
"""
import serial
import time
import csv
from datetime import datetime

def send_command(ser, command):
    """Send command and get response"""
    if not command.endswith('\r'):
        command += '\r'

    ser.reset_input_buffer()
    ser.write(command.encode('ascii'))
    time.sleep(0.05)

    if ser.in_waiting > 0:
        response = ser.read(ser.in_waiting)
        try:
            return response.decode('ascii', errors='ignore').strip()
        except:
            return None
    return None

def parse_detection_string(response, sampling_rate=2560):
    """Parse $C00 response and return detailed info"""
    try:
        if not response:
            return None

        # Handle both formats: "@C00001;076;067;" or "001;076;067;"
        data = response
        if response.startswith('@C00'):
            data = response[4:].strip()

        # Split by semicolon - format is "detection_register;speed_bin;magnitude_dB;"
        values = data.split(';')

        if len(values) < 3:
            return None

        detection_reg = values[0]
        speed_bin = int(values[1])
        magnitude_db = int(values[2])

        # Parse detection register bits
        reg_val = int(detection_reg, 16) if detection_reg else 0
        detected = (reg_val & 0x01) != 0
        direction = "approaching" if (reg_val & 0x02) else "receding"
        speed_range = "high" if (reg_val & 0x04) else "low"
        micro = (reg_val & 0x08) != 0

        # Calculate speed
        doppler_hz = speed_bin * (sampling_rate / 256.0)
        speed_kmh = doppler_hz / 44.7
        speed_mph = speed_kmh * 0.621371

        return {
            'raw_response': response,
            'detection_reg': detection_reg,
            'detected': detected,
            'direction': direction,
            'speed_range': speed_range,
            'micro': micro,
            'speed_bin': speed_bin,
            'magnitude_db': magnitude_db,
            'doppler_hz': doppler_hz,
            'speed_kmh': speed_kmh,
            'speed_mph': abs(speed_mph)
        }

    except Exception as e:
        print(f"Parse error: {e}")
        return None

def main():
    print("\n" + "="*80)
    print("  K-LD2 FRAME CAPTURE DIAGNOSTIC")
    print("  Logs raw sensor data frame-by-frame to diagnose speed ceiling")
    print("="*80)

    port = '/dev/serial0'
    baudrate = 38400

    try:
        ser = serial.Serial(port=port, baudrate=baudrate, timeout=0.5)
        print(f"\nConnected to {port} at {baudrate} baud\n")

        # Configure sensor
        print("Configuring sensor...")

        # Set direction to BOTH
        dir_resp = send_command(ser, "$R02=2")
        print(f"Direction mode: {dir_resp}")

        # Set sensitivity to 9
        sens_resp = send_command(ser, "$D01=9")
        print(f"Sensitivity: {sens_resp}")

        # Set hold time to 0
        hold_resp = send_command(ser, "$D00=0")
        print(f"Hold time: {hold_resp}")

        # Get sampling rate
        samp_resp = send_command(ser, "$S04")
        sampling_rate = 2560  # Default
        if samp_resp and samp_resp.startswith('@S04'):
            samp_val = samp_resp[4:].strip()
            if samp_val == '02':
                sampling_rate = 2560
            elif samp_val == '01':
                sampling_rate = 1280
            print(f"Sampling rate: {sampling_rate} Hz (raw: {samp_val})")

        print("\n" + "="*80)
        print("READY - Start swinging! (Ctrl+C to stop)")
        print("="*80 + "\n")

        # Prepare CSV file
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        csv_filename = f"/home/user/PRGR_Project/radar_capture_{timestamp}.csv"

        csv_file = open(csv_filename, 'w', newline='')
        csv_writer = csv.writer(csv_file)
        csv_writer.writerow([
            'timestamp_ms',
            'detection_reg',
            'detected',
            'direction',
            'speed_range',
            'micro',
            'speed_bin',
            'magnitude_db',
            'doppler_hz',
            'speed_kmh',
            'speed_mph',
            'raw_response'
        ])

        start_time = time.time()
        frame_count = 0
        detection_count = 0
        max_speed = 0.0
        max_bin = 0

        try:
            while True:
                # Poll at ~100 Hz
                poll_start = time.time()

                # Check detection register
                det_reg_resp = send_command(ser, "$R00")

                # Get detection string
                speed_resp = send_command(ser, "$C00")

                if speed_resp:
                    frame = parse_detection_string(speed_resp, sampling_rate)

                    if frame:
                        timestamp_ms = (time.time() - start_time) * 1000

                        # Write to CSV
                        csv_writer.writerow([
                            f"{timestamp_ms:.1f}",
                            frame['detection_reg'],
                            frame['detected'],
                            frame['direction'],
                            frame['speed_range'],
                            frame['micro'],
                            frame['speed_bin'],
                            frame['magnitude_db'],
                            f"{frame['doppler_hz']:.2f}",
                            f"{frame['speed_kmh']:.2f}",
                            f"{frame['speed_mph']:.2f}",
                            frame['raw_response']
                        ])

                        frame_count += 1

                        # Track detection
                        if frame['detected'] and frame['speed_mph'] >= 1.0:
                            detection_count += 1

                            # Track max
                            if frame['speed_mph'] > max_speed:
                                max_speed = frame['speed_mph']
                            if frame['speed_bin'] > max_bin:
                                max_bin = frame['speed_bin']

                            # Print live detections
                            print(f"⚡ {timestamp_ms:8.0f}ms | "
                                  f"BIN={frame['speed_bin']:3d} | "
                                  f"MAG={frame['magnitude_db']:3d}dB | "
                                  f"SPEED={frame['speed_mph']:6.2f} mph | "
                                  f"{frame['direction']:10s} | "
                                  f"{frame['speed_range']:4s}")

                        # Periodic status update (every 1000 frames)
                        if frame_count % 1000 == 0:
                            elapsed = time.time() - start_time
                            print(f"\n📊 STATUS: {frame_count} frames, {detection_count} detections, "
                                  f"max={max_speed:.1f} mph (bin={max_bin}), "
                                  f"{elapsed:.1f}s elapsed\n")

                # Poll at ~100 Hz
                elapsed = time.time() - poll_start
                sleep_time = max(0.01 - elapsed, 0.001)
                time.sleep(sleep_time)

        except KeyboardInterrupt:
            print("\n\n" + "="*80)
            print("  CAPTURE COMPLETE")
            print("="*80)
            print(f"\nTotal frames captured: {frame_count}")
            print(f"Detections logged: {detection_count}")
            print(f"Maximum speed: {max_speed:.2f} mph (bin={max_bin})")
            print(f"Doppler frequency at max: {max_bin * (sampling_rate / 256.0):.1f} Hz")
            print(f"\nData saved to: {csv_filename}")
            print("\nYou can analyze this CSV to see:")
            print("  - Raw bin values (should be 200+ for 40+ mph)")
            print("  - Magnitude patterns during swing")
            print("  - Direction changes")
            print("  - Timestamp progression")

            csv_file.close()

    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
