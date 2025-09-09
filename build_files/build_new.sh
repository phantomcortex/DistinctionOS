#!/usr/bin/bash
set -euo pipefail

# CREDIT: https://github.com/ExistingPerson08/amyos-gnome/blob/main/build_files/install-apps.sh
# A good example on what to improve upon

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}


#remove pesky bazzite things
remove_packages=(waydroid \
  sunshine \
  gnome-shell-extension-compiz-windows-effect \
  openssh-askpass \
  cockpit-bridge \
  zfs-fuse)
# TODO: remove askpass envs (and other Bazzite envs)
# TODO: Rebrand Bazzite things to DistinctionOS

for pkg in "${remove_packages[@]}"; do
  if rpm -q "$pkg" &>/dev/null; then
    echo "Removing $pkg..."
    dnf5 -y remove "$pkg"
  fi 
done 


# ZFS filesystem driver 
dnf install -y https://zfsonlinux.org/fedora/zfs-release-2-8.fc42.noarch.rpm   

#=================Cider=====================
# Cider workaround because I don't want to \ 
# mess with the main installer portion
rpm --import https://repo.cider.sh/RPM-GPG-KEY

tee /etc/yum.repos.d/cider.repo << 'EOF'
[cidercollective]
name=Cider Collective Repository
baseurl=https://repo.cider.sh/rpm/RPMS
enabled=1
gpgcheck=1
gpgkey=https://repo.cider.sh/RPM-GPG-KEY
EOF

dnf makecache
#=================Cider=====================
# RPM packages list
declare -A RPM_PACKAGES=(
  ["fedora"]="\
    yt-dlp \
    zsh \
    zsh-syntax-highlighting \
    zsh-autosuggestions \
    neovim \
    file-roller \
    evince \
    loupe \
    zoxide \
    apfs-fuse \
    ardour8 \
    sassc \
    blackbox-terminal \
    gstreamer1-plugins-good-extras
    heif-pixbuf-loader \
    libheif-tools \
    decibels \
    dconf \
    gtk-murrine-engine \
    gnome-tweaks \
    glib2-devel \
    perl-File-Copy \
    winetricks \
    clang \
    lutris \
    virt-manager \
    dkms \
    nss-mdns.i686 \
    pcsc-lite-libs.i686 \
    freerdp \
    dialog \
    iproute \
    libnotify \
    nmap-ncat \
    wl-paste \
    pandoc \
    docker \
    docker-compose"

  ["rpmfusion-free,rpmfusion-free-updates,rpmfusion-nonfree,rpmfusion-nonfree-updates"]="\
    audacity-freeworld \
    libheif-freeworld \
    libavcodec-freeworld \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    VirtualBox"

  ["fedora-multimedia"]="\
    mpv \
    clapper"

  ["brave-browser"]="brave-browser"
  ["cidercollective"]="Cider"
  ["copr:ilyaz/LACT"]="lact"
  ["copr:fernando-debian/dysk"]="dysk"
  ["copr:atim/heroic-games-launcher"]="heroic-games-launcher-bin"
  ["copr:sergiomb/clonezilla"]="clonezilla"
  ["copr:alternateved/eza"]="eza"
)

log "Starting DistinctionOS build process"

