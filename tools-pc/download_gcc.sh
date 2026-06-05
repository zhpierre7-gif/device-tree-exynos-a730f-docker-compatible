#!/bin/bash
# Download GCC Linaro 4.9.4 for A730F kernel builds
# Required for compiling kernel 4.4.177 (GCC 16+ is incompatible)

GCC_URL="https://releases.linaro.org/components/toolchain/binaries/4.9-2017.01/aarch64-linux-gnu/gcc-linaro-4.9.4-2017.01-x86_64_aarch64-linux-gnu.tar.xz"
GCC_DIR="$HOME/Downloads/gcc-linaro-4.9.4-2017.01-x86_64_aarch64-linux-gnu"

if [ -f "$GCC_DIR/bin/aarch64-linux-gnu-gcc" ]; then
    echo "GCC 4.9 already installed at $GCC_DIR"
    "$GCC_DIR/bin/aarch64-linux-gnu-gcc" --version | head -1
    exit 0
fi

echo "Downloading GCC Linaro 4.9.4..."
cd "$HOME/Downloads"
wget "$GCC_URL" -O gcc-linaro-4.9.4.tar.xz
echo "Extracting..."
tar xf gcc-linaro-4.9.4.tar.xz
rm gcc-linaro-4.9.4.tar.xz

echo "Done!"
"$GCC_DIR/bin/aarch64-linux-gnu-gcc" --version | head -1
