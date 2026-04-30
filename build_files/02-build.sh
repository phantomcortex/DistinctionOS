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
  
  if "${install_cmd[@]}" &>/dev/null; then
    log_success "Bulk installation from $repo succeeded"
    SUCCEEDED_PACKAGES+=("${packages[@]}")
    return 0
  fi
  
  log_warning "Bulk installation from $repo failed, attempting individual installation"
  
  # Fall back to individual package installation
  local success_count=0
  local fail_count=0
  
  for pkg in "${packages[@]}"; do
    local -a single_install_cmd=(dnf5 -y install)
    [[ -n "$enable_opt" ]] && single_install_cmd+=("$enable_opt")
    single_install_cmd+=("$pkg")
    
    if "${single_install_cmd[@]}" &>/dev/null; then
      log_success "  ✓ $pkg"
      SUCCEEDED_PACKAGES+=("$pkg")
      ((success_count++))
    else
      log_warning "  ✗ $pkg (failed)"
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
  if ! dnf5 -y copr enable "$copr_repo" &>/dev/null; then
    log_error "Failed to enable COPR: $copr_repo"
    SKIPPED_REPOS+=("copr:$copr_repo")
    FAILED_PACKAGES+=("${packages[@]}")
    return 1
  fi
  
  log_info "Attempting to install ${#packages[@]} package(s)"
  
  # Attempt bulk installation
  if dnf5 -y install "${packages[@]}" &>/dev/null; then
    log_success "Bulk installation from $copr_repo succeeded"
    SUCCEEDED_PACKAGES+=("${packages[@]}")
    dnf5 -y copr disable "$copr_repo" &>/dev/null || true
    return 0
  fi
  
  log_warning "Bulk installation from $copr_repo failed, attempting individual installation"
  
  # Fall back to individual installation
  local success_count=0
  local fail_count=0
  
  for pkg in "${packages[@]}"; do
    if dnf5 -y install "$pkg" &>/dev/null; then
      log_success "  ✓ $pkg"
      SUCCEEDED_PACKAGES+=("$pkg")
      ((success_count++))
    else
      log_warning "  ✗ $pkg (failed)"
      FAILED_PACKAGES+=("$pkg")
      ((fail_count++))
    fi
  done
  
  log_info "COPR $copr_repo: $success_count succeeded, $fail_count failed"
  
  # Disable COPR
  dnf5 -y copr disable "$copr_repo" &>/dev/null || true
}

# ============================================================================
# RPM Fusion Fedora 43 Fallback Installation
# ============================================================================
# Temporarily adds F43 rpmfusion repos to install packages missing from F44

install_rpmfusion_f43_fallback() {
  local -a packages=("$@")
  [[ ${#packages[@]} -eq 0 ]] && return 0

  log_section "RPM Fusion F43 fallback for ${#packages[@]} package(s)"

  local tmp_free_repo="/etc/yum.repos.d/rpmfusion-free-f43-fallback.repo"
  local tmp_nonfree_repo="/etc/yum.repos.d/rpmfusion-nonfree-f43-fallback.repo"

  tee "$tmp_free_repo" > /dev/null << 'EOF'
[rpmfusion-free-f43-fallback]
name=RPM Fusion for Fedora 43 - Free (F44 Fallback)
baseurl=https://mirrors.rpmfusion.org/free/fedora/43/$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-fedora-2020
skip_if_unavailable=1
EOF

  tee "$tmp_nonfree_repo" > /dev/null << 'EOF'
[rpmfusion-nonfree-f43-fallback]
name=RPM Fusion for Fedora 43 - NonFree (F44 Fallback)
baseurl=https://mirrors.rpmfusion.org/nonfree/fedora/43/$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-nonfree-fedora-2020
skip_if_unavailable=1
EOF

  dnf5 makecache &>/dev/null || true

  local success_count=0
  local fail_count=0
  local -a still_failed=()

  for pkg in "${packages[@]}"; do
    if dnf5 -y install \
        --enablerepo=rpmfusion-free-f43-fallback,rpmfusion-nonfree-f43-fallback \
        "$pkg" &>/dev/null; then
      log_success "  ✓ $pkg (via F43 fallback)"
      SUCCEEDED_PACKAGES+=("$pkg")
      ((success_count++))
    else
      log_warning "  ✗ $pkg (F43 fallback also failed)"
      still_failed+=("$pkg")
      ((fail_count++))
    fi
  done

  # Rebuild FAILED_PACKAGES removing entries that succeeded via fallback
  local -a updated_failed=()
  for failed_pkg in "${FAILED_PACKAGES[@]}"; do
    local still_in_failed=false
    for sf in "${still_failed[@]}"; do
      [[ "$failed_pkg" == "$sf" ]] && still_in_failed=true && break
    done
    # Keep if not one of the packages we just retried, or if it's still failing
    local was_retried=false
    for retried in "${packages[@]}"; do
      [[ "$failed_pkg" == "$retried" ]] && was_retried=true && break
    done
    if ! $was_retried || $still_in_failed; then
      updated_failed+=("$failed_pkg")
    fi
  done
  FAILED_PACKAGES=("${updated_failed[@]}")

  rm -f "$tmp_free_repo" "$tmp_nonfree_repo"
  dnf5 makecache &>/dev/null || true

  log_info "F43 fallback: $success_count succeeded, $fail_count failed"
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
# Freeworld RPM Force-Install
# ============================================================================
# Downloads freeworld RPMs from RPMFusion and installs via rpm to sidestep
# dnf dependency/conflict checks against Bazzite's terra-repo packages.
#
#   mesa-vulkan-drivers-freeworld  --force --nodeps  (overrides terra mesa)
#   mesa-va-drivers-freeworld      --nodeps
#   libheif-freeworld              --nodeps           (F43 repo: not yet in F44)

install_freeworld_rpms() {
  log_section "Installing freeworld RPMs via rpm"

  local tmp_dir
  tmp_dir=$(mktemp -d)

  # Shared helper: download one package from the given repo(s) and install it.
  # Usage: _freeworld_pkg <package> <enablerepo> <rpm-flag...>
  _freeworld_pkg() {
    local pkg="$1" repos="$2"; shift 2
    local rpm_flags=("$@")

    if dnf download --destdir="$tmp_dir" --enablerepo="$repos" "$pkg" &>/dev/null; then
      local rpm_file
      rpm_file=$(find "$tmp_dir" -name "${pkg}*.rpm" | sort -V | tail -1)
      if [[ -n "$rpm_file" ]]; then
        if rpm "${rpm_flags[@]}" -i "$rpm_file"; then
          log_success "$pkg installed"
          SUCCEEDED_PACKAGES+=("$pkg")
        else
          log_error "rpm install failed for $pkg"
          FAILED_PACKAGES+=("$pkg")
        fi
        rm -f "$rpm_file"
      else
        log_error "Downloaded RPM not found for $pkg"
        FAILED_PACKAGES+=("$pkg")
      fi
    else
      log_warning "Failed to download $pkg"
      FAILED_PACKAGES+=("$pkg")
    fi
  }

  # ── mesa-vulkan-drivers-freeworld: --force needed to override terra mesa ──
  _freeworld_pkg "mesa-vulkan-drivers-freeworld" \
    "rpmfusion-free,rpmfusion-free-updates" \
    --force --nodeps

  # ── mesa-va-drivers-freeworld: same repos, no --force needed ──
  _freeworld_pkg "mesa-va-drivers-freeworld" \
    "rpmfusion-free,rpmfusion-free-updates" \
    --nodeps

  # ── libheif-freeworld: not yet in F44 — pull from F43 repo temporarily ──
  local f43_repo="/etc/yum.repos.d/rpmfusion-free-f43-freeworld-tmp.repo"
  tee "$f43_repo" > /dev/null << 'EOF'
[rpmfusion-free-f43-freeworld-tmp]
name=RPM Fusion for Fedora 43 - Free (libheif-freeworld fallback)
baseurl=https://mirrors.rpmfusion.org/free/fedora/43/$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-fedora-2020
skip_if_unavailable=1
EOF
  dnf5 makecache --repo=rpmfusion-free-f43-freeworld-tmp &>/dev/null || true
  _freeworld_pkg "libheif-freeworld" "rpmfusion-free-f43-freeworld-tmp" --nodeps
  rm -f "$f43_repo"

  rm -rf "$tmp_dir"
}

# ============================================================================
# Resilient Single Package Installation
# ============================================================================
# For special cases like CrossOver, Kora theme, etc.

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
readonly -a REMOVE_PACKAGES=(
  "waydroid"                                # Not needed
  "sunshine"                                # Not needed
  "gnome-shell-extension-compiz-windows-effect"  # Not needed
  "openssh-askpass"                         # Not needed
)

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

# ──────────────────────────────────────────────────────────────────────────
# Cider Collective Repository
# ──────────────────────────────────────────────────────────────────────────

log_info "Adding Cider Collective repository"

if rpm --import https://repo.cider.sh/RPM-GPG-KEY &>/dev/null; then
  log_success "Cider GPG key imported"
else
  log_warning "Failed to import Cider GPG key (repository may be unavailable)"
fi

tee /etc/yum.repos.d/cider.repo > /dev/null << 'EOF'
[cidercollective]
name=Cider Collective Repository
baseurl=https://repo.cider.sh/rpm/RPMS
enabled=1
gpgcheck=1
gpgkey=https://repo.cider.sh/RPM-GPG-KEY
EOF

log_success "Cider repository configured"

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
# Create Required Directories
# ============================================================================

log_section "Creating required directories"

create_dir_with_log "/var/opt" "Package directory for fix-opt.sh"

# ============================================================================
# Package Installation - Organized by Repository
# ============================================================================

log_section "Installing packages from configured repositories"

# Associative array mapping repositories to their packages
declare -A RPM_PACKAGES=(
  # Core Fedora repositories
  ["fedora"]="\
    zsh \
    zsh-syntax-highlighting \
    zsh-autosuggestions \
    neovim \
    file-roller \
    evince \
    loupe \
    sassc \
    gstreamer1-plugins-good-extras \
    gstreamer1-vaapi \
    decibels \
    dconf \
    gtk-murrine-engine \
    glib2-devel \
    perl-File-Copy \
    winetricks \
    lutris \
    sox \
    totem-video-thumbnailer \
    mediainfo \
    pandoc \
    flatpak-builder \
    gnome-tweaks \
    freerdp \
    nss-mdns.i686 \
    pcsc-lite-libs.i686 \
    nmap-ncat \
    sane-backends-libs.i686 \
    sane-backends-libs.x86_64 \
    dcraw \
    perl-Image-ExifTool \
    libheif-tools \
    heif-pixbuf-loader \
    libgda \
    libgda-sqlite \
    libjxl-utils \
    foremost \
    filelight \
    clamav \
    diffpdf \
    ghex \
    id3v2 \
    kdiff3 \
    lhasa \
    lzma \
    meld \
    okteta \
    pandoc-cli \
    testdisk \
    qpdf \
    rdfind \
    rhash \
    unar \
    xorriso \
    baobab"

  ["rpmfusion-free,rpmfusion-free-updates,rpmfusion-nonfree,rpmfusion-nonfree-updates"]="\
    audacity-freeworld \
    libavcodec-freeworld \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    mesa-va-drivers-freeworld"

  # Fedora Multimedia (optimized multimedia packages)
  ["fedora-multimedia"]="mpv"

  # Third-party repositories
  ["brave-browser"]="brave-browser"
  ["cidercollective"]="Cider"
)

# Install packages from standard repositories
for repo in "${!RPM_PACKAGES[@]}"; do
  read -ra pkg_array <<<"${RPM_PACKAGES[$repo]}"
  install_packages_resilient "$repo" "${pkg_array[@]}"
done

# ──────────────────────────────────────────────────────────────────────────
# COPR Repository Packages
# ──────────────────────────────────────────────────────────────────────────

log_section "Installing packages from COPR repositories"

# COPR packages (handled separately due to enable/disable requirement)
declare -A COPR_PACKAGES=(
  ["ilyaz/LACT"]="lact"                                    # AMD GPU control
  ["fernando-debian/dysk"]="dysk"                          # Disk usage analyzer
  ["atim/heroic-games-launcher"]="heroic-games-launcher-bin"  # Epic/GOG launcher
  ["sergiomb/clonezilla"]="clonezilla"                     # Disk cloning utility
  ["alternateved/eza"]="eza"                               # Modern ls replacement
  #["monkeygold/nautilus-open-any-terminal"]="nautilus-open-any-terminal"
)

for copr_repo in "${!COPR_PACKAGES[@]}"; do
  read -ra pkg_array <<<"${COPR_PACKAGES[$copr_repo]}"
  install_copr_resilient "$copr_repo" "${pkg_array[@]}"
done

# ──────────────────────────────────────────────────────────────────────────
# RPM Fusion F43 Fallback
# ──────────────────────────────────────────────────────────────────────────
# RPM Fusion F44 repos may not be fully populated yet; retry failures via F43

readonly -a RPMFUSION_PACKAGES=(
  "audacity-freeworld"
  "libavcodec-freeworld"
  "gstreamer1-plugins-bad-freeworld"
  "gstreamer1-plugins-ugly"
  "libheif-freeworld"
)

rpmfusion_failed=()
for pkg in "${RPMFUSION_PACKAGES[@]}"; do
  for failed in "${FAILED_PACKAGES[@]}"; do
    if [[ "$pkg" == "$failed" ]]; then
      rpmfusion_failed+=("$pkg")
      break
    fi
  done
done

if [[ ${#rpmfusion_failed[@]} -gt 0 ]]; then
  install_rpmfusion_f43_fallback "${rpmfusion_failed[@]}"
else
  log_info "No RPM Fusion packages require F43 fallback"
fi

# ============================================================================
# Special Package Installations
# ============================================================================

log_section "Installing special packages"

# ──────────────────────────────────────────────────────────────────────────
# CrossOver (Commercial Wine Implementation)
# ──────────────────────────────────────────────────────────────────────────

log_info "Installing CrossOver from CodeWeavers"
install_single_package_resilient \
  "http://crossover.codeweavers.com/redirect/crossover.rpm" \
  "crossover"

# ──────────────────────────────────────────────────────────────────────────
# Kora Icon Theme (Custom Build)
# ──────────────────────────────────────────────────────────────────────────

log_info "Installing Kora icon theme (latest release)"

# Get latest release URL
kora_url=$(curl -s https://api.github.com/repos/phantomcortex/kora/releases/latest 2>/dev/null | \
  grep "browser_download_url.*\.rpm" | \
  cut -d '"' -f 4)

if [[ -n "$kora_url" ]]; then
  install_single_package_resilient "$kora_url" "kora-icon-theme"
else
  log_warning "Failed to retrieve Kora theme URL (GitHub API may be down)"
  FAILED_PACKAGES+=("kora-icon-theme")
fi

# ──────────────────────────────────────────────────────────────────────────
# Freeworld RPMs (H.265 support, mesa forced over terra, libheif from F43)
# ──────────────────────────────────────────────────────────────────────────

install_freeworld_rpms

# ============================================================================
# System Upgrade (Best-Effort)
# ============================================================================

log_section "Performing system upgrade (best-effort)"

log_info "Upgrading all packages to latest versions"
if dnf5 -y upgrade &>/dev/null; then
  log_success "System upgrade complete"
else
  log_warning "System upgrade encountered issues (non-critical)"
fi

# ============================================================================
# Critical Package Validation
# ============================================================================
# These packages are essential - report if missing but don't fail build

log_section "Validating critical packages"

readonly -a CRITICAL_PACKAGES=(
  "zsh"
  "totem-video-thumbnailer"
  "Cider"
  "libavcodec-freeworld"
  "gstreamer1-plugins-bad-freeworld"
  "gstreamer1-plugins-ugly"
  "mesa-va-drivers-freeworld"
  "mesa-vulkan-drivers-freeworld"
  "libheif-freeworld"
)

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

# ============================================================================
# Wine Fallback Installation
# ============================================================================
# If Wine failed earlier, try one more time with --skip-broken

if ! rpm -q wine &>/dev/null; then
  log_section "Wine fallback installation"
  log_info "Attempting Wine installation with --skip-broken"
  
  if dnf5 -y install wine --skip-broken &>/dev/null; then
    log_success "Wine installed via fallback method"
    SUCCEEDED_PACKAGES+=("wine")
  else
    log_warning "Wine installation failed even with --skip-broken"
  fi
fi

curl -L "https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip" -o /tmp/Inter.zip
mkdir -p /usr/share/fonts/Inter/
unzip -j /tmp/Inter.zip "InterVariable.ttf" "InterVariable-Italic.ttf" -d /usr/share/fonts/Inter/
rm /tmp/Inter.zip && fc-cache -f

# ============================================================================
# versionlock
# ============================================================================
# while this isn't entirely neccessary, it's good peace of mind 

readonly -a VERSIONLOCK_PACKAGES=(
  "zsh"
  "Cider"
  "lact"
  "file-roller"
  "dcraw"
  "sassc"
)
log_info "versionlock section"
versionlock_failures=0
for pkg in "${VERSIONLOCK_PACKAGES[@]}"; do
  if dnf versionlock add "$pkg" &>/dev/null; then
    log_success "  ✓ $pkg"
  else
    log_warning "  ✗ $pkg (unable to add versionlock)"
    ((versionlock_failures++))
  fi
done

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
log_info "Next: 03-fix-opt.sh will configure /opt persistence"

exit 0
