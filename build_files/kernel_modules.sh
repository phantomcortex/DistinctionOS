#!/bin/bash

KERNEL=$(ls /lib/modules | sort -V | tail -1)
echo -e "\033[31mREGENERATE INITRAMFS\033[0m"

akmods --rebuild
dracut --force --kver "${KERNEL}"
