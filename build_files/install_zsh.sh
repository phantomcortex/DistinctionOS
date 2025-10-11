#!/bin/bash

# ZFS filesystem driver 
dnf install -y https://zfsonlinux.org/fedora/zfs-release-2-8.fc42.noarch.rpm   
# Install ZFS 
dnf -y install zfs


#kernel module

# Build ZFS modules for the target kernel specifically
dkms autoinstall -k ${KERNEL}

if [ -d "/lib/modules/${KERNEL}/extra/zfs" ]; then
    echo "ZFS modules successfully built for kernel ${KERNEL}"
else
    echo "Warning: ZFS module build may have failed for kernel ${KERNEL}"
    # Fallback: attempt to build for all installed kernels
fi 
# Set up the build environment properly

