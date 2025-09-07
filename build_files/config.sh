#!/usr/bin/bash
set -euo pipefail

# script for things that don't really have a specific place

# Change the default shell to zsh
if [ -e /etc/default/useradd ];then
 sed -i 's|SHELL=/bin/bash|SHELL=/usr/bin/zsh|' /etc/default/useradd
fi 
usermod -s /usr/bin/zsh root
#

# enable distictionos-firstrun
systemctl enable distinction-firstrun.service

# Enable TPM monitoring services
echo "Enabling TPM monitor services..."
systemctl enable distinction-tpm-monitor.timer
systemctl enable distinction-tpm-monitor.service
