#!/bin/bash
# install-athanor.sh — Install the Athanor kernel module and userspace tools
#
# Usage: sudo ./install-athanor.sh
#
# This script:
#   1. Builds the kernel module
#   2. Installs it to the kernel modules directory
#   3. Creates the vitriol group
#   4. Installs udev rules
#   5. Loads the module

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE="${SCRIPT_DIR}/vitriol_alka.ko"

echo "=== Athanor Installer ==="

# Check root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root"
    exit 1
fi

# Step 1: Build kernel module
echo ""
echo "Step 1: Building kernel module..."
make -C "$SCRIPT_DIR" all
echo "Built: $MODULE"

# Step 2: Install module
echo ""
echo "Step 2: Installing kernel module..."
make -C "$SCRIPT_DIR" install
echo "Module installed."

# Step 3: Create vitriol group
echo ""
echo "Step 3: Creating vitriol group..."
groupadd -f vitriol
echo "Group 'vitriol' created/exists."

# Step 4: Install udev rules
echo ""
echo "Step 4: Installing udev rules..."
cp "${SCRIPT_DIR}/99-vitriol.rules" /etc/udev/rules.d/
udevadm control --reload-rules
udevadm trigger
echo "Udev rules installed."

# Step 5: Load module
echo ""
echo "Step 5: Loading module..."
modprobe vitriol_alka
sleep 1

# Verify
echo ""
echo "=== Verification ==="
if [ -e /dev/vitriol ]; then
    echo "OK: /dev/vitriol exists"
    ls -la /dev/vitriol
else
    echo "WARNING: /dev/vitriol not found"
fi

echo ""
dmesg | grep VITRIOL | tail -10

echo ""
echo "=== Installation Complete ==="
echo "To use: alka-run.sh <recipe.alka> <vial.alkavl>"
