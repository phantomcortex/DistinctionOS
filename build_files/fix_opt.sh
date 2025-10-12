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
  


  log "Processing standard package: $dirname"
    mv "$dir" "/usr/lib/opt/$dirname"
    echo "L+ /var/opt/$dirname - - - - /usr/lib/opt/$dirname" >> /usr/lib/tmpfiles.d/distinction-opt-fix.conf
  log "Fix completed successfully"
done
