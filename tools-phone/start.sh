#!/system/bin/sh
# Docker A730F - START (final)
# Run: su -c 'sh /sdcard/Docker/tools-phone/start.sh'

echo "[*] Setting up Docker..."

# 1. Force kill everything + clean
killall -9 dockerd containerd 2>/dev/null
sleep 2
rm -f /data/docker/run/containerd.sock /data/local/tmp/docker.sock /data/docker/run/docker.pid /data/docker/run/containerd.sock.ttrpc

# 2. Mount cgroups
mount -t tmpfs none /sys/fs/cgroup 2>/dev/null
for c in cpu cpuacct memory devices freezer pids; do
    mkdir -p /sys/fs/cgroup/$c
    mount -t cgroup -o $c none /sys/fs/cgroup/$c 2>/dev/null
done

# 3. Link binaries + fix paths
mkdir -p /data/docker/shim_sockets /run/containerd 2>/dev/null
mount --bind /data/docker/shim_sockets /run/containerd/s 2>/dev/null
ln -sf /data/local/tmp/docker27/* /system/bin/ 2>/dev/null

# 4. Build CA certs
mkdir -p /data/docker/certs /data/docker/run /data/docker/data /data/docker/containerd/root /data/docker/containerd/state
cat /system/etc/security/cacerts/*.0 > /data/docker/certs/ca-certificates.crt 2>/dev/null

# 5. Start containerd
echo "  -> containerd..."
containerd \
  --address /data/docker/run/containerd.sock \
  --root /data/docker/containerd/root \
  --state /data/docker/containerd/state \
  > /data/docker/containerd.log 2>&1 &
for i in $(seq 10); do sleep 1; [ -S /data/docker/run/containerd.sock ] && break; done

# 6. Start dockerd with SSL certs
echo "  -> dockerd..."
export SSL_CERT_FILE=/data/docker/certs/ca-certificates.crt
dockerd \
  --host unix:///data/local/tmp/docker.sock \
  --data-root /data/docker/data \
  --exec-root /data/docker/run \
  --containerd /data/docker/run/containerd.sock \
  --storage-driver vfs \
  --pidfile /data/docker/run/docker.pid \
  --dns 8.8.8.8 \
  > /data/docker/dockerd.log 2>&1 &
for i in $(seq 10); do sleep 1; [ -S /data/local/tmp/docker.sock ] && chmod 666 /data/local/tmp/docker.sock && break; done

echo ""
echo "Docker ready!"
echo "  source /sdcard/Docker/tools-phone/docker-alias.sh"
echo "  docker run --rm hello-world"
