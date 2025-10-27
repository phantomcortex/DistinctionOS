#!/usr/bin/bash

set -euo pipefail

# ============================================================================
# /opt Directory Persistence Configuration
# ============================================================================
# Purpose: Generate tmpfiles.d config to persist /opt packages across reboots
# Mechanism: Dynamically scans /var/opt and creates symlink definitions
# Runtime: systemd-tmpfiles executes this config at boot
# ============================================================================

# Color codes for logging consistency
readonly COLOR_RESET='\033[0m'
readonly COLOR_GREEN='\033[32m'
readonly COLOR_CYAN='\033[36m'

log_section() {
  echo -e "\n${COLOR_CYAN}▶ $*${COLOR_RESET}"
}

log_success() {
  echo -e "${COLOR_GREEN}✓ $*${COLOR_RESET}"
}

# ============================================================================
# Directory Preparation & tmpfiles.d Generation
# ============================================================================

log_section "Configuring /opt directory persistence"

# Ensure required directories exist
mkdir -p /usr/lib/opt
mkdir -p /var/opt

# Process each directory in /var/opt
for dir in /var/opt/*/; do
  [ -d "$dir" ] || continue
  dirname=$(basename "$dir")
  
  echo "  Processing: $dirname"
  mv "$dir" "/usr/lib/opt/$dirname"
  echo "L+ /var/opt/$dirname - - - - /usr/lib/opt/$dirname" >> /usr/lib/tmpfiles.d/distinction-opt-fix.conf
done

log_success "/opt persistence configured"
echo "  ℹ Packages in /opt will persist across reboots via tmpfiles.d"

exit 0
