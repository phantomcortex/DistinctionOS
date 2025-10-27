#!/usr/bin/bash
set -euo pipefail

# CREDIT: https://github.com/ExistingPerson08/amyos-gnome/blob/main/build_files/install-apps.sh
# A good example on what to improve upon


trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
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

# remove current libheif due to heif-type images becoming extremely bright/washed-out
rpm -e --nodeps libheif heif-pixbuf-loader 

# RPM packages list
declare -A RPM_PACKAGES=(
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
    heif-pixbuf-loader"

  ["rpmfusion-free,rpmfusion-free-updates,rpmfusion-nonfree,rpmfusion-nonfree-updates"]="\
    audacity-freeworld \
    libavcodec-freeworld \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    libheif-freeworld"

  ["fedora-multimedia"]="mpv"

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
    cmd=(dnf5 -y install --best)
    [[ -n "$enable_opt" ]] && cmd+=("$enable_opt")
    cmd+=("${pkg_array[@]}")
    "${cmd[@]}"
  fi
done

# Install traditional wine
dnf5 -y install wine --skip-broken
dnf5 versionlock add wine 


# TODO: add ujust recipe for crossover or make custom rpm .spec
dnf5 -y install http://crossover.codeweavers.com/redirect/crossover.rpm 

# upgrade packages since bazzite sometimes ships older packages
dnf5 -y upgrade

# custom kora icon theme
# Install latest release directly with dnf5
dnf5 -y install $(curl -s https://api.github.com/repos/phantomcortex/kora/releases/latest | grep "browser_download_url.*\.rpm" | cut -d '"' -f 4)
