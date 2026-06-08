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
# Guard: disallow `--allowerasing`
# ============================================================================
# --allowerasing lets dnf silently remove packages to satisfy an install, which
# can clobber required packages. Wrap dnf/dnf5 so any future use is rejected.
#
# Narrow exception: the freeworld codec stack (libavcodec-freeworld,
# mesa-*-freeworld, gstreamer1-plugins-bad-freeworld) overlaps file paths
# with the Fedora "free" variants, so a clean install requires removing the
# free variant first. The dnf_codec_swap() function in the codec section
# bypasses these wrappers via `command dnf5` after validating that the
# swap is between a specific known-safe pair — see CODEC_SWAP_ALLOWLIST.

dnf() {
  local arg
  for arg in "$@"; do
    if [[ "$arg" == "--allowerasing" ]]; then
      log_error "Refusing to run dnf with --allowerasing (disallowed in this build)"
      return 1
    fi
  done
  command dnf "$@"
}

dnf5() {
  local arg
  for arg in "$@"; do
    if [[ "$arg" == "--allowerasing" ]]; then
      log_error "Refusing to run dnf5 with --allowerasing (disallowed in this build)"
      return 1
    fi
  done
  command dnf5 "$@"
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

# Note: Cider (cidercollective repo) and CrossOver are no longer installed
# here — they are pre-built into the distinctionos-cache OCI artifact (see
# .github/cache-builder/packages.txt) and installed by 03-cache-install.sh.

log_info "CLEAR VERSIONLOCK"
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
# Create Required Directories
# ============================================================================

log_section "Creating required directories"

create_dir_with_log "/var/opt" "Package directory for 06-fix-opt.sh"

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
    loupe \
    sassc \
    gstreamer1-plugins-good-extras \
    decibels \
    dconf \
    gtk-murrine-engine \
    perl-File-Copy \
    winetricks \
    lutris \
    sox \
    totem-video-thumbnailer \
    mediainfo \
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
    id3v2 \
    lhasa \
    lzma \
    meld \
    pandoc-cli \
    rdfind \
    xorriso \
    optipng \
    glib2-devel \
    firejail"

  # vvenc and the freeworld codec stack are installed by the dedicated
  # codec section below — they need atomic resolution against x265 and
  # libavcodec-freeworld in the same transaction.
  ["rpmfusion-free,rpmfusion-free-updates,rpmfusion-nonfree,rpmfusion-nonfree-updates"]="\
    gstreamer1-plugins-ugly"

  ["terra,terra-extras"]=" \
    gstreamer1-vaapi \
    mesa-libgbm \
    mesa-libEGL \
    mesa-libgbm-devel \
    mesa-libEGL-devel"
  
  # Fedora Multimedia (optimized multimedia packages)
  ["fedora-multimedia"]="mpv"

  # Third-party repositories
  ["brave-browser"]="brave-browser"
)

# Install packages from standard repositories
for repo in "${!RPM_PACKAGES[@]}"; do
  read -ra pkg_array <<<"${RPM_PACKAGES[$repo]}"
  install_packages_resilient "$repo" "${pkg_array[@]}"
done

# ──────────────────────────────────────────────────────────────────────────
# Codec Stack — atomic swap to RPMFusion freeworld variants
# ──────────────────────────────────────────────────────────────────────────
# Why this lives here, not in the force-install OCI artifact:
#
# libavcodec-freeworld, gstreamer1-plugins-bad-freeworld, and the
# mesa-*-freeworld pair link against versioned symbols from x265 and vvenc
# (e.g. x265_api_get_215, libvvenc.so.1.13). When these RPMs were snapshotted
# in the force-install artifact — which builds on a separate schedule from
# the main image — the captured .so files reference symbol versions that
# no longer exist on the rolling Bazzite base, producing runtime errors:
#
#   ffmpeg: error while loading shared libraries: libvvenc.so.1.13
#   ffmpeg: symbol lookup error: ... undefined symbol: x265_api_get_215
#
# Installing the whole freeworld codec stack in a single dnf transaction
# against the live repos co-resolves them with their current x265/vvenc
# dependencies — versions match by construction, no skew possible.

log_section "Installing freeworld codec stack"

# Narrowly-scoped escape hatch for the --allowerasing guard.
# Calls `command dnf5` directly (bypassing the wrapper) but only after
# validating that the swap pair is in CODEC_SWAP_ALLOWLIST. Any other use
# of --allowerasing remains blocked by the dnf/dnf5 wrappers above.
readonly -a CODEC_SWAP_ALLOWLIST=(
  "ffmpeg-free|ffmpeg"
  "libavcodec-free|libavcodec-freeworld"
  "libavdevice-free|libavdevice-freeworld"
  "libavfilter-free|libavfilter-freeworld"
  "libavformat-free|libavformat-freeworld"
  "libavutil-free|libavutil-freeworld"
  "libpostproc-free|libpostproc-freeworld"
  "libswresample-free|libswresample-freeworld"
  "libswscale-free|libswscale-freeworld"
  "mesa-va-drivers|mesa-va-drivers-freeworld"
  "mesa-vulkan-drivers|mesa-vulkan-drivers-freeworld"
  "gstreamer1-plugins-bad-free|gstreamer1-plugins-bad-freeworld"
  "gstreamer1-plugins-bad-free-extras|gstreamer1-plugins-bad-freeworld-extras"
)

