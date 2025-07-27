#!/bin/bash

#KERNEL=$(ls /lib/modules | sort -V | tail -1)
#dnf5 -y install kernel-devel-matched
echo -e "\033[31mREGENERATE INITRAMFS\033[0m"

# First, ensure the proper kernel-devel package is available
# You'll need the Bazzite kernel headers specifically
KERNEL=$(ls /lib/modules/ | grep bazzite | sort -V | tail -1)

# Create necessary directories for akmods
mkdir -p /var/log/akmods /run/akmods /var/cache/akmods

# Set up the build environment properly
export KERNELDIR="/lib/modules/${KERNEL}/build"

# If the build directory doesn't exist, create a symlink to source if available
if [ ! -d "/lib/modules/${KERNEL}/build" ]; then
    ln -sf /usr/src/kernels/${KERNEL} /lib/modules/${KERNEL}/build 2>/dev/null || \
    ln -sf /lib/modules/${KERNEL}/source /lib/modules/${KERNEL}/build 2>/dev/null
fi

# Now attempt the akmods rebuild
akmods --kernels "${KERNEL}" --rebuild

#dracut --force --kver "${KERNEL}"

