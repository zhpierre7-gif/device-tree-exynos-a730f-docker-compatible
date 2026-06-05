#!/system/bin/sh
# Docker A730F - START (kernel #8+ with bridge networking)
# Run: su -c 'sh /sdcard/Docker/tools-phone/start.sh'

echo "[1/7] Mounting cgroups..."
mount -t tmpfs none /sys/fs/cgroup 2>/dev/null
for c in cpu cpuacct memory devices freezer pids; do
    mkdir -p /sys/fs/cgroup/$c
    mount -t cgroup -o $c none /sys/fs/cgroup/$c 2>/dev/null
done

echo "[2/7] Fixing /run + /tmp..."
mkdir -p /data/docker/shim_sockets
mount --bind /data/docker/shim_sockets /run/containerd/s 2>/dev/null

echo "[3/7] Linking binaries..."
ln -sf /data/local/tmp/docker27/* /system/bin/ 2>/dev/null

echo "[4/7] Building CA certificates..."
mkdir -p /data/docker/certs
cat /system/etc/security/cacerts/*.0 > /data/docker/certs/ca-certificates.crt 2>/dev/null
export SSL_CERT_FILE=/data/docker/certs/ca-certificates.crt

echo "[5/7] Cleaning old instances..."
killall dockerd containerd 2>/dev/null
sleep 1
rm -f /data/docker/run/containerd.sock /data/local/tmp/docker.sock

echo "[6/7] Starting containerd + dockerd (bridge mode)..."
mkdir -p /data/docker/run /data/docker/data /data/docker/containerd/root /data/docker/containerd/state

containerd \
  --address /data/docker/run/containerd.sock \
  --root /data/docker/containerd/root \
  --state /data/docker/containerd/state \
  > /data/docker/containerd.log 2>&1 &
sleep 3

dockerd \
  --host unix:///data/local/tmp/docker.sock \
  --data-root /data/docker/data \
  --exec-root /data/docker/run \
  --containerd /data/docker/run/containerd.sock \
  --storage-driver vfs \
  --pidfile /data/docker/run/docker.pid \
  --dns 8.8.8.8 \
  > /data/docker/dockerd.log 2>&1 &
sleep 5

chmod 666 /data/local/tmp/docker.sock 2>/dev/null

echo "[7/7] Docker ready with bridge networking!"
echo ""
echo "  source /sdcard/Docker/tools-phone/docker-alias.sh"
echo "  docker run --rm alpine ping -c2 8.8.8.8"
echo "  docker run -it --rm ubuntu bash"
