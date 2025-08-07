#!/usr/bin/bash
set -euo pipefail

#==Crossover
RED="\033[31m"
NC="\033[0m"
GREEN="\033[32m"
CYAN="\033[36m"
#rm -rf /opt
# remove link so installing crossover is possible
if [ -L "/opt" ] && [ -d "/var/opt" ]; then
    echo -e "DEBUG: /opt is a symlink to /var/opt"
    rm -rf /opt
    recreate_opt=true
fi
rm -rf /opt
echo "mainline remove opt"
dnf -y install http://crossover.codeweavers.com/redirect/crossover.rpm
#if [[ -d /opt/cxoffice ]]; then
echo -e "$RED DEBUG:$NC"
echo -e "$GREEN ls /opt >> $NC"
ls /opt 
echo -e "$GREEN ls /var/opt >> $NC"
if [[ ! -d /var/opt ]]; then
  echo -e "$RED /var/opt does not exist for some reason...\n $CYAN CREATING... $NC"
  mkdir -p /var/opt
ls /var/opt 
opt_empty=true
#
if [ "$(find "/opt" -mindepth 1 -print -quit)" ]; then
    echo -e "$RED DEBUG: /opt is not empty $NC"
    opt_empty=false
    mkdir -p /var/opt
    mv /opt/cxoffice /var/opt
else
  mv /opt/*/ /var/opt
fi

if [ "$opt_empty" = true ]; then
    echo "${RED}nothing in opt. Something went wrong." >&2
    exit 1
fi

if [ "$recreate_opt" = true ]; then
  echo "$RED rm opt$NC"
  rm -rf /opt 
  echo "ln -s /opt /var/opt"
  ln -s /opt /var/opt
fi

