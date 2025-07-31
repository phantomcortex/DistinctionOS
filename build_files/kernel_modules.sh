#!/bin/bash



dnf5 -y install dkms
: '
Black        0;30     Dark Gray     1;30
Red          0;31     Light Red     1;31
Green        0;32     Light Green   1;32
Brown/Orange 0;33     Yellow        1;33
Blue         0;34     Light Blue    1;34
Purple       0;35     Light Purple  1;35
Cyan         0;36     Light Cyan    1;36
Light Gray   0;37     White         1;37
'
# First, ensure the proper kernel-devel package is available
# You'll need the Bazzite kernel headers specifically
KERNEL=$(ls /lib/modules/ | grep bazzite | sort -V | tail -1)

# Set up the build environment properly
export KERNELDIR="/lib/modules/${KERNEL}/build"
echo -e "\033[31mINSTALL XPADNEO\033[0m"
PREV_DIR=$(pwd) && echo -e "\033[33m$pwd\033[0m"
git clone https://github.com/atar-axis/xpadneo.git /tmp/xpadneo
cd /tmp/xpadneo/hid-xpadneo
#modified straight from xpadneo's makefile

echo -e "\033[37m$tee\033[0m"
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
fi

echo -e "\033[31mINSTALL CUSTOM KERNEL\033[0m"
# Remove all packages whose name starts with 'kernel'
echo -e "\033[31mDEBUG:\033[0m"
dnf list --installed |grep -E 'kernel|bazzite'
dnf copr enable -y bieszczaders/kernel-cachyos-lto
dnf install -y kernel-cachyos-lto kernel-cachyos-lto-devel-matched
cp /lib/modules/${KERNEL}/extras/hid-xpadneo.ko.zst /lib/modules/${ls /lib/modules/ |grep cachyos}/extras/

FILE1="/lib/modules/${ls /lib/modules |grep cachyos}/extra/xpadneo/xpadneo.ko.zst"
FILE2="/lib/modules/${ls /lib/modules |grep cachyos}/kernel/drivers/hid/hid-xpadneo.ko"
if [[ -f "$FILE1" || -f "$FILE2" ]]; then
    # Orange text: ANSI escape code 38;5;208
    echo -e "\033[38;5;208mXPADNEO INSTALLED ON CACHYOS KERNEL\033[0m"
  else
    echo -e "\033[33;5mXPADNEO FAILED TO INSTALL\033[0m" && exit 1  
fi
echo -e "\033[31mDEBUG:\033[0m" && ls /lib/modules
echo -e "\033[33mREMOVING OTHER KERNELS\033[0m"
dnf list --installed | awk '{print $1}' | grep '^kernel' | xargs -r dnf remove -y
echo -e "\033[31mDEBUG:\033[0m" && ls /lib/modules


cd $PREV_DIR

