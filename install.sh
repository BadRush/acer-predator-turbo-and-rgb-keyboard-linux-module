#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
   echo "[*] This script must be run as root (e.g. sudo ./install.sh)"
   exit 1
fi

if [[ ! -d "/sys/bus/wmi/devices/7A4DDFE7-5B5D-40B4-8595-4408E0CC7F56" ]]; then
    echo "[!] Warning: Acer gaming WMI GUID (7A4DDFE7-5B5D-40B4-8595-4408E0CC7F56) not found."
    echo "[!] Keyboard RGB or Turbo features might not be supported on this model."
fi

if [ ! "$(uname -r | grep lts)" == "" ]; then
    echo "[*] LTS kernel detected"
    MAKEFLAGS="LTS=1"
fi

# Remove previous chr devices if any exist
rm -f /dev/acer-gkbbl-0 /dev/acer-gkbbl-static-0

# Compile the kernel module
echo "[*] Building facer kernel module..."
if [ "$(cat /proc/version | grep clang)" != "" ]; then
    make CC=clang LD=ld.lld $MAKEFLAGS
else
    make $MAKEFLAGS
fi

# Remove previous conflicting modules
echo "[*] Removing conflicting modules if present..."
rmmod acer_wmi 2>/dev/null || true
rmmod facer 2>/dev/null || true

# Install required kernel module dependencies
echo "[*] Loading module dependencies..."
modprobe wmi 2>/dev/null || true
modprobe rfkill 2>/dev/null || true
modprobe platform_profile 2>/dev/null || true
modprobe sparse-keymap 2>/dev/null || true
modprobe video 2>/dev/null || true

# Insert facer module
echo "[*] Inserting facer kernel module..."
insmod src/facer.ko

# Ensure device node permissions
sleep 0.5
chmod 666 /dev/acer-gkbbl-0 /dev/acer-gkbbl-static-0 2>/dev/null || true

if [[ -e /dev/acer-gkbbl-0 ]]; then
    echo "[✓] Dynamic RGB device node ready: /dev/acer-gkbbl-0"
fi
if [[ -e /dev/acer-gkbbl-static-0 ]]; then
    echo "[✓] Static RGB device node ready: /dev/acer-gkbbl-static-0"
fi

dmesg | grep -iE "facer|acer" | tail -n 10 2>/dev/null || true
echo "[*] Installation completed successfully!"