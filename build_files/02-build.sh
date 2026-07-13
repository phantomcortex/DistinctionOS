#!/usr/bin/bash
set -uo pipefail

# ============================================================================
# DistinctionOS Build Script - Package Management & Repository Configuration
# ============================================================================
# Purpose: Install system packages with resilient "best-effort" approach
# Strategy: Attempt bulk installation, fall back to individual installation on failure
# Note: Build continues even if some packages fail (repository outages, etc.)
# repository outages have occured with openzfs, crossover, and Cider
# ============================================================================

# Source utility functions
source /ctx/95-utility-functions.sh

# ============================================================================
# Manifest Loading & Build Diagnostics
# ============================================================================
# Package lists live in /ctx/manifests/*.list — data stays declarative,
# this script stays pure logic. dnf output is captured to a log file so
# failures are diagnosable from CI output instead of vanishing into /dev/null.

readonly MANIFEST_DIR="/ctx/manifests"
readonly DNF_LOG="/tmp/distinction-dnf-build.log"
: > "$DNF_LOG"

# Read a manifest file: strip comments and blank lines, emit tokens.
read_manifest() {
  local file="$MANIFEST_DIR/$1"
  if [[ ! -f "$file" ]]; then
    log_error "Manifest not found: $file"
    return 1
  fi
  sed -e 's/#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$file" \
    | grep -v '^$'
}

# Show the tail of the dnf log after a failure (indented for readability).
dnf_log_tail() {
  local lines="${1:-25}"
  log_info "Last $lines lines of dnf output ($DNF_LOG):"
  tail -n "$lines" "$DNF_LOG" | sed 's/^/    /'
}

# Authenticated-if-possible GitHub API GET. Token sources (in order):
#   1. BuildKit secret mount  (Containerfile: --mount=type=secret,id=github_token)
#   2. GITHUB_TOKEN env var   (local builds)
# Falls back to anonymous (rate-limited) access if neither is present.
github_api_get() {
  local url="$1"
  local -a auth=()
  if [[ -r /run/secrets/github_token ]]; then
    auth=(-H "Authorization: Bearer $(< /run/secrets/github_token)")
  elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
    auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi
  curl -sfL --retry 3 --retry-delay 2 \
    -H "Accept: application/vnd.github+json" \
    "${auth[@]}" "$url"
}

# ============================================================================
# Package Installation Tracking
# ============================================================================

# Arrays to track installation results
declare -a FAILED_PACKAGES=()
declare -a SUCCEEDED_PACKAGES=()
declare -a SKIPPED_REPOS=()

# ============================================================================
# Best-Effort Package Installation Function
# ============================================================================
# Attempts bulk installation first, falls back to individual installation
# Tracks successes and failures without halting the build

install_packages_resilient() {
  local repo="$1"
  shift
  local -a packages=("$@")
  
  log_section "Installing from repository: $repo"
  log_info "Attempting to install ${#packages[@]} package(s)"
  
  # Attempt bulk installation first
  local enable_opt=""
  [[ $repo != "fedora" ]] && enable_opt="--enablerepo=$repo"
  
  local -a install_cmd=(dnf5 -y install)
  [[ -n "$enable_opt" ]] && install_cmd+=("$enable_opt")
  install_cmd+=("${packages[@]}")
  
  if "${install_cmd[@]}" &>>"$DNF_LOG"; then
    log_success "Bulk installation from $repo succeeded"
    SUCCEEDED_PACKAGES+=("${packages[@]}")
    return 0
  fi
  
  log_warning "Bulk installation from $repo failed, attempting individual installation"
  dnf_log_tail 15
  
  # Fall back to individual package installation
  local success_count=0
  local fail_count=0
  
  for pkg in "${packages[@]}"; do
    local -a single_install_cmd=(dnf5 -y install)
    [[ -n "$enable_opt" ]] && single_install_cmd+=("$enable_opt")
    single_install_cmd+=("$pkg")
    
    if "${single_install_cmd[@]}" &>>"$DNF_LOG"; then
      log_success "  ✓ $pkg"
      SUCCEEDED_PACKAGES+=("$pkg")
      ((success_count++))
    else
      log_warning "  ✗ $pkg (failed)"
      dnf_log_tail 5
      FAILED_PACKAGES+=("$pkg")
      ((fail_count++))
    fi
  done
  
  log_info "Repository $repo: $success_count succeeded, $fail_count failed"
}

# ============================================================================
# Best-Effort COPR Installation Function
# ============================================================================

