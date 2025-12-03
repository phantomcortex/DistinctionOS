#!/usr/bin/bash

set -euo pipefail

# ============================================================================
# ZFS Installation
# ============================================================================
# Install ZFS filesystem driver and prepare for DKMS compilation
# Note: DKMS compilation handled by kernel-modules.sh
# ============================================================================

# Source utility functions
source /ctx/95-utility-functions.sh

readonly ZFS_VERSION="2.3.5"  # Adjust as needed for latest stable
readonly WORK_DIR="/tmp/kernel-module-build"
NPROC=$(nproc)
KERNEL=$(ls /lib/modules/ | grep ba | tail -1)

# ============================================================================
# ZFS Repository & Package Installation
# ============================================================================

log_section "Installing ZFS"

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

git clone https://github.com/openzfs/zfs.git
cd zfs 

# Switch to $ZFS_VERSION
git fetch origin
git checkout -b zfs-2.3.5

log_info "Running autogen.sh"
if ./autogen.sh; then
  log_success "Autogen completed"
else
  log_error "Autogen failed"
  exit 1
fi

log_info "Configuring ZFS build"
log_info "Configuration options:"
echo "  • Kernel modules only (no userspace utilities)"
echo "  • Linux kernel compatibility layer"
echo "  • Optimized for kernel: $KERNEL"

if ./configure \
  --with-linux="/lib/modules/${KERNEL}/build" \
  --with-linux-obj="/lib/modules/${KERNEL}/build" \
  --enable-linux-builtin=no \
  --with-config=kernel; then
  log_success "Configuration successful"
else
  log_error "Configuration failed"
  exit 1
fi

log_info "Using $NPROC parallel compilation threads"

if make -j"$NPROC"; then
  log_success "ZFS compilation successful"
else
  log_error "ZFS compilation failed"
  exit 1
fi

log_info "Installing ZFS kernel modules"

if make install; then
  log_success "ZFS modules installed successfully"
else
  log_error "ZFS module installation failed"
  exit 1
fi

cd ~

exit 0
