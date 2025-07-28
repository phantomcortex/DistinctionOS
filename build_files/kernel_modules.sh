#!/bin/bash

echo -e "\033[31mREGENERATE INITRAMFS\033[0m"
dnf5 -y install dkms make
# First, ensure the proper kernel-devel package is available
# You'll need the Bazzite kernel headers specifically
KERNEL=$(ls /lib/modules/ | grep bazzite | sort -V | tail -1)

# Set up the build environment properly
export KERNELDIR="/lib/modules/${KERNEL}/build"
#mkdir -p /var/log/akmods/
#touch /var/log/akmods/akmods.log
PREV_DIR=$(pwd)
git clone https://github.com/atar-axis/xpadneo.git /tmp/xpadneo
cd /tmp/xpadneo/hid-xpadneo
#modified straight from xpadneo's makefile

tee makefile << 'EOF'
KERNEL_SOURCE_DIR ?= /lib/modules/$(shell ls /lib/modules/ | tail -1)/build
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
make -C $KERNELDIR INSTALL_MOD_DIR="kernel/drivers/hid" LD=$(LD) M=$(shell pwd)/src VERSION="$(shell cat ../VERSION)" $@
cd $PREV_DIR
exit 2
#tmp
#dnf5 -y copr enable atim/xpadneo
#dnf5 -y install xpadneo
#akmods --kernels $KERNEL --akmod xpadneo
#echo -e "\033[31mDKMS ADD\033[0m"
#dkms add /usr/src/akmods/xpadneo-kmod-0.9.7
#echo -e "\033[31mDKMS BUILD\033[0m"
#dkms build xpadneo/0.9.7 -k "${KERNEL}"
#echo -e "\033[31mDKMS INSTALL\033[0m"
#dkms install xpadneo/0.9.7 -k "${KERNEL}"