install_copr_resilient() {
  local copr_repo="$1"
  shift
  local -a packages=("$@")
  
  log_section "Installing from COPR: $copr_repo"
  
  # Enable COPR repository
  if ! dnf5 -y copr enable "$copr_repo" &>>"$DNF_LOG"; then
    log_error "Failed to enable COPR: $copr_repo"
    dnf_log_tail 10
    SKIPPED_REPOS+=("copr:$copr_repo")
    FAILED_PACKAGES+=("${packages[@]}")
    return 1
  fi
  
  log_info "Attempting to install ${#packages[@]} package(s)"
  
  # Attempt bulk installation
  if dnf5 -y install "${packages[@]}" &>>"$DNF_LOG"; then
    log_success "Bulk installation from $copr_repo succeeded"
    SUCCEEDED_PACKAGES+=("${packages[@]}")
    dnf5 -y copr disable "$copr_repo" &>>"$DNF_LOG" || true
    return 0
  fi
  
  log_warning "Bulk installation from $copr_repo failed, attempting individual installation"
  dnf_log_tail 15
  
  # Fall back to individual installation
  local success_count=0
  local fail_count=0
  
  for pkg in "${packages[@]}"; do
    if dnf5 -y install "$pkg" &>>"$DNF_LOG"; then
      log_success "  ✓ $pkg"
      SUCCEEDED_PACKAGES+=("$pkg")
      ((success_count++))
    else
      log_warning "  ✗ $pkg (failed)"
      dnf_log_tail 5
      FAILED_PACKAGES+=("$pkg")
      ((fail_count++))
    fi
  done
  
  log_info "COPR $copr_repo: $success_count succeeded, $fail_count failed"
  
  # Disable COPR
  dnf5 -y copr disable "$copr_repo" &>>"$DNF_LOG" || true
}

# ============================================================================
# RPM Fusion GPG Key Bootstrap
# ============================================================================
# Verifies version-specific RPMFusion GPG keys are present; if not, installs
# the rpmfusion-*-release packages which drop them into /etc/pki/rpm-gpg/.

ensure_rpmfusion_keys() {
  local fedora_ver
  fedora_ver=$(rpm -E %fedora)

  local free_key="/etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-fedora-${fedora_ver}"
  local nonfree_key="/etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-nonfree-fedora-${fedora_ver}"

  if [[ -f "$free_key" && -f "$nonfree_key" ]]; then
    log_success "RPMFusion GPG keys present for Fedora $fedora_ver"
    return 0
  fi

  log_warning "RPMFusion GPG keys missing for Fedora $fedora_ver — fetching release packages"

  local free_url="https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_ver}.noarch.rpm"
  local nonfree_url="https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_ver}.noarch.rpm"

  if dnf5 -y install "$free_url" "$nonfree_url" &>/dev/null; then
    log_success "RPMFusion release packages installed"
  else
    log_error "Failed to install RPMFusion release packages — subsequent RPMFusion installs may fail"
    return 1
  fi

  # Verify keys landed
  if [[ -f "$free_key" && -f "$nonfree_key" ]]; then
    log_success "RPMFusion GPG keys verified for Fedora $fedora_ver"
  else
    log_warning "Keys still absent after install — GPG verification may fail"
  fi
}


# ============================================================================
# Resilient Single Package Installation
# ============================================================================
# For special cases like the Kora theme, etc.

install_single_package_resilient() {
  local package_source="$1"
  local package_name="$2"
  
  log_info "Installing $package_name from: $package_source"
  
  if dnf5 -y install "$package_source" &>/dev/null; then
    log_success "$package_name installed successfully"
    SUCCEEDED_PACKAGES+=("$package_name")
    return 0
  else
    log_warning "$package_name installation failed"
    FAILED_PACKAGES+=("$package_name")
    return 1
  fi
}

# ============================================================================
# Script Start
# ============================================================================

script_start "DistinctionOS Package Installation" "Best-effort resilient installation"

log_info "Build strategy: Continue despite individual package failures"
log_info "Repositories and packages will be retried individually if bulk fails"

# ============================================================================
# Package Removal - Critical Packages Only
# ============================================================================

log_section "Removing conflicting packages"

# These packages MUST be removed (conflicts or unwanted)
# Edit build_files/manifests/packages-remove.list — not this script.
mapfile -t REMOVE_PACKAGES < <(read_manifest "packages-remove.list")
readonly -a REMOVE_PACKAGES

