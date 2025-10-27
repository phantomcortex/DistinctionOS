#!/usr/bin/bash

set -euo pipefail

# ============================================================================
# ZFS Installation
# ============================================================================
# Install ZFS filesystem driver and prepare for DKMS compilation
# Note: DKMS compilation handled by kernel-modules.sh
# ============================================================================

# Source utility functions
source /ctx/utility-functions.sh

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
