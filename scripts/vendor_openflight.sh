#!/usr/bin/env bash
# Vendor the radar driver code from OpenFlight into radar/openflight/
# Run this once after cloning PRGR_Project to populate the radar subsystem.
#
# OpenFlight is AGPL-3.0 licensed. The vendored code lives in radar/openflight/
# and is clearly attributed. See radar/LICENSE_OPENFLIGHT for the full license.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RADAR_DIR="$SCRIPT_DIR/../radar/openflight"
TMP_DIR=$(mktemp -d)

echo "=== Vendoring OpenFlight radar drivers ==="

# Clone only the files we need (shallow, no history)
git clone --depth 1 --filter=blob:none --sparse \
    https://github.com/jewbetcha/openflight.git "$TMP_DIR/openflight"

cd "$TMP_DIR/openflight"
git sparse-checkout set src/openflight

# Copy radar driver files (not server.py, camera_tracker.py, cloud/, gspro/, sim/)
echo "Copying core radar modules..."

# Top-level modules
for f in ops243.py launch_monitor.py ballistics.py spin_estimate.py \
         speed_correction.py session_logger.py serial_latency.py __init__.py; do
    if [ -f "src/openflight/$f" ]; then
        cp "src/openflight/$f" "$RADAR_DIR/$f"
        echo "  ✓ $f"
    fi
done

# K-LD7 package
echo "Copying kld7/ package..."
cp -r src/openflight/kld7/* "$RADAR_DIR/kld7/"
echo "  ✓ kld7/"

# Rolling buffer package
echo "Copying rolling_buffer/ package..."
cp -r src/openflight/rolling_buffer/* "$RADAR_DIR/rolling_buffer/"
echo "  ✓ rolling_buffer/"

# Copy license
cp LICENSE "$SCRIPT_DIR/../radar/LICENSE_OPENFLIGHT"
echo "  ✓ LICENSE_OPENFLIGHT"

# Copy relevant tests
echo "Copying tests..."
TESTS_DIR="$SCRIPT_DIR/../radar/tests"
for f in test_ops243.py test_kld7.py test_kld7_geometry.py test_rolling_buffer.py \
         test_ballistics.py test_spin_estimate.py test_speed_correction.py \
         test_launch_monitor.py test_serial_latency.py conftest.py __init__.py; do
    if [ -f "tests/$f" ]; then
        cp "tests/$f" "$TESTS_DIR/$f"
        echo "  ✓ tests/$f"
    fi
done

# Copy hardware test scripts
echo "Copying hardware test scripts..."
HW_TEST_DIR="$SCRIPT_DIR/../scripts/hardware-test"
for f in test_radar_raw.py test_kld7.py test_rolling_buffer_persist.py \
         debug_hardware_trigger.py debug_radar_commands.py debug_rolling_buffer.py \
         diagnose.py probe_kld7_timing.py test_sound_trigger.py; do
    if [ -f "scripts/hardware-test/$f" ]; then
        cp "scripts/hardware-test/$f" "$HW_TEST_DIR/$f"
        echo "  ✓ scripts/hardware-test/$f"
    fi
done

# Cleanup
rm -rf "$TMP_DIR"

echo ""
echo "=== Done ==="
echo "Radar drivers vendored into: $RADAR_DIR"
echo "Tests vendored into: $TESTS_DIR"
echo "Hardware test scripts in: $HW_TEST_DIR"
echo ""
echo "Next steps:"
echo "  1. cd radar && pip install -e ."
echo "  2. python -m pytest tests/ -v"
echo "  3. Plug in OPS243-A and run: python -m openflight.ops243"