removed_count=0
for pkg in "${REMOVE_PACKAGES[@]}"; do
  if rpm -q "$pkg" &>/dev/null; then
    if dnf5 -y remove "$pkg" &>/dev/null; then
      log_success "Removed: $pkg"
      ((removed_count++))
    else
      log_warning "Failed to remove: $pkg (non-critical)"
    fi
  fi
done

counter_display "$removed_count" "package" "packages" "removed"

# ============================================================================
# Repository Configuration
# ============================================================================

log_section "Configuring additional repositories"

# Note: Cider (cidercollective repo) and CrossOver are no longer installed
# here — they are pre-built into the distinctionos-cache OCI artifact (see
# .github/cache-builder/packages.txt) and installed by 03-cache-install.sh.

log_info "Clearing inherited versionlocks from base image"
dnf5 versionlock clear

# ──────────────────────────────────────────────────────────────────────────
# RPMFusion GPG Key Bootstrap
# ──────────────────────────────────────────────────────────────────────────

ensure_rpmfusion_keys

# ──────────────────────────────────────────────────────────────────────────
# Refresh Repository Metadata
# ──────────────────────────────────────────────────────────────────────────

log_info "Refreshing repository metadata"
dnf5 clean all &>/dev/null && log_success "metadata cache cleaned"
if dnf5 makecache &>/dev/null; then
  log_success "Metadata cache updated"
else
  log_warning "Metadata refresh encountered issues (continuing anyway)"
fi

# ============================================================================
# Targeted Package Upgrades (Three-Pass Strategy)
# ============================================================================
# Pass 1: Security & bugfix releases (auto-selected by DNF)
# Pass 2: [Skipped] - for manual intervention if needed
# Pass 3: Hand-selected packages known to be safe and non-conflicting
#
# Rationale: Some packages (glycin, file-roller, mutter, mutter-devel, gnome-shell)
# are excluded due to potential for destabilization. The three-pass approach gives
# finer control while still capturing most updates.

log_section "Targeted package upgrades (three-pass strategy)"

# ──────────────────────────────────────────────────────────────────────────
# PASS 1: Security & Bugfix Releases
# ──────────────────────────────────────────────────────────────────────────

log_info "PASS 1: Upgrading --bugfix and --security releases"
if dnf5 -y upgrade --bugfix --security &>>"$DNF_LOG"; then
  log_success "Security and bugfix upgrades applied"
else
  log_warning "Security/bugfix upgrade had issues (continuing anyway)"
  dnf_log_tail 15
fi

# ──────────────────────────────────────────────────────────────────────────
# PASS 2: [Reserved for manual/intermediate upgrades - skipped in automated builds]
# ──────────────────────────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────────────────────────
# PASS 3: Hand-Selected Safe Packages (low risk, tested together)
# ──────────────────────────────────────────────────────────────────────────
# These packages were selected from available updates as safe to upgrade:
#  - Development tools: cargo, rust, rustc, git, git-core, vim, neovim, gdb
#  - Core utilities: coreutils, less, perl-*, openssh
#  - Media/codecs: gstreamer1*, mesa*, wayland, enchant2, hunspell
#  - Libraries: c-ares, cjson, librabbitmq, libnghttp3, llvm-libs, libwayland*
#  - Build/system: kernel-headers, hwdata, p11-kit*, pam*, p11-kit-trust
#
# Explicitly EXCLUDED due to stability concerns:
#  - glycin* (graphics)
#  - file-roller (archive manager)
#  - mutter, mutter-devel (window manager)
#  - gnome-shell (desktop shell)
#  - webkit2gtk* (web rendering engine - complex deps)
#  - javascriptcoregtk* (JS engine - complex deps)
#  - libvpl (Intel media - may conflict with mesa)
#  - systemd-standalone-sysusers (critical system boundary)
#  - geoclue2, gssdp, gupnp (location/UPnP - network-adjacent)

log_info "PASS 3: Upgrading hand-selected safe packages"

