#!/system/bin/sh
ln -sf /data/local/tmp/docker27/* /system/bin/ 2>/dev/null
cat /system/etc/security/cacerts/*.0 > /data/docker/certs/ca-certificates.crt 2>/dev/null
chmod 666 /data/local/tmp/docker.sock 2>/dev/null
echo "Repair done. docker -H unix:///data/local/tmp/docker.sock version"
