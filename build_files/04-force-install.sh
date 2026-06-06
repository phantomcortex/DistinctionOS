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

# ─────────────────────────────────────────────────────────────────────────────
# Pre-erase: any installed package whose NAME matches an incoming RPM gets
# removed before we install the replacement. Without this, `rpm -i --force
# --nodeps` leaves the rpm database with two NVRAs for the same NAME — rpm
# tolerates it, but `rpm-ostree compose build-chunked-oci` (the chunker)
# refuses with "Multiple installed '<name>'" and the build dies post-image.
#
# Narrower than `dnf install --allowerasing`: only erases packages whose
# NAME we are about to provide ourselves. --allowerasing has historically
# cascaded into removing critical packages like steam; this loop cannot.
# ─────────────────────────────────────────────────────────────────────────────
log_section "Resolving pre-erase set"

declare -A erase_set=()
for rpm_file in "$FORCE_RPMS_DIR"/*.rpm; do
    if ! incoming_name=$(rpm -qp --qf '%{NAME}\n' "$rpm_file" 2>/dev/null); then
        log_warning "  ? Could not query $(basename "$rpm_file") — skipping pre-erase scan for it"
        continue
    fi
    if rpm -q "$incoming_name" >/dev/null 2>&1; then
        if [[ -z "${erase_set[$incoming_name]:-}" ]]; then
            log_info "  • $incoming_name  (replaced by $(basename "$rpm_file"))"
        fi
        erase_set["$incoming_name"]=1
    fi
done

if (( ${#erase_set[@]} > 0 )); then
    log_info "Erasing ${#erase_set[@]} package name(s) currently installed:"
    for name in "${!erase_set[@]}"; do
        rpm -q "$name" | sed 's/^/    - /'
    done

    # --allmatches: nukes every installed NVRA for each NAME, in case a
    #               prior failed build polluted the database with duplicates.
    # --nodeps:     dependents are satisfied by the replacement installed
    #               in the next step.
    if ! rpm --erase --allmatches --nodeps "${!erase_set[@]}"; then
        log_error "Pre-erase failed — refusing to force-install on top of stale state"
        exit 1
    fi
    log_success "Pre-erase complete"
else
    log_info "Nothing currently installed matches incoming RPM names — pre-erase is a no-op"
fi

log_section "Force-installing RPMs"
if rpm --force --nodeps -i "$FORCE_RPMS_DIR"/*.rpm; then
    log_success "All force-install RPMs installed"
else
    log_error "rpm install failed — see output above"
    exit 1
fi

script_complete "Force-Install RPMs" "Force-install packages installed"
exit 0
