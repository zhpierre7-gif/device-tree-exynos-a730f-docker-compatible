#!/system/bin/sh
# Docker A730F - START | Run: su -c 'sh /sdcard/Docker/start.sh'
echo "[*] Mounting cgroups..."
mount -t tmpfs none /sys/fs/cgroup 2>/dev/null
for c in cpu cpuacct memory devices freezer pids; do mkdir -p /sys/fs/cgroup/$c; mount -t cgroup -o $c none /sys/fs/cgroup/$c 2>/dev/null; done
echo "[*] DNS + certs..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
cat /system/etc/security/cacerts/*.0 > /data/docker/certs/ca-certificates.crt 2>/dev/null
export SSL_CERT_FILE=/data/docker/certs/ca-certificates.crt
echo "[*] Linking binaries..."
ln -sf /data/local/tmp/docker27/* /system/bin/ 2>/dev/null
echo "[*] Starting containerd..."
killall dockerd containerd 2>/dev/null; sleep 1
mkdir -p /data/docker/run /data/docker/data /data/docker/containerd/root /data/docker/containerd/state /data/docker/certs
containerd --address /data/docker/run/containerd.sock --root /data/docker/containerd/root --state /data/docker/containerd/state > /data/docker/containerd.log 2>&1 &
sleep 2
echo "[*] Starting dockerd..."
dockerd --host unix:///data/local/tmp/docker.sock --data-root /data/docker/data --exec-root /data/docker/run --containerd /data/docker/run/containerd.sock --storage-driver vfs --iptables=false --bridge=none --userland-proxy=false --pidfile /data/docker/run/docker.pid --dns 8.8.8.8 > /data/docker/dockerd.log 2>&1 &
sleep 5
chmod 666 /data/local/tmp/docker.sock
echo "[*] Docker ready! | docker -H unix:///data/local/tmp/docker.sock version"
