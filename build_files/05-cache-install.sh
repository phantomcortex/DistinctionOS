#!/usr/bin/bash
# Installs pre-cached RPMs from the cache OCI artifact.
# Packages here install cleanly; the artifact exists to survive remote removal.
set -euo pipefail

source /ctx/95-utility-functions.sh

script_start "Cache RPM Install" "Pre-cached packages from distinctionos-cache OCI artifact"

readonly CACHE_RPMS_DIR="/var/tmp/cache-rpms"

if [[ ! -d "$CACHE_RPMS_DIR" ]] || [[ -z "$(ls -A "$CACHE_RPMS_DIR" 2>/dev/null)" ]]; then
    log_info "No cache RPMs found at $CACHE_RPMS_DIR — nothing to install"
    script_complete "Cache RPM Install" "No packages cached"
    exit 0
fi

log_section "RPMs to install"
ls "$CACHE_RPMS_DIR"

log_section "Installing cache RPMs"
if dnf5 -y install "$CACHE_RPMS_DIR"/*.rpm; then
    log_success "All cache RPMs installed"
else
    log_error "dnf install failed — see output above"
    exit 1
fi

script_complete "Cache RPM Install" "Cache packages installed"
exit 0
