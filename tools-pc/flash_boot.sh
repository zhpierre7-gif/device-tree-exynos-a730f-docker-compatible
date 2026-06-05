#!/bin/bash
# Flash Docker kernel to A730F via ADB
BOOT="boot/boot.img"
adb push "$BOOT" /sdcard/boot_docker.img
adb shell "su -c 'dd if=/sdcard/boot_docker.img of=/dev/block/platform/13500000.dwmmc0/by-name/BOOT bs=4096'"
echo "Flashed! Rebooting..."
adb reboot
