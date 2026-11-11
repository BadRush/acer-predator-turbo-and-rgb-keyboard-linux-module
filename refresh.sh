#!/bin/bash
set -e
if [[ $EUID -ne 0 ]]; then
   echo "[*] Please run as root (e.g. sudo ./refresh.sh)"
   exit 1
fi
rmmod facer 2>/dev/null || true
make
modprobe platform_profile 2>/dev/null || true
modprobe rfkill 2>/dev/null || true
insmod src/facer.ko
sleep 0.5
chmod 666 /dev/acer-gkbbl-0 /dev/acer-gkbbl-static-0 2>/dev/null || true
dmesg | grep -iE "facer|acer" | tail -n 20 2>/dev/null || true
