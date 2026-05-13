#!/usr/bin/bash
# Installs the pre-built custom mesa stack from the mesa-rpms OCI artifact stage.
# All packages come from a single Fedora SRPM with freeworld codec support enabled,
# guaranteeing version coherency across mesa-filesystem, mesa-libGL, mesa-libgbm,
# mesa-dri-drivers, mesa-vulkan-drivers, mesa-va-drivers, and mesa-libOpenCL.
set -euo pipefail

source /ctx/95-utility-functions.sh

script_start "Mesa Stack Install" "Fedora SRPM + freeworld codecs (pre-built artifact)"

readonly MESA_RPMS_DIR="/var/tmp/mesa-rpms"

if [[ ! -d "$MESA_RPMS_DIR" ]] || [[ -z "$(ls -A "$MESA_RPMS_DIR" 2>/dev/null)" ]]; then
    log_error "No mesa RPMs found at $MESA_RPMS_DIR"
    log_error "Ensure the mesa-rpms FROM stage is present in the Containerfile."
    exit 1
fi

log_section "RPMs to install"
ls "$MESA_RPMS_DIR"

# --force overrides any conflicting terra-mesa packages already present in the
# Bazzite base image. --nodeps avoids circular resolution during this replacement.
log_section "Installing custom mesa RPMs"
if rpm --force --nodeps -i "$MESA_RPMS_DIR"/*.rpm; then
    log_success "All custom mesa RPMs installed"
else
    log_error "rpm install failed — see output above"
    exit 1
fi

mesa_version=$(rpm -q --queryformat '%{VERSION}' mesa-filesystem 2>/dev/null || echo "unknown")
log_info "Mesa version: $mesa_version"

# ── Versionlock ───────────────────────────────────────────────────────────────
# Prevents terra-mesa or rpmfusion from overwriting our packages during any
# future dnf operation on the running system.
log_section "Versionlocking mesa packages"

readonly -a MESA_PACKAGES=(
    "mesa-filesystem"
    "mesa-libGL"
    "mesa-libEGL"
    "mesa-libOpenCL"
    "mesa-libgbm"
    "mesa-libgbm-devel"
    "mesa-dri-drivers"
    "mesa-vulkan-drivers"
    "mesa-va-drivers"
)

lock_failures=0
for pkg in "${MESA_PACKAGES[@]}"; do
    if rpm -q "$pkg" &>/dev/null; then
        if dnf5 versionlock add "$pkg" &>/dev/null; then
            log_success "  ✓ $pkg"
        else
            log_warning "  ✗ $pkg (versionlock failed — non-critical)"
            ((lock_failures++)) || true
        fi
    else
        log_info "  - $pkg (not installed, skipping)"
    fi
done

[[ $lock_failures -gt 0 ]] && log_warning "$lock_failures package(s) could not be versionlocked"

# ── Validate ──────────────────────────────────────────────────────────────────
log_section "Validation"
validate_critical_packages \
    "mesa-filesystem" \
    "mesa-libGL" \
    "mesa-libEGL" \
    "mesa-libgbm" \
    "mesa-dri-drivers"

script_complete "Mesa Stack Install" "Mesa $mesa_version installed and versionlocked"
exit 0
