#!/usr/bin/bash
set -euo pipefail

# CREDIT: https://github.com/ExistingPerson08/amyos-gnome/blob/main/build_files/fix-opt.sh
# Enhanced for Crossover support by DistinctionOS

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

log "Starting enhanced /opt directory fix"

# Ensure required directories exist
mkdir -p /usr/lib/opt
mkdir -p /var/opt

# Process each directory in /var/opt
for dir in /var/opt/*/; do
  [ -d "$dir" ] || continue
  dirname=$(basename "$dir")
  
  # Special handling for Crossover
  if [[ "$dirname" == "cxoffice" ]]; then
    log "Processing Crossover with special writeable handling"
    
    # Move most content to read-only location
    mkdir -p "/usr/lib/opt/$dirname"
    
    # Move everything EXCEPT etc to /usr/lib/opt
    for item in "$dir"*; do
      basename_item=$(basename "$item")
      if [[ "$basename_item" != "etc" ]]; then
        if [[ -e "$item" ]]; then
          mv "$item" "/usr/lib/opt/$dirname/"
        fi
      fi
    done
    
    # Keep etc in /var/opt for writeability (or create it)
    if [[ ! -d "/var/opt/$dirname/etc" ]]; then
      mkdir -p "/var/opt/$dirname/etc"
    fi
    
    # Create tmpfiles.d configuration
    cat >> /usr/lib/tmpfiles.d/distinction-opt-fix.conf <<EOF
# Crossover directory structure
d /var/opt/$dirname 0755 root root -
d /var/opt/$dirname/etc 0755 root root -
# Preserve existing license files if present
C /var/opt/$dirname/etc/cxoffice.conf 0644 root root - /usr/lib/opt/$dirname/etc/cxoffice.conf.default
C /var/opt/$dirname/etc/license.txt 0644 root root - /usr/lib/opt/$dirname/etc/license.txt.default
EOF
    
    # Create symlinks for read-only components
    for subdir in bin lib lib64 share support; do
      if [[ -d "/usr/lib/opt/$dirname/$subdir" ]]; then
        echo "L+ /var/opt/$dirname/$subdir - - - - /usr/lib/opt/$dirname/$subdir" >> /usr/lib/tmpfiles.d/distinction-opt-fix.conf
      fi
    done
    
    # If there are default config files, preserve them
    if [[ -d "$dir/etc" ]]; then
      for config_file in "$dir/etc"/*; do
        if [[ -f "$config_file" ]]; then
          filename=$(basename "$config_file")
          cp "$config_file" "/usr/lib/opt/$dirname/etc/${filename}.default"
        fi
      done
    fi
    
  else
    # Standard handling for other /opt packages
    log "Processing standard package: $dirname"
    mv "$dir" "/usr/lib/opt/$dirname"
    echo "L+ /var/opt/$dirname - - - - /usr/lib/opt/$dirname" >> /usr/lib/tmpfiles.d/distinction-opt-fix.conf
  fi
done

# Debug output (optional - remove in production)
if [[ -f /usr/lib/tmpfiles.d/distinction-opt-fix.conf ]]; then
  log "Generated tmpfiles.d configuration:"
  cat /usr/lib/tmpfiles.d/distinction-opt-fix.conf
fi

log "Fix completed successfully"
