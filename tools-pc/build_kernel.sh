#!/bin/bash
# Build Docker kernel for A730F
KERNEL_DIR=~/Downloads/kernel_jackpotlte
GCC=~/Downloads/gcc-linaro-4.9.4-2017.01-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-
export CROSS_COMPILE=$GCC
export ANDROID_MAJOR_VERSION=p
export PLATFORM_VERSION=9
cd "$KERNEL_DIR"
echo "Building with defconfig..."
make exynos7885-jackpot2lte_docker_nouserns_defconfig
sed -i 's/CONFIG_CPUSETS=y/# CONFIG_CPUSETS is not set/' .config
make olddefconfig
make -j$(nproc)
echo "Image built: arch/arm64/boot/Image"
