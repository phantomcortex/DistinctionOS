#!/usr/bin/bash
# Installs pre-built RPMs that require rpm --force --nodeps due to file conflicts.
set -euo pipefail

source /ctx/95-utility-functions.sh

script_start "Force-Install RPMs" "Packages requiring rpm --force --nodeps from distinctionos-force-install OCI artifact"

readonly FORCE_RPMS_DIR="/var/tmp/force-install-rpms"

if [[ ! -d "$FORCE_RPMS_DIR" ]] || [[ -z "$(ls -A "$FORCE_RPMS_DIR" 2>/dev/null)" ]]; then
    log_info "No force-install RPMs found at $FORCE_RPMS_DIR — nothing to install"
    script_complete "Force-Install RPMs" "No packages to force-install"
    exit 0
fi

log_section "RPMs to install"
ls "$FORCE_RPMS_DIR"

log_section "Force-installing RPMs"
if rpm --force --nodeps -i "$FORCE_RPMS_DIR"/*.rpm; then
    log_success "All force-install RPMs installed"
else
    log_error "rpm install failed — see output above"
    exit 1
fi

script_complete "Force-Install RPMs" "Force-install packages installed"
exit 0
