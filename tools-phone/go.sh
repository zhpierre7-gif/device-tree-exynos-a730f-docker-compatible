#!/system/bin/sh
# Docker quick launcher - run this, then use 'd' for everything
export PATH=/data/local/tmp:$PATH
export SSL_CERT_FILE=/data/docker/certs/ca-certificates.crt
alias d=/data/local/tmp/dock
echo "Docker on! Commands: d ps | d images | d run --rm alpine sh"