dnf_codec_swap() {
  local from="$1" to="$2"
  local pair="${from}|${to}"

  local allowed=false
  for entry in "${CODEC_SWAP_ALLOWLIST[@]}"; do
    [[ "$entry" == "$pair" ]] && allowed=true && break
  done

  if ! $allowed; then
    log_error "  ✗ dnf_codec_swap: '$from' → '$to' not in allowlist"
    FAILED_PACKAGES+=("$to")
    return 1
  fi

  # If source isn't installed, fall back to a plain install of the target.
  # This handles bases that already ship the freeworld variant, or where
  # the -free counterpart was never installed.
  if ! rpm -q "$from" &>/dev/null; then
    if command dnf5 -y install "$to" &>/dev/null; then
      log_success "  ✓ $to (direct install — no $from present)"
      SUCCEEDED_PACKAGES+=("$to")
      return 0
    fi
    log_warning "  ✗ $to (direct install failed)"
    FAILED_PACKAGES+=("$to")
    return 1
  fi

  # Source installed → swap. --allowerasing lets dnf remove the source
  # if the target's file list overlaps. The allowlist above bounds the
  # blast radius to known-safe codec pairs.
  if command dnf5 -y swap "$from" "$to" --allowerasing &>/dev/null; then
    log_success "  ✓ $from → $to"
    SUCCEEDED_PACKAGES+=("$to")
    return 0
  fi

  log_warning "  ✗ $from → $to (swap failed)"
  FAILED_PACKAGES+=("$to")
  return 1
}

# Order: top-level meta-packages first (ffmpeg pulls the libav* family),
# then GPU driver swaps, then the standalone libavcodec/gstreamer adders.
dnf_codec_swap "ffmpeg-free"                "ffmpeg"
dnf_codec_swap "mesa-va-drivers"            "mesa-va-drivers-freeworld"
dnf_codec_swap "mesa-vulkan-drivers"        "mesa-vulkan-drivers-freeworld"
dnf_codec_swap "libavcodec-free"            "libavcodec-freeworld"
dnf_codec_swap "gstreamer1-plugins-bad-free" "gstreamer1-plugins-bad-freeworld"

# vvenc and svt-av1 round out the encoder set. They have no -free counterpart
# (RPMFusion-only), so a plain install is correct — it co-resolves with the
# freeworld libavcodec just installed, guaranteeing matching sonames.
log_info "Installing standalone codec libraries (vvenc, svt-av1)"
if command dnf5 -y install vvenc vvenc-libs svt-av1-libs &>/dev/null; then
  log_success "  ✓ vvenc, vvenc-libs, svt-av1-libs"
  SUCCEEDED_PACKAGES+=("vvenc" "vvenc-libs" "svt-av1-libs")
else
  log_warning "  ✗ vvenc/svt-av1 install failed (codec encoders may be missing)"
  FAILED_PACKAGES+=("vvenc")
fi

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
# Freeworld RPMs (libheif-freeworld from F43 — not yet in F44)
# ──────────────────────────────────────────────────────────────────────────

install_freeworld_rpms


# ============================================================================
# Critical Package Validation
# ============================================================================
# These packages are essential - report if missing but don't fail build

log_section "Validating critical packages"

readonly -a CRITICAL_PACKAGES=(
  "zsh"
  "podman"
  "steam.i686"
  "steam-devices"
  "gnome-shell"
  "gnome-session"
  "vulkan-headers"
  "mesa-vulkan-drivers-freeworld"  # post-swap: replaces mesa-vulkan-drivers
  "mesa-va-drivers-freeworld"      # post-swap: replaces mesa-va-drivers
  "mesa-filesystem"
  "mesa-dri-drivers"
  "mesa-libGL"
  "mesa-libEGL"
  "mesa-libgbm"
  "mesa-libgbm-devel"
  "mesa-libEGL"
  "mesa-libEGL-devel"
  "ffmpeg"
  "libavcodec-freeworld"           # codec stack: patent-encumbered encoders
  "vvenc-libs"                     # H.266/VVC encoder runtime
  "gstreamer1-plugins-bad-freeworld"
  "mutter"
  "wayland-devel"
  "ScopeBuddy"
  "terra-gamescope"
  "SDL3"
  "glib2"
  "glib2-devel"
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
  "podman"
  "lact"
  "file-roller"
  "dcraw"
  "sassc"
  "steam"
  "steam-devices"
  "gnome-shell"
  "gnome-session"
  "vulkan-headers"
  "mesa-vulkan-drivers-freeworld"  # post-swap name
  "mesa-va-drivers-freeworld"      # post-swap name
  "mesa-filesystem"
  "mesa-dri-drivers"
  "mesa-libGL"
  "mesa-libEGL"
  "mesa-libgbm"
  "mesa-libgbm-devel"
  "mesa-libEGL"
  "mesa-libEGL-devel"
  "ffmpeg"
  "libavcodec-freeworld"
  "vvenc"
  "vvenc-libs"
  "gstreamer1-plugins-bad-freeworld"
  "mutter"
  "wayland-devel"
  "ScopeBuddy"
  "terra-gamescope"
  "gcc"
  "SDL3"
  "glib2"
  "glib2-devel"
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
log_info "Next: 03-cache-install.sh will install pre-cached RPMs"

exit 0
