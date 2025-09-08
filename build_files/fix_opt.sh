#!/usr/bin/bash
set -euo pipefail

# Alternative approach: Full copy for complete writeability
# Use this if you prefer simplicity over immutability benefits

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

log "Starting /opt directory fix (full-copy variant)"

# Ensure required directories exist
mkdir -p /usr/lib/opt
mkdir -p /var/opt

# Process each directory in /var/opt
for dir in /var/opt/*/; do
  [ -d "$dir" ] || continue
  dirname=$(basename "$dir")
  
  if [[ "$dirname" == "cxoffice" ]]; then
    log "Processing Crossover with full-copy approach"
    
    # Store the entire package in /usr/lib/opt as backup/source
    mkdir -p "/usr/lib/opt/$dirname"
    cp -a "$dir"* "/usr/lib/opt/$dirname/" 2>/dev/null || true
    
    # Keep everything in /var/opt for full writeability
    # No need to move anything - it's already there
    
    # Create tmpfiles.d to copy from backup on boot if needed
    cat >> /usr/lib/tmpfiles.d/distinction-opt-fix.conf <<EOF
# Crossover - Full writeable copy
d /var/opt/$dirname 0755 root root -
d /var/opt/$dirname/etc 0755 root root -
# Copy missing files from backup (C = copy if doesn't exist)
C /var/opt/$dirname - - - - /usr/lib/opt/$dirname
EOF
    
    log "Crossover configured for full writeability"
    
  else
    # Standard handling for other /opt packages
    log "Processing standard package: $dirname"
    mv "$dir" "/usr/lib/opt/$dirname"
    echo "L+ /var/opt/$dirname - - - - /usr/lib/opt/$dirname" >> /usr/lib/tmpfiles.d/distinction-opt-fix.conf
  fi
done

log "Fix completed successfully"