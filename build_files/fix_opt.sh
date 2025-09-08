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
    
    # Move main content to read-only location
    mkdir -p "/usr/lib/opt/$dirname"
    
    # Save the etc directory temporarily if it exists
    if [[ -d "$dir/etc" ]]; then
      log "Preserving existing etc directory"
      cp -a "$dir/etc" "/tmp/cxoffice-etc-temp"
    fi
    
    # Move everything to /usr/lib/opt first
    for item in "$dir"*; do
      basename_item=$(basename "$item")
      if [[ -e "$item" ]]; then
        mv "$item" "/usr/lib/opt/$dirname/"
      fi
    done
    
    # Now move etc back to /var/opt for writeability
    if [[ -d "/usr/lib/opt/$dirname/etc" ]]; then
      mkdir -p "/var/opt/$dirname"
      mv "/usr/lib/opt/$dirname/etc" "/var/opt/$dirname/etc"
      log "Moved etc to writeable location"
    elif [[ -d "/tmp/cxoffice-etc-temp" ]]; then
      # Restore from temp if we saved it
      mkdir -p "/var/opt/$dirname"
      mv "/tmp/cxoffice-etc-temp" "/var/opt/$dirname/etc"
      log "Restored etc from temp"
    else
      # Create empty etc if it doesn't exist
      mkdir -p "/var/opt/$dirname/etc"
      log "Created empty etc directory"
    fi
    
    # Ensure proper permissions
    chmod 755 "/var/opt/$dirname/etc"
    
    # Create tmpfiles.d configuration
    cat >> /usr/lib/tmpfiles.d/distinction-opt-fix.conf <<EOF
# Crossover directory structure
d /var/opt/$dirname 0755 root root -
d /var/opt/$dirname/etc 0755 root root -
EOF
    
    # Create symlinks for read-only components
    for subdir in bin lib lib64 share support; do
      if [[ -d "/usr/lib/opt/$dirname/$subdir" ]]; then
        echo "L+ /var/opt/$dirname/$subdir - - - - /usr/lib/opt/$dirname/$subdir" >> /usr/lib/tmpfiles.d/distinction-opt-fix.conf
      fi
    done
    
    # If cxoffice.conf exists, ensure it's in the writeable location
    if [[ -f "/usr/lib/opt/$dirname/etc/cxoffice.conf" ]]; then
      mv "/usr/lib/opt/$dirname/etc/cxoffice.conf" "/var/opt/$dirname/etc/"
      log "Moved cxoffice.conf to writeable location"
    fi
    
  else
    # Standard handling for other /opt packages
    log "Processing standard package: $dirname"
    mv "$dir" "/usr/lib/opt/$dirname"
    echo "L+ /var/opt/$dirname - - - - /usr/lib/opt/$dirname" >> /usr/lib/tmpfiles.d/distinction-opt-fix.conf
  fi
done

# Clean up any temp directories
rm -rf /tmp/cxoffice-etc-temp

# Debug output (optional - remove in production)
if [[ -f /usr/lib/tmpfiles.d/distinction-opt-fix.conf ]]; then
  log "Generated tmpfiles.d configuration:"
  cat /usr/lib/tmpfiles.d/distinction-opt-fix.conf
fi

log "Fix completed successfully"
