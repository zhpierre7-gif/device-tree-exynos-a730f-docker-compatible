#!/system/bin/sh
# One-time install: puts 'dock' in your PATH permanently
mount -o rw,remount / 2>/dev/null
cp /data/local/tmp/dock /system/bin/dock 2>/dev/null && echo "dock installed!" || {
    echo "Can't write /system, using /data/local/tmp"
    echo "Run: source /sdcard/Docker/tools-phone/go.sh"
}
