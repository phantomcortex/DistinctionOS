#!/bin/bash
set -euo pipefail

# Determine the target kernel version for DKMS build
TARGET_KERNEL=$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | tail -1)

# Build ZFS modules for the target kernel specifically
dkms autoinstall -k ${TARGET_KERNEL}

if [ -d "/lib/modules/${TARGET_KERNEL}/extra/zfs" ]; then
    echo "ZFS modules successfully built for kernel ${TARGET_KERNEL}"
else
    echo "Warning: ZFS module build may have failed for kernel ${TARGET_KERNEL}"
    # Fallback: attempt to build for all installed kernels
    dkms autoinstall
fi 

KERNEL=$(ls /lib/modules/ | grep bazzite | sort -V | tail -1)

# Set up the build environment properly
export KERNELDIR="/lib/modules/${KERNEL}/build"
echo -e "\033[31mINSTALL XPADNEO\033[0m"
set +u #these are here prevent 'unbound variable' which doesn't make ANY sense.
PREV_DIR=$(pwd) && echo -e "\033[33m$pwd\033[0m"
set -u
git clone https://github.com/atar-axis/xpadneo.git /tmp/xpadneo
cd /tmp/xpadneo/hid-xpadneo

#modified straight from xpadneo's makefile
tee makefile << 'EOF'
KERNEL_SOURCE_DIR ?= /lib/modules/$(shell ls /lib/modules/ | grep bazzite | tail -1)/build
LD := ld.bfd

all: modules

.INTERMEDIATE: ../VERSION

../VERSION:
	$(MAKE) -C .. $(@:../%=%)

# convenience rules for local development

clean modules modules_install: ../VERSION
	$(MAKE) -C $(KERNEL_SOURCE_DIR) INSTALL_MOD_DIR="kernel/drivers/hid" LD=$(LD) M=$(shell pwd)/src VERSION="$(shell cat ../VERSION)" $@

reinstall: modules
	sudo make modules_install
	sudo rmmod hid-xpadneo || true
	sudo modprobe hid-xpadneo $(MOD_PARAMS)

# DKMS support rules

dkms.conf: dkms.conf.in ../VERSION
	sed 's/"@DO_NOT_CHANGE@"/"$(shell cat ../VERSION)"/g' <"$<" >"$@" 
EOF
echo -e "\033[31mMAKE MODULES\033[0m"
make modules 
echo -e "\033[31mMODULES_INSTALL\033[0m"
make modules_install
echo -e "\033[31mMODULES DONE\033[0m"
sleep 5

FILE1="/lib/modules/${KERNEL}/extra/xpadneo/xpadneo.ko.zst"
FILE2="/lib/modules/${KERNEL}/kernel/drivers/hid/hid-xpadneo.ko"

if [[ -f "$FILE1" || -f "$FILE2" ]]; then
    # Orange text: ANSI escape code 38;5;208
    echo -e "\033[38;5;208mXPADNEO INSTALLED\033[0m"
  else
    echo -e "\033[33;5mXPADNEO FAILED TO INSTALL\033[0m" && exit 1  
fi #sanity check

# Get kernel version and build initramfs
KERNEL_VERSION="$(dnf5 repoquery --installed --queryformat='%{evr}.%{arch}' kernel)"
/usr/bin/dracut \
  --no-hostonly \
  --kver "$KERNEL_VERSION" \
  --reproducible \
  --zstd \
  -v \
  --add ostree \
  -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

chmod 0600 "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"

#cd $PREV_DIR
cd /

#TODO: get cachyos kernel working
#TODO: investigate if kmod packages are installed correctly after init-regen \
# and consider switching to packaged variant of xpadneo
