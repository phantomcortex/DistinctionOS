#!/usr/bin/bash

set -euo pipefail

# ============================================================================
# Kernel Module Compilation
# ============================================================================

# Source utility functions
source /ctx/95-utility-functions.sh

# ============================================================================
# Kernel Detection
# ============================================================================

log_header "Kernel Module Compilation"

log_section "Detecting installed kernel"

# Find the kernel version 
KERNEL_VERSION="$(find "/usr/lib/modules" -maxdepth 1 -type d ! -path "/usr/lib/modules" -exec basename '{}' ';' | sort | tail -n 1)"

log_success "Detected kernel: $KERNEL_VERSION"

# Set kernel build directory for compilation
export KERNELDIR="/lib/modules/${KERNEL}/build"
log_info "Kernel build directory: $KERNELDIR"

# ============================================================================
# Initramfs Regeneration
# ============================================================================
# Rebuild initramfs to include new kernel modules

log_section "Regenerating initramfs with new modules"

log_info "Running dracut to rebuild initramfs"
if /usr/bin/dracut \
  --no-hostonly \
  --kver "$KERNEL_VERSION" \
  --reproducible \
  --zstd \
  -v \
  --add ostree \
  -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"; then
  log_success "Initramfs regenerated successfully"
else
  log_error "Initramfs regeneration failed"
  exit 1
fi

# Set secure permissions on initramfs
log_info "Setting initramfs permissions (0600)"
chmod 0600 "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"
log_success "Initramfs permissions secured"

# ============================================================================
# Build Complete
# ============================================================================

log_info "Next step:"
echo "  7. remote-grabber.sh - GNOME extension management"

# ============================================================================
# Future Improvements (TODO)
# ============================================================================
# - Integrate CachyOS-LTO kernel as default
# - Add support for additional controller drivers if needed

exit 0