log "Installing RPM packages"
mkdir -p /var/opt
for repo in "${!RPM_PACKAGES[@]}"; do
  read -ra pkg_array <<<"${RPM_PACKAGES[$repo]}"
  if [[ $repo == copr:* ]]; then
    # Handle COPR packages
    copr_repo=${repo#copr:}
    dnf5 -y copr enable "$copr_repo"
    dnf5 -y install "${pkg_array[@]}"
    dnf5 -y copr disable "$copr_repo"
  else
    # Handle regular packages
    [[ $repo != "fedora" ]] && enable_opt="--enable-repo=$repo" || enable_opt=""
    cmd=(dnf5 -y install)
    [[ -n "$enable_opt" ]] && cmd+=("$enable_opt")
    cmd+=("${pkg_array[@]}")
    "${cmd[@]}"
  fi
done

#=================SANITY CHECKER & BACKUP INSTALLER=================
log "Running package installation sanity check"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track failed packages
declare -a FAILED_PACKAGES=()
declare -a MISSING_PACKAGES=()

# Function to check if package is installed
check_package_installed() {
  local pkg="$1"
  # Handle i686 architecture packages
  if [[ "$pkg" == *.i686 ]]; then
    rpm -q "$pkg" &>/dev/null || rpm -q "${pkg%.i686}.i686" &>/dev/null
  else
    rpm -q "$pkg" &>/dev/null
  fi
}

# Iterate through all packages and verify installation
log "Verifying package installations"
for repo in "${!RPM_PACKAGES[@]}"; do
  read -ra pkg_array <<<"${RPM_PACKAGES[$repo]}"
  for pkg in "${pkg_array[@]}"; do
    # Skip empty entries
    [[ -z "$pkg" ]] && continue
    
    # Special handling for certain packages with different installed names
    case "$pkg" in
      "gstreamer1-plugins-good-extras")
        # This might be part of a metapackage
        if ! rpm -q gstreamer1-plugins-good &>/dev/null; then
          MISSING_PACKAGES+=("$pkg")
        fi
        ;;
      "heroic-games-launcher-bin")
        # Check for heroic-games-launcher or heroic-games-launcher-bin
        if ! rpm -q heroic-games-launcher &>/dev/null && ! rpm -q heroic-games-launcher-bin &>/dev/null; then
          MISSING_PACKAGES+=("$pkg")
        fi
        ;;
      *)
        if ! check_package_installed "$pkg"; then
          MISSING_PACKAGES+=("$pkg")
        fi
        ;;
    esac
  done
done

