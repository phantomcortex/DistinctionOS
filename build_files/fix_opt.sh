#!/usr/bin/bash
set -euo pipefail

# Credit: https://github.com/astrovm/amyos/blob/main/build_files/fix-opt.sh


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
  echo "L+ /var/opt/$dirname - - - - /usr/lib/opt/$dirname" >>/usr/lib/tmpfiles.d/distinction-opt-fix.conf
  done

log "Fix completed"
