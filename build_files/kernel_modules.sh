#!/bin/bash

echo -e "\033[31mREGENERATE INITRAMFS\033[0m"
dnf5 -y install dkms
# First, ensure the proper kernel-devel package is available
# You'll need the Bazzite kernel headers specifically
KERNEL=$(ls /lib/modules/ | grep bazzite | sort -V | tail -1)

# Set up the build environment properly
export KERNELDIR="/lib/modules/${KERNEL}/build"
#tmp
dnf5 -y copr enable atim/xpadneo
dnf5 -y install xpadneo
akmods --rebuild --kernels $KERNEL --akmod xpadneo
#echo -e "\033[31mDKMS ADD\033[0m"
#dkms add /usr/src/akmods/xpadneo-kmod-0.9.7
#echo -e "\033[31mDKMS BUILD\033[0m"
#dkms build xpadneo/0.9.7 -k "${KERNEL}"
#echo -e "\033[31mDKMS INSTALL\033[0m"
#dkms install xpadneo/0.9.7 -k "${KERNEL}"
