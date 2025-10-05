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
# TODO: Rebrand Bazzite things to DistinctionOS
# TODO: Figure out why certain packages seem to be omitted during install

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
    bat \
    evince \
    loupe \
    zoxide \
    ardour8 \
    sassc \
    blackbox-terminal \
    gstreamer1-plugins-good-extras
    heif-pixbuf-loader \
    libheif-tools \
    decibels \
    dconf \
    gtk-murrine-engine \
    glib2-devel \
    perl-File-Copy \
    winetricks \
    lutris"

  ["rpmfusion-free,rpmfusion-free-updates,rpmfusion-nonfree,rpmfusion-nonfree-updates"]="\
    audacity-freeworld \
    libheif-freeworld \
    libavcodec-freeworld \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly"

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

dnf5 -y install \
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
    docker-compose \
    flatpak-builder \
    gnome-tweaks \
    sane-backends-libs.i686 \
    sane-backends-libs.x86_64 \
    sox \
    totem-video-thumbnailer \
    mediainfo \
    perl-Image-ExifTool


# Install ZFS 
dnf -y install zfs

# remove bazzite things intended for waydroid
find /usr/share/applications -iname '*waydroid*' -exec rm -rf {} + 

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

# custom kora icon theme

# Install latest release directly with dnf5
dnf5 -y install $(curl -s https://api.github.com/repos/phantomcortex/kora/releases/latest | grep "browser_download_url.*\.rpm" | cut -d '"' -f 4)
# Winboat (Added @ 0.7.11)
dnf5 -y install $(curl -s https://api.github.com/repos/TibixDev/winboat/releases/latest | grep "browser_download_url.*\.rpm" | cut -d '"' -f 4)


