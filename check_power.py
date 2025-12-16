#!/usr/bin/env python3
"""Check if we can measure any response from K-LD2 power pins"""
import RPi.GPIO as GPIO
import time

print("=== K-LD2 Power Diagnostic ===\n")

# Check what pins are available
print("Raspberry Pi Power Pins:")
print("  Pin 2:  5V (recommended for K-LD2 VCC)")
print("  Pin 4:  5V (alternative)")
print("  Pin 6:  GND (recommended for K-LD2 GND)")
print("  Pin 9:  GND (alternative)")
print("  Pin 14: GND (alternative)")
print()

print("UART Data Pins (after power is connected):")
print("  Pin 8:  GPIO14 (TXD) → Connect to K-LD2 RX")
print("  Pin 10: GPIO15 (RXD) → Connect to K-LD2 TX")
print()

print("=== K-LD2 Wiring Check ===")
print("Your K-LD2 should have 4 wires:")
print("  1. VCC (usually RED)    → Pi Pin 2 (5V)")
print("  2. GND (usually BLACK)  → Pi Pin 6 (GND)")
print("  3. TX  (usually WHITE)  → Pi Pin 10 (RXD/GPIO15)")
print("  4. RX  (usually GREEN)  → Pi Pin 8 (TXD/GPIO14)")
print()

print("=== Troubleshooting No LED ===")
print("If there's NO LED on the K-LD2:")
print()
print("1. POWER ISSUE - Check:")
print("   - VCC connected to 5V pin (Pin 2 or 4)?")
print("   - GND connected to GND pin (Pin 6)?")
print("   - Female connectors making good contact?")
print("   - Try wiggling the connectors")
print()
print("2. CURRENT ISSUE:")
print("   - K-LD2 draws ~100-200mA")
print("   - Pi GPIO 5V pins can supply this")
print("   - BUT check if other devices are using power")
print()
print("3. SENSOR ISSUE:")
print("   - Sensor might be damaged")
print("   - Try measuring voltage at sensor VCC pin with multimeter")
print("   - Should read ~5V")
print()
print("4. CONNECTION ISSUE:")
print("   - Female headers seated properly?")
print("   - Check for bent pins")
print("   - Try re-seating all connections")
print()

# Let's also verify the Pi's voltage output
print("=== Quick Test ===")
print("You can verify your Pi's 5V output works:")
print("  1. Disconnect K-LD2")
print("  2. Use multimeter: measure between Pin 2 (5V) and Pin 6 (GND)")
print("  3. Should read ~5V")
print()

answer = input("Do you have a multimeter to check voltage? (y/n): ")
if answer.lower() == 'y':
    print("\nMeasure between:")
    print("  - Red probe: Pin 2 (5V)")
    print("  - Black probe: Pin 6 (GND)")
    print("  - Expected: ~5.0V (4.8V - 5.2V is OK)")
    print()
    voltage = input("What voltage do you read? (or 'skip'): ")
    if voltage != 'skip':
        try:
            v = float(voltage)
            if 4.8 <= v <= 5.2:
                print(f"✓ {v}V is good! Pi power output OK")
                print("→ Problem is likely with K-LD2 connections or sensor itself")
            elif v < 4.8:
                print(f"✗ {v}V is too low! Power supply issue")
            else:
                print(f"⚠ {v}V is unusual")
        except:
            pass

print("\n=== Next Steps ===")
print("1. Verify K-LD2 VCC is connected to Pi Pin 2 (5V)")
print("2. Verify K-LD2 GND is connected to Pi Pin 6 (GND)")
print("3. Check female connectors are firmly seated")
print("4. If still no LED, sensor may be faulty or needs external power supply")
