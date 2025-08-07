#!/usr/bin/bash
set -euo pipefail

# Credit: https://github.com/astrovm/amyos/blob/main/build_files/fix-opt.sh

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
 
#echo -e ""
#mv /opt/cxoffice /usr/lib/opt
# Crossover Requires a license file so It needs to be writable
# in theory this should be handled in fix_opt.sh
# relink
#rm -rf /opt
#ln -s /opt /var/opt


trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

log "Starting /opt directory fix"

# Move directories from /var/opt to /usr/lib/opt
for dir in /var/opt/*/; do
  [ -d "$dir" ] || continue
  dirname=$(basename "$dir")
  mv "$dir" "/usr/lib/opt/$dirname"
  # Since I like to support wine developtment by buying Crossover -
  # I often have to use hacky workarounds on immutable systems
  if [["$dirname" == "cxoffice"]]; then
    echo "d /usr/lib/opt/$dirname 0755 root root -" >> /usr/lib/tmpfiles.d/distinction-opt-fix.conf
    echo "d /usr/lib/opt/$dirname/etc 0755 root root -" >> /usr/lib/tmpfiles.d/distinction-opt-fix.conf
    echo "f /usr/lib/opt/$dirname/etc/cxoffice.conf 0644 root root -" >> /usr/lib/tmpfiles.d/distinction-opt-fix.conf
    echo "f /usr/lib/opt/$dirname/etc/license.txt 0644 root root -" >> /usr/lib/tmpfiles.d/distinction-opt-fix.conf
    for subdir in bin lib lib64 share support; do 
      if [[ -d "/usr/lib/opt/$dirname/$subdir" ]]; then
        echo "L+ /var/opt/$dirname/$subdir - - - - /usr/lib/opt/$dirname/$subdir" >> /usr/lib/tmpfiles.d/distinction-opt-fix.conf
      fi 
      echo -e "\033[31mDEBUG: \033[36mvar_opt:\033[32m$(ls /var/opt/) \033[36musr_lib_opt:\033[32m$(ls /usr/lib/opt) \n \033[31m$(cat /usr/lib/tmpfiles.d/distinction-opt-fix.conf)\033[0m"
    done
  fi
  echo "L+ /var/opt/$dirname - - - - /usr/lib/opt/$dirname" >>/usr/lib/tmpfiles.d/distinction-opt-fix.conf
done

log "Fix completed"