# Report findings
if [[ ${#MISSING_PACKAGES[@]} -eq 0 ]]; then
  echo -e "${GREEN}✓ All packages verified successfully${NC}"
else
  echo -e "${YELLOW}⚠ Found ${#MISSING_PACKAGES[@]} missing packages${NC}"
  echo "Missing packages:"
  printf '%s\n' "${MISSING_PACKAGES[@]}"
  
  # Backup installer - attempt to install missing packages individually
  log "Attempting backup installation of missing packages"
  
  for pkg in "${MISSING_PACKAGES[@]}"; do
    echo -e "${YELLOW}Attempting to install: $pkg${NC}"
    
    # Determine which repo the package belongs to
    pkg_repo=""
    for repo in "${!RPM_PACKAGES[@]}"; do
      if [[ "${RPM_PACKAGES[$repo]}" == *"$pkg"* ]]; then
        pkg_repo="$repo"
        break
      fi
    done
    
    # Try to install the package
    if [[ -n "$pkg_repo" ]]; then
      if [[ $pkg_repo == copr:* ]]; then
        copr_repo=${pkg_repo#copr:}
        if dnf5 -y copr enable "$copr_repo" && dnf5 -y install "$pkg"; then
          echo -e "${GREEN}✓ Successfully installed $pkg${NC}"
        else
          echo -e "${RED}✗ Failed to install $pkg${NC}"
          FAILED_PACKAGES+=("$pkg")
        fi
        dnf5 -y copr disable "$copr_repo"
      elif [[ $pkg_repo == "fedora" ]]; then
        if dnf5 -y install "$pkg"; then
          echo -e "${GREEN}✓ Successfully installed $pkg${NC}"
        else
          echo -e "${RED}✗ Failed to install $pkg${NC}"
          FAILED_PACKAGES+=("$pkg")
        fi
      else
        # Handle repos with comma-separated names
        enable_repos="${pkg_repo//,/ --enable-repo=}"
        if dnf5 -y install --enable-repo=$enable_repos "$pkg"; then
          echo -e "${GREEN}✓ Successfully installed $pkg${NC}"
        else
          echo -e "${RED}✗ Failed to install $pkg${NC}"
          FAILED_PACKAGES+=("$pkg")
        fi
      fi
    else
      # Package repo not found, try default installation
      if dnf5 -y install "$pkg"; then
        echo -e "${GREEN}✓ Successfully installed $pkg${NC}"
      else
        echo -e "${RED}✗ Failed to install $pkg (no repo found)${NC}"
        FAILED_PACKAGES+=("$pkg")
      fi
    fi
  done
  
  # Final report
  if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
    echo -e "${RED}⚠ WARNING: The following packages could not be installed:${NC}"
    printf '%s\n' "${FAILED_PACKAGES[@]}"
    echo -e "${YELLOW}These packages may require manual intervention or may not be available.${NC}"
    # Log to file for later review
    printf '%s\n' "${FAILED_PACKAGES[@]}" > /var/log/distinction-failed-packages.log
    echo "Failed packages have been logged to /var/log/distinction-failed-packages.log"
  else
    echo -e "${GREEN}✓ All missing packages were successfully installed on backup attempt${NC}"
  fi
fi

# Additional verification for critical packages
log "Verifying critical package installations"
CRITICAL_PACKAGES=(
  "zsh"
  "neovim"
  "lutris"
  "virt-manager"
  "dkms"
  "docker"
)

for pkg in "${CRITICAL_PACKAGES[@]}"; do
  if check_package_installed "$pkg"; then
    echo -e "${GREEN}✓ Critical package $pkg is installed${NC}"
  else
    echo -e "${RED}✗ CRITICAL: Package $pkg is NOT installed${NC}"
    # Attempt one more installation with verbose output
    echo "Attempting critical package recovery for $pkg..."
    dnf5 -y install "$pkg" || echo -e "${RED}Failed to recover $pkg - manual intervention required${NC}"
  fi
done

#=================END SANITY CHECKER=================

# Install ZFS 
dnf -y install zfs

# remove bazzite things intended for waydroid
find /usr -iname '*waydroid*' -exec rm -rf {} + 

# custom icon for Cider because it doesn't seem to use it regardless of what icon theme is used
sed -i 's@Icon=Cider@Icon=/usr/share/icons/kora/apps/scalable/cider.svg@g' /usr/share/applications/Cider.desktop

# modify winetricks due to winetricks telling me 'You are using 64 bit verb' or 'You seem to be using wow64 mode!' five-thousand times... 
if [ -f /usr/share/applications/winetricks.desktop ]; then 
  sed -i 's@Exec=winetricks --gui@Exec=/usr/bin/env WINEDEBUG-all winetricks -q --gui@g' /usr/share/applications/winetricks.desktop
else
  echo "winetricks.desktop does not exist for some reason"
  if [ rpm -q winetricks ]; then 
    tee /usr/share/applications/winetricks.desktop << 'EOF'
[Desktop Entry]
Name=Winetricks
Comment=Work around problems and install applications under Wine
Exec=/usr/bin/env WINEDEBUG=-all winetricks -q --gui
Terminal=false
Icon=winetricks
Type=Application
Categories=Utility;
EOF
  fi
fi

if [[ ! -d /var/opt ]]; then
  echo -e "$RED /var/opt does not exist for some reason...\n $CYAN CREATING... $NC"
  mkdir -p /var/opt
fi #sanity check

dnf5 -y install http://crossover.codeweavers.com/redirect/crossover.rpm 

# The follwing is opensnitch, a per process firewall which can be disabled at any time.
#dnf5 -y install https://raw.githubusercontent.com/evilsocket/opensnitch/releases/download/v1.7.2/opensnitch-1.7.2-1.x86_64.rpmfusion-free

# custom kora icon theme
dnf5 -y install https://github.com/phantomcortex/kora/releases/download/1.6.5.12/kora-icon-theme-1.6.5.12-1.fc42.noarch.rpm