# Array of packages deemed safe for upgrade in this build
readonly SAFE_UPGRADE_PKGS=(
  # Development toolchain
  cargo
  rust
  rust-std-static
  clippy
  git
  git-core
  git-core-doc
  vim-common
  vim-data
  vim-enhanced
  vim-filesystem
  vim-minimal
  xxd
  neovim
  gdb
  gdb-headless
  # System utilities and core libraries
  coreutils
  coreutils-common
  less
  less-color
  perl-Git
  perl-Socket
  perl-URI
  openssh
  openssh-clients
  # Multimedia and graphics (excluding webkit/js engines and problematic packages)
  gstreamer1
  gstreamer1-plugins-base
  gstreamer1-plugins-good
  gstreamer1-plugins-bad-free-libs
  mesa-dri-drivers
  mesa-filesystem
  mesa-libEGL
  mesa-libGL
  mesa-libGL-devel
  mesa-libgbm
  mesa-libgbm-devel
  mesa-vulkan-drivers
  enchant2
  hunspell
  hunspell-filesystem
  libwayland-client
  libwayland-cursor
  libwayland-egl
  libwayland-server
  wayland-devel
  # Libraries
  c-ares
  cjson
  librabbitmq
  libnghttp3
  llvm-filesystem
  llvm-libs
  libmodulemd
  # System packages
  kernel-headers
  hwdata
  p11-kit
  p11-kit-client
  p11-kit-trust
  pam
  pam-libs
  # Misc tools
  fzf
  mtr
  acl
  bluez-libs
  libacl
  libattr
  7zip
)

if dnf5 -y upgrade "${SAFE_UPGRADE_PKGS[@]}" &>>"$DNF_LOG"; then
  log_success "PASS 3: Hand-selected safe packages upgraded successfully"
else
  log_warning "PASS 3: Some hand-selected packages had upgrade issues (continuing anyway)"
  dnf_log_tail 15
fi

log_info "Targeted upgrade strategy complete (3 passes)"

# ============================================================================
# Create Required Directories
# ============================================================================

log_section "Creating required directories"

create_dir_with_log "/var/opt" "Package directory for 06-fix-opt.sh"

# ============================================================================
# Package Installation - Organized by Repository
# ============================================================================

log_section "Installing packages from configured repositories"

# Repository → manifest mapping. Package lists live in build_files/manifests/.
declare -A REPO_MANIFESTS=(
  ["fedora"]="packages-fedora.list"
  ["rpmfusion-free,rpmfusion-free-updates,rpmfusion-nonfree,rpmfusion-nonfree-updates"]="packages-rpmfusion.list"
  ["terra,terra-extras"]="packages-terra.list"
  ["fedora-multimedia"]="packages-fedora-multimedia.list"
  ["brave-browser"]="packages-brave.list"
)

