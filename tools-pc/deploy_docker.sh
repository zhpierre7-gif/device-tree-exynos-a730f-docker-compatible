#!/bin/bash
# Deploy Docker 27.3.1 binaries to phone
TGZ="https://download.docker.com/linux/static/stable/aarch64/docker-27.3.1.tgz"
wget "$TGZ" -O /tmp/docker.tgz
tar xzf /tmp/docker.tgz -C /tmp/
adb shell "mkdir -p /data/local/tmp/docker27"
for f in /tmp/docker/*; do adb push "$f" /data/local/tmp/docker27/; done
adb shell "chmod 755 /data/local/tmp/docker27/*"
echo "Docker binaries deployed to /data/local/tmp/docker27/"
