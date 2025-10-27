#!/usr/bin/bash

set -euo pipefail

# ============================================================================
# ZFS Installation
# ============================================================================
# Install ZFS filesystem driver and prepare for DKMS compilation
# Note: DKMS compilation handled by kernel-modules.sh
# ============================================================================

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
# ZFS Repository & Package Installation
# ============================================================================

log_section "Installing ZFS repository"
dnf install -y https://zfsonlinux.org/fedora/zfs-release-2-8.fc42.noarch.rpm
log_success "ZFS repository configured"

log_section "Installing ZFS packages"
dnf -y install zfs
log_success "ZFS packages installed"

log_section "ZFS installation complete"
echo "  ℹ DKMS compilation will be handled by kernel-modules.sh"

exit 0
