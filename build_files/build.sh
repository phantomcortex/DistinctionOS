#!/usr/bin/bash
set -euo pipefail


# ============================================================================
# DistinctionOS Build Script - Package Management & Repository Configuration
# ============================================================================
# Install system packages, configure repositories, manage package removal
# ============================================================================

# Enable command tracing for debugging (excludes echo/log commands)
trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

# ============================================================================
# Logging Functions with Color Coding
# ============================================================================

# ANSI color codes
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[31m'
readonly COLOR_GREEN='\033[32m'
readonly COLOR_YELLOW='\033[33m'
readonly COLOR_BLUE='\033[34m'
readonly COLOR_MAGENTA='\033[35m'
readonly COLOR_CYAN='\033[36m'

log_header() {
  echo -e "${COLOR_BLUE}╔════════════════════════════════════════════════════════════════════╗${COLOR_RESET}"
  echo -e "${COLOR_BLUE}║${COLOR_RESET} $* "
  echo -e "${COLOR_BLUE}╚════════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
}

log_section() {
  echo -e "\n${COLOR_CYAN}▶ $*${COLOR_RESET}"
}

log_success() {
  echo -e "${COLOR_GREEN}✓ $*${COLOR_RESET}"
}

log_warning() {
  echo -e "${COLOR_YELLOW}⚠ $*${COLOR_RESET}"
}

log_error() {
  echo -e "${COLOR_RED}✗ $*${COLOR_RESET}" >&2
}

log_info() {
  echo -e "${COLOR_MAGENTA}ℹ $*${COLOR_RESET}"
}

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

# ============================================================================
# Validation Functions
# ============================================================================

validate_package_installed() {
  local package="$1"
  if rpm -q "$package" &>/dev/null; then
    log_success "$package installed successfully"
    return 0
  else
    log_warning "$package installation could not be verified"
    return 1
  fi
}

validate_critical_packages() {
  local -a critical_packages=("$@")
  local failed=0
  
  for pkg in "${critical_packages[@]}"; do
    if ! rpm -q "$pkg" &>/dev/null; then
      log_error "Critical package missing: $pkg"
      ((failed++))
    fi
  done
  
  if [[ $failed -gt 0 ]]; then
    log_error "$failed critical package(s) failed to install"
    return 1
  fi
  
  log_success "All critical packages validated"
  return 0
}

#remove pesky bazzite things
#zfs-fuse conflicts zfs kernel module
remove_packages=(waydroid \
  sunshine \
  gnome-shell-extension-compiz-windows-effect \
  openssh-askpass \
  zfs-fuse)

for pkg in "${remove_packages[@]}"; do
  if rpm -q "$pkg" &>/dev/null; then
    echo "Removing $pkg..."
    dnf5 -y remove "$pkg"
  fi 
done 


#=================Cider=====================
# Cider workaround because I don't want to \ 
# mess with the main installer portion
#
log_info "Adding Cider Collective repository"
rpm --import https://repo.cider.sh/RPM-GPG-KEY

tee /etc/yum.repos.d/cider.repo << 'EOF'
[cidercollective]
name=Cider Collective Repository
baseurl=https://repo.cider.sh/rpm/RPMS
enabled=1
gpgcheck=1
gpgkey=https://repo.cider.sh/RPM-GPG-KEY
EOF


log_success "Cider repository configured"

# Refresh repository metadata
log_info "Refreshing repository metadata"
dnf makecache
log_success "Metadata cache updated"
#=================Cider=====================

# remove current libheif due to heif-type images becoming extremely bright/washed-out
rpm -e --nodeps libheif heif-pixbuf-loader 

# ============================================================================
# Package Installation - Organized by Source
# ============================================================================

# Associative array mapping repositories to their packages
# Format: ["repository"]="space-separated package list"
declare -A RPM_PACKAGES=(
  # Core Fedora repositories
  ["fedora"]="\
    yt-dlp \
    zsh \
    zsh-syntax-highlighting \
    zsh-autosuggestions \
    neovim \
    file-roller \
    bat \
    evince \
    loupe \
    zoxide \
    ardour8 \
    sassc \
    blackbox-terminal \
    gstreamer1-plugins-good-extras
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
    dkms \
    nss-mdns.i686 \
    pcsc-lite-libs.i686 \
    freerdp \
    nmap-ncat \
    pandoc \
    docker \
    docker-compose \
    gnome-tweaks \
    sane-backends-libs.i686 \
    sane-backends-libs.x86_64 \
    sox \
    totem-video-thumbnailer \
    mediainfo \
    dcraw \
    perl-Image-ExifTool \
    libheif \
    libheif-tools \
    heif-pixbuf-loader \
    wine"

  ["rpmfusion-free,rpmfusion-free-updates,rpmfusion-nonfree,rpmfusion-nonfree-updates"]="\
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
  
  # COPR repositories (community-maintained packages)
  ["copr:ilyaz/LACT"]="lact"                                    # AMD GPU control
  ["copr:fernando-debian/dysk"]="dysk"                          # Disk usage analyzer
  ["copr:atim/heroic-games-launcher"]="heroic-games-launcher-bin"  # Epic/GOG launcher
  ["copr:sergiomb/clonezilla"]="clonezilla"                     # Disk cloning utility
  ["copr:alternateved/eza"]="eza"                               # Modern ls replacement
)

log "Starting DistinctionOS build process"

log "Installing RPM packages"

# Create directory for /opt packages (required for fix-opt.sh)
mkdir -p /var/opt

# Install packages organized by repository
for repo in "${!RPM_PACKAGES[@]}"; do
  read -ra pkg_array <<<"${RPM_PACKAGES[$repo]}"

  if [[ $repo == copr:* ]]; then
    # Handle COPR packages
    copr_repo=${repo#copr:}
    log_info "Enabling COPR: $copr_repo"
    dnf5 -y copr enable "$copr_repo"
    
    log_info "Installing from $copr_repo: ${pkg_array[*]}"
    if dnf5 -y install "${pkg_array[@]}"; then
      log_success "Installed packages from $copr_repo"
    else
      log_warning "Some packages from $copr_repo may have failed"
    fi
    
    dnf5 -y copr disable "$copr_repo"

  else
    # Handle regular packages
    [[ $repo != "fedora" ]] && enable_opt="--enable-repo=$repo" || enable_opt=""

    log_info "Installing from $repo: ${pkg_array[*]}"
    cmd=(dnf5 -y install --best)
    [[ -n "$enable_opt" ]] && cmd+=("$enable_opt")
    cmd+=("${pkg_array[@]}")
    "${cmd[@]}"

    if "${cmd[@]}"; then
      log_success "Installed packages from $repo"
    else
      log_warning "Some packages from $repo may have failed"
    fi

  fi
done

log_info "Locking Wine and build dependencies to prevent updates"
dnf5 versionlock add wine 

log_info "Current version locks:"
dnf5 versionlock list

[ rpm -q wine ] && log_success "Wine installed and version-locked"

# ============================================================================
# CrossOver Installation
# ============================================================================
# Commercial Wine implementation for running Windows applications
# Note: Direct download from CodeWeavers (not in standard repos)

log_section "Installing CrossOver"

log_info "Downloading and installing CrossOver from CodeWeavers"
if dnf5 -y install http://crossover.codeweavers.com/redirect/crossover.rpm; then
  log_success "CrossOver installed successfully"
else
  log_error "CrossOver installation failed"
fi


# ============================================================================
# System Upgrade
# ============================================================================
# Ensure all packages are at latest versions

log_section "Performing system upgrade"

log_info "Upgrading all packages to latest versions"
if dnf5 -y upgrade; then
  log_success "System upgrade complete"
else
  log_warning "System upgrade encountered issues"
fi 

# ============================================================================
# Validation
# ============================================================================
# Verify critical packages installed correctly

log_section "Validating critical package installation"

readonly -a CRITICAL_PACKAGES=(
  "zsh"
  "neovim"
  "Cider"
  "wine"
  "brave-browser"
  "crossover"
  "totem-video-thumbnailer"
  "libheif"
  "blackbox-terminal"

)

validate_critical_packages "${CRITICAL_PACKAGES[@]}"

# ============================================================================
# Cleanup
# ============================================================================

log_section "Cleaning up package manager cache"

dnf5 clean all
log_success "Cache cleaned"

# custom kora icon theme
# Install latest release directly with dnf5
dnf5 -y install $(curl -s https://api.github.com/repos/phantomcortex/kora/releases/latest | grep "browser_download_url.*\.rpm" | cut -d '"' -f 4)
