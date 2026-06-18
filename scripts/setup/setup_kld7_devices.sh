#!/usr/bin/env bash
# PRGR Launch Monitor - udev Rules for Radar Serial Devices
#
# The K-LD7 and OPS243-A are USB-serial devices. By default Linux assigns them
# arbitrary /dev/ttyUSBx names that can change between boots or when other USB
# devices are plugged in. These udev rules create stable symlinks:
#
#   /dev/prgr-kld7     -> K-LD7 24GHz Doppler radar
#   /dev/prgr-ops243   -> OPS243-A 24GHz Doppler radar
#
# To find the vendor and product IDs for your devices, run:
#   lsusb
# and look for lines containing your USB-serial adapter (e.g. FTDI, CP210x, CH340).
# The format is "ID xxxx:yyyy" where xxxx is the vendor ID and yyyy is the product ID.
#
# You can also use:
#   udevadm info -a /dev/ttyUSB0 | grep -E "idVendor|idProduct|serial"
# to get more details including the serial number for distinguishing identical adapters.

set -euo pipefail

RULES_FILE="/etc/udev/rules.d/99-prgr-radar.rules"

echo "=== PRGR Launch Monitor - udev Rules Setup ==="
echo ""

# Check for root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root (use sudo)."
    exit 1
fi

echo "Creating udev rules at $RULES_FILE ..."

cat > "$RULES_FILE" << 'RULES'
# PRGR Launch Monitor - Stable serial device names for radar modules
#
# Replace XXXX and YYYY with your actual vendor and product IDs from lsusb.
# If both devices use the same USB-serial chip, add a ATTRS{serial}=="..." filter
# to distinguish them. Find the serial with:
#   udevadm info -a /dev/ttyUSB0 | grep serial

# K-LD7 24GHz Doppler Radar
# Example: FTDI chip -> idVendor=0403, idProduct=6001
SUBSYSTEM=="tty", ATTRS{idVendor}=="XXXX", ATTRS{idProduct}=="YYYY", SYMLINK+="prgr-kld7", MODE="0666"

# OPS243-A 24GHz Doppler Radar
# Example: CP210x chip -> idVendor=10c4, idProduct=ea60
SUBSYSTEM=="tty", ATTRS{idVendor}=="XXXX", ATTRS{idProduct}=="YYYY", SYMLINK+="prgr-ops243", MODE="0666"
RULES

echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

echo ""
echo "============================================"
echo "  udev rules installed!"
echo ""
echo "  Next steps:"
echo "  1. Plug in your radar devices"
echo "  2. Run 'lsusb' to find vendor/product IDs"
echo "  3. Edit $RULES_FILE with the correct IDs"
echo "  4. Run 'sudo udevadm control --reload-rules && sudo udevadm trigger'"
echo "  5. Check that /dev/prgr-kld7 and /dev/prgr-ops243 appear"
echo "============================================"
