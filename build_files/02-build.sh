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
# Refresh Repository Metadata
# ──────────────────────────────────────────────────────────────────────────

log_info "Refreshing repository metadata"
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
    bat \
    evince \
    loupe \
    zoxide \
    sassc \
    blackbox-terminal \
    gstreamer1-plugins-good-extras \
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
    docker \
    docker-compose \
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
    libgda-sqlite"

  ["rpmfusion-free,rpmfusion-free-updates,rpmfusion-nonfree,rpmfusion-nonfree-updates,rpmfusion-free-updates-testing,rpmfusion-nonfree-updates-testing"]="\
    audacity-freeworld \
    libavcodec-freeworld \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    libheif-freeworld"

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
  ["monkeygold/nautilus-open-any-terminal"]="nautilus-open-any-terminal"
)

for copr_repo in "${!COPR_PACKAGES[@]}"; do
  read -ra pkg_array <<<"${COPR_PACKAGES[$copr_repo]}"
  install_copr_resilient "$copr_repo" "${pkg_array[@]}"
done


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
  "neovim"
  "brave-browser"
  "wine"
  "blackbox-terminal"
  "totem-video-thumbnailer"
  "Cider"
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
  "neovim"
  "blackbox-terminal"
  "Cider"
  "eza"
  "dysk"
  "lact"
  "file-roller"
  "bat"
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
  echo "  • Repository downtime (e.g., ZFS repository)"
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
