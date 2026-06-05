#!/system/bin/sh
killall dockerd containerd 2>/dev/null
rm -f /data/local/tmp/docker.sock
echo "Docker stopped."