# Install packages from standard repositories
for repo in "${!REPO_MANIFESTS[@]}"; do
  mapfile -t pkg_array < <(read_manifest "${REPO_MANIFESTS[$repo]}")
  if [[ ${#pkg_array[@]} -eq 0 ]]; then
    log_warning "Manifest ${REPO_MANIFESTS[$repo]} is empty — skipping $repo"
    continue
  fi
  install_packages_resilient "$repo" "${pkg_array[@]}"
done

# ──────────────────────────────────────────────────────────────────────────
# COPR Repository Packages
# ──────────────────────────────────────────────────────────────────────────

log_section "Installing packages from COPR repositories"

# COPR packages (handled separately due to enable/disable requirement)
# Edit build_files/manifests/coprs.list — format: <owner/project> <pkg> [pkg ...]
while read -r copr_repo copr_pkgs; do
  [[ -z "$copr_repo" ]] && continue
  read -ra pkg_array <<<"$copr_pkgs"
  install_copr_resilient "$copr_repo" "${pkg_array[@]}"
done < <(read_manifest "coprs.list")

# ============================================================================
# Special Package Installations
# ============================================================================

log_section "Installing special packages"

# ──────────────────────────────────────────────────────────────────────────
# Kora Icon Theme (Custom Build)
# ──────────────────────────────────────────────────────────────────────────

log_info "Installing Kora icon theme (latest release)"

# Get latest release URL — authenticated when a token is available (see
# github_api_get), since anonymous API calls share a per-IP rate limit pool
# on CI runners and fail intermittently.
kora_json=$(github_api_get "https://api.github.com/repos/phantomcortex/kora/releases/latest" || true)

kora_url=""
if [[ -n "$kora_json" ]]; then
  if command -v jq &>/dev/null; then
    kora_url=$(jq -r '.assets[].browser_download_url | select(endswith(".rpm"))' <<<"$kora_json" | head -1)
  else
    # Fallback parse if jq is unavailable for any reason
    kora_url=$(grep "browser_download_url.*\.rpm" <<<"$kora_json" | cut -d '"' -f 4 | head -1)
  fi
fi

if [[ -n "$kora_url" ]]; then
  install_single_package_resilient "$kora_url" "kora-icon-theme"
else
  log_warning "Failed to retrieve Kora theme URL (GitHub API unavailable or rate-limited)"
  FAILED_PACKAGES+=("kora-icon-theme")
fi


# ============================================================================
# Critical Package Validation
# ============================================================================
# These packages are essential - report if missing but don't fail build

log_section "Validating critical packages"

# Edit build_files/manifests/packages-critical.list — not this script.
mapfile -t CRITICAL_PACKAGES < <(read_manifest "packages-critical.list")
readonly -a CRITICAL_PACKAGES

validation_failures=0
for pkg in "${CRITICAL_PACKAGES[@]}"; do
  if rpm -q "$pkg" &>/dev/null; then
    log_success "  ✓ $pkg"
  else
    log_warning "  ✗ $pkg (CRITICAL - missing)"
    ((validation_failures++))
  fi
done

if [[ $validation_failures -eq 0 ]]; then
  log_success "All critical packages validated"
else
  log_warning "$validation_failures critical package(s) missing"
fi

# ──────────────────────────────────────────────────────────────────────────
# Hard Requirement: steam must be installed
# ──────────────────────────────────────────────────────────────────────────
# Unlike the soft validation above, a missing 'steam' package fails the build.

if rpm -q steam &>/dev/null; then
  log_success "Required package 'steam' is present"
else
  log_error "Required package 'steam' is not installed — failing build"
  exit 1
fi

# ============================================================================
# Inter Font (pinned v4.0)
# ============================================================================

log_section "Installing Inter font v4.0"

readonly INTER_URL="https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip"

if curl -fL --retry 3 --retry-delay 2 "$INTER_URL" -o /tmp/Inter.zip; then
  mkdir -p /usr/share/fonts/Inter/
  if unzip -j -o /tmp/Inter.zip "InterVariable.ttf" "InterVariable-Italic.ttf" \
      -d /usr/share/fonts/Inter/ &>>"$DNF_LOG"; then
    fc-cache -f &>/dev/null || true
    log_success "Inter font installed"
  else
    log_warning "Inter zip extraction failed (non-critical)"
  fi
  rm -f /tmp/Inter.zip
else
  log_warning "Inter font download failed (non-critical)"
fi

# NOTE: the former "versionlock add" section was removed deliberately.
# dnf versionlock has no effect on a deployed rpm-ostree/bootc system —
# updates arrive as whole image rebuilds from a fresh base, so the locks
# were never consulted. (The `versionlock clear` near the top remains, as
# it removes any locks inherited from the base image that could block
# installs during THIS build.)

# ============================================================================
# Cleanup
# ============================================================================

log_section "Cleaning package manager cache"

if dnf5 clean all &>/dev/null; then
  log_success "Cache cleaned"
else
  log_warning "Cache cleanup failed (non-critical)"
fi

# ============================================================================
# Installation Summary Report
# ============================================================================

script_complete "Package Installation" "Review summary below"

log_header "Installation Summary"

# Calculate statistics
total_attempted=$((${#SUCCEEDED_PACKAGES[@]} + ${#FAILED_PACKAGES[@]}))
success_rate=0
[[ $total_attempted -gt 0 ]] && success_rate=$(( (${#SUCCEEDED_PACKAGES[@]} * 100) / total_attempted ))

echo ""
log_info "Package Installation Statistics:"
echo "  Total Attempted:    $total_attempted"
echo "  Successful:         ${#SUCCEEDED_PACKAGES[@]}"
echo "  Failed:             ${#FAILED_PACKAGES[@]}"
echo "  Success Rate:       ${success_rate}%"

if [[ ${#SKIPPED_REPOS[@]} -gt 0 ]]; then
  echo ""
  log_warning "Skipped Repositories (unavailable):"
  for repo in "${SKIPPED_REPOS[@]}"; do
    echo "  - $repo"
  done
fi

if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
  echo ""
  log_warning "Failed Package Installations:"
  for pkg in "${FAILED_PACKAGES[@]}"; do
    echo "  - $pkg"
  done
  echo ""
  log_info "Failed packages may be due to:"
  echo "  • Package name changes"
  echo "  • Temporary network issues"
  echo "  • Dependency conflicts"
  echo ""
  log_info "Build will continue - these packages can be installed later if needed"
fi

if [[ ${#SUCCEEDED_PACKAGES[@]} -gt 0 ]]; then
  echo ""
  log_success "Build completed successfully with ${#SUCCEEDED_PACKAGES[@]} packages installed"
fi

echo ""
log_info "Next: 03-cache-install.sh will install pre-cached RPMs"

exit 0
