#!/system/bin/sh
# Source this once per session to use 'dock' anywhere
export PATH=/data/local/tmp:$PATH
export SSL_CERT_FILE=/data/docker/certs/ca-certificates.crt
alias docker=/data/local/tmp/dock
echo "Docker ready! Use: dock ps | dock images | dock run --rm alpine sh"
