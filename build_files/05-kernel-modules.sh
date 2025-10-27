#!/usr/bin/bash

set -euo pipefail

# ============================================================================
# Kernel Module Compilation
# ============================================================================

# Source utility functions
source /ctx/utility-functions.sh

# ============================================================================
# Kernel Detection
# ============================================================================

log_header "Kernel Module Compilation"

log_section "Detecting installed kernel"

# Find the Bazzite kernel version
KERNEL=$(ls /lib/modules/ | grep bazzite | sort -V | tail -1)

if [[ -z "$KERNEL" ]]; then
  log_error "No Bazzite kernel found in /lib/modules/"
  exit 1
fi

log_success "Detected kernel: $KERNEL"

# Set kernel build directory for compilation
export KERNELDIR="/lib/modules/${KERNEL}/build"
log_info "Kernel build directory: $KERNELDIR"

# ============================================================================
# xpadneo Module Compilation
# ============================================================================
# Enhanced Xbox controller driver with better wireless support

log_section "Building xpadneo kernel module"

# Store current directory (with unbound variable protection)
set +u  # Temporarily disable unbound variable check
PREV_DIR=$(pwd)
set -u

log_info "Cloning xpadneo repository"
if git clone https://github.com/atar-axis/xpadneo.git /tmp/xpadneo; then
  log_success "Repository cloned to /tmp/xpadneo"
else
  log_error "Failed to clone xpadneo repository"
  exit 1
fi

cd /tmp/xpadneo/hid-xpadneo

# ──────────────────────────────────────────────────────────────────────────
# Custom Makefile Generation
# ──────────────────────────────────────────────────────────────────────────
# Modified from xpadneo's original makefile to work with ostree systems
# DO NOT MODIFY THE HEREDOC BELOW - IT IS CAREFULLY CRAFTED FOR COMPATIBILITY

log_info "Generating custom makefile for ostree compatibility"

tee makefile << 'EOF'
KERNEL_SOURCE_DIR ?= /lib/modules/$(shell ls /lib/modules/ | grep bazzite | tail -1)/build
LD := ld.bfd

all: modules

.INTERMEDIATE: ../VERSION

../VERSION:
	$(MAKE) -C .. $(@:../%=%)

# convenience rules for local development

clean modules modules_install: ../VERSION
	$(MAKE) -C $(KERNEL_SOURCE_DIR) INSTALL_MOD_DIR="kernel/drivers/hid" LD=$(LD) M=$(shell pwd)/src VERSION="$(shell cat ../VERSION)" $@

reinstall: modules
	sudo make modules_install
	sudo rmmod hid-xpadneo || true
	sudo modprobe hid-xpadneo $(MOD_PARAMS)

# DKMS support rules

dkms.conf: dkms.conf.in ../VERSION
	sed 's/"@DO_NOT_CHANGE@"/"$(shell cat ../VERSION)"/g' <"$<" >"$@" 
EOF

log_success "Custom makefile generated"

# ──────────────────────────────────────────────────────────────────────────
# Module Compilation
# ──────────────────────────────────────────────────────────────────────────

log_section "Compiling xpadneo module"

if make modules; then
  log_success "Module compilation successful"
else
  log_error "Module compilation failed"
  exit 1
fi

log_section "Installing xpadneo module"

if make modules_install; then
  log_success "Module installation successful"
else
  log_error "Module installation failed"
  exit 1
fi

# ──────────────────────────────────────────────────────────────────────────
# Installation Verification
# ──────────────────────────────────────────────────────────────────────────

log_section "Verifying xpadneo installation"

# Check for module in possible installation locations
readonly FILE1="/lib/modules/${KERNEL}/extra/xpadneo/xpadneo.ko.zst"
readonly FILE2="/lib/modules/${KERNEL}/kernel/drivers/hid/hid-xpadneo.ko"

if [[ -f "$FILE1" || -f "$FILE2" ]]; then
  log_success "xpadneo module verified at:"
  [[ -f "$FILE1" ]] && echo "  $FILE1"
  [[ -f "$FILE2" ]] && echo "  $FILE2"
else
  log_error "xpadneo module not found in expected locations"
  log_error "Expected locations:"
  echo "  $FILE1"
  echo "  $FILE2"
  exit 1
fi

# Return to root directory
cd /

# ============================================================================
# Initramfs Regeneration
# ============================================================================
# Rebuild initramfs to include new kernel modules

log_section "Regenerating initramfs with new modules"

# Get precise kernel version for dracut
KERNEL_VERSION="$(dnf5 repoquery --installed --queryformat='%{evr}.%{arch}' kernel)"
log_info "Kernel version: $KERNEL_VERSION"

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

log_header "Kernel module compilation complete"

log_info "Installed modules:"
echo "  • xpadneo (Xbox controller driver)"
if command -v zfs &>/dev/null; then
  echo "  • ZFS (filesystem driver)"
fi

log_info "Next step:"
echo "  7. remote-grabber.sh - GNOME extension management"

# ============================================================================
# Future Improvements (TODO)
# ============================================================================
# - Integrate CachyOS-LTO kernel as default
# - Investigate kmod package installation after initramfs regeneration
# - Consider switching to packaged variant of xpadneo if available
# - Add support for additional controller drivers if needed

exit 0
