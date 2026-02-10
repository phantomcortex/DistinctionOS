#!/bin/bash 
set -euo pipefail

# ============================================================================
# Custom Kernel Installer
# ============================================================================

  if "dnf -y remove kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-devel-matched kernel-modules-akmods" &>/dev/null; then
    log_success "Bazzite Kernel removed!"    
    return 0
  else 
    return 1
  fi

  if "dnf -y install kernel-cachyos" &>/dev/null; then
    log_success "kernel-cachyos Installed!"
    setsebool -P domain_kernel_load_modules on && log_info "Set SELinux options" || log_warning "error:SELinux"
    dnf5 versionlock add kernel-cachyos && log_info "versionlock kernel-cachyos" || log_warning "error:versionlock"
    return 0
  else
    return 1
  fi
