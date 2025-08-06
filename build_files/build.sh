#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
: '
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flatpak_apps=(
    "info.cemu.Cemu" \
    "com.mattjakeman.ExtensionManager" \
    "com.ranfdev.DistroShelf" \
    "com.github.tchx84.Flatseal" \
    "io.missioncenter.MissionCenter" \
    "com.vysp3r.ProtonPlus" \
    "org.DolphinEmu.dolphin-emu" \
    "org.onlyoffice.desktopeditors" \
    "rs.ruffle.Ruffle" \
    "com.steamgriddb.SGDBoop" \
    "io.github.nokse22.Exhibit" \
    "me.proton.Mail"
)
'
for app in "${flatpak_apps[@]}"; do
    echo "Installing $app..."
    flatpak install -y --noninteractive flathub "$app"
done

RED='\033[31m'
NC='\033[0m'
# Define the COPR repo and package
dnf5 -y config-manager setopt "*rpmfusion*".enabled=1 #bazzite seems to have some of rpmfusion repos disabled from their base images; Words cannot accurately describe how much this infuriated me  
if ! dnf repolist | grep -q "copr:copr.fedorainfracloud.org:bazzite-org:rom-properties"; then
  dnf5 copr enable -y bazzite-org/rom-properties
  dnf5 -y install rom-properties
fi
                        
dnf5 -y copr enable monkeygold/nautilus-open-any-terminal
dnf5 -y install nautilus-open-any-terminal
# extras
AUDACITY_FREEWORLD="audacity-freeworld" #this exists due to dnf failing to find certain rpmfusion packages sometimes
AUDACITY_RPM_URL="https://mirror.fcix.net/rpmfusion/free/fedora/releases/42/Everything/x86_64/os/Packages/a/audacity-freeworld-3.7.3-1.fc42.x86_64.rpm"

echo "Attempting to install '${AUDACITY_FREEWORLD}' via standard DNF..."
if dnf5 -y install "$AUDACITY_FREEWORLD"; then
    echo "✅ Package '${AUDACITY_FREEWORLD}' installed successfully."
else
    echo "⚠️ Standard DNF install failed. Attempting direct RPM install from URL..."
    if dnf5 -y install "$AUDACITY_RPM_URL"; then
        echo "✅ Package installed successfully from URL."
    else
        echo "❌ Failed to install '${AUDACITY_FREEWORLD}' via both methods."
        exit 1
    fi
fi

LIBHEIF_FREEWORLD="libheif-freeworld"
LIBHEIF_RPM_URL="https://ftp-stud.hs-esslingen.de/pub/Mirrors/rpmfusion.org/free/fedora/releases/42/Everything/x86_64/os/Packages/l/libheif-freeworld-1.19.7-1.fc42.x86_64.rpm"

echo "Attempting to install '${LIBHEIF_FREEWORLD}' via standard DNF..."
if dnf5 -y install "$LIBHEIF_FREEWORLD"; then
    echo "✅ Package '${LIBHEIF_FREEWORLD}' installed successfully."
else
    echo "⚠️ Standard DNF install failed. Attempting direct RPM install from URL..."
    if dnf5 -y install "$LIBHEIF_RPM_URL"; then
        echo "✅ Package installed successfully from URL."
    else
        echo "❌ Failed to install '${LIBHEIF_FREEWORLD}' via both methods."
        exit 1
    fi
fi

LIBAVCODEC_FREEWORLD="libavcodec-freeworld"
LIBAVCODEC_RPM_URL="https://muug.ca/mirror/rpmfusion/free/fedora/releases/42/Everything/x86_64/os/Packages/l/libavcodec-freeworld-7.1.1-5.fc42.x86_64.rpm"

echo "Attempting to install '${LIBAVCODEC_FREEWORLD}' via standard DNF..."
if dnf5 -y install "$LIBAVCODEC_FREEWORLD"; then
    echo "✅ Package '${LIBAVCODEC_FREEWORLD}' installed successfully."
else
    echo "⚠️ Standard DNF install failed. Attempting direct RPM install from URL..."
    if dnf5 -y install "$LIBAVCODEC_RPM_URL"; then
        echo "✅ Package installed successfully from URL."
    else
        echo "❌ Failed to install '${LIBAVCODEC_FREEWORLD}' via both methods."
        exit 1
    fi
fi

GSP_UGLY="gstreamer1-plugins-ugly"
GSP_UGLY_RPM_URL="https://muug.ca/mirror/rpmfusion/free/fedora/releases/42/Everything/x86_64/os/Packages/g/gstreamer1-plugins-ugly-1.26.0-1.fc42.x86_64.rpm"

echo "Attempting to install '${GSP_UGLY}' via standard DNF..."
if dnf5 -y install "$GSP_UGLY"; then
    echo "✅ Package '${GSP_UGLY}' installed successfully."
else
    echo "⚠️ Standard DNF install failed. Attempting direct RPM install from URL..."
    if dnf5 -y install "$GSP_UGLY_RPM_URL"; then
        echo "✅ Package installed successfully from URL."
    else
        echo "❌ Failed to install '${GSP_UGLY}' via both methods."
        exit 1
    fi
fi

GSP_BAD_FREEWORLD="gstreamer1-plugins-bad-freeworld"
GSP_BAD_FREEWORLD_RPM_URL="https://muug.ca/mirror/rpmfusion/free/fedora/releases/42/Everything/x86_64/os/Packages/g/gstreamer1-plugins-bad-freeworld-1.26.0-1.fc42.x86_64.rpm"

echo "Attempting to install '${GSP_BAD_FREEWORLD}' via standard DNF..."
if dnf5 -y install "$GSP_BAD_FREEWORLD"; then
    echo "✅ Package '${GSP_BAD_FREEWORLD}' installed successfully."
else
    echo "⚠️ Standard DNF install failed. Attempting direct RPM install from URL..."
    if dnf5 -y install "$GSP_BAD_FREEWORLD_RPM_URL"; then
        echo "✅ Package installed successfully from URL."
    else
        echo "❌ Failed to install '${GSP_BAD_FREEWORLD}' via both methods."
        exit 1
    fi
fi

copr_repos=('ilyaz/LACT' 'fernando-debian/dysk' 'atim/nushell')

install_packages=(python3-icoextract \
  rom-properties-gtk3 \
  tealdeer \
  gtk-murrine-engine \
  gnome-tweaks \
  dconf \
  mpv \
  decibels \
  libheif-tools \
  heif-pixbuf-loader \
  gstreamer1-plugins-good-extras \
  ffmpegthumbnailer \
  x265 \
  file-roller \
  evince \
  loupe \
  blender
  zoxide \
  nvim \
  rust \
  cargo \
  zsh \
  zsh-autosuggestions \
  zsh-syntax-highlighting \
  blackbox-terminal \
  clapper \
  totem-video-thumbnailer \
  VirtualBox \
  zfs-fuse \
  apfs-fuse \
  ardour8 \
  ffmpeg \
  make \
  lact \
  dysk \
  nushell \
  meson \
  binutils \
  make \
  cmake \
  sassc \
  dkms \
  jq)




: <<'END_COMMENT'
for repo in "${copr_repos[@]}"; do
  if ! dnf repolist |grep -e '$repo'
      dnf5 copr enable -y "$repo"
      echo "enabling copr $repo"
  fi 
done
END_COMMENT
dnf5 copr enable -y ilyaz/LACT
dnf5 copr enable -y fernando-debian/dysk
dnf5 copr enable -y atim/nushell

for pkg in "${install_packages[@]}"; do
    if ! rpm -q "$pkg" &>/dev/null; then
        echo "Installing $pkg..."
        dnf5 -y install "$pkg"
    else
      echo "$pkg Already Installed ✅"
    fi
done

remove_packages=(waydroid \
  sunshine \
  gnome-shell-extension-compiz-windows-effect \
  gnome-shell-extension-compiz-alike-magic-lamp-effect \
  openssh-askpass \
  dkms)

for pkg in "${remove_packages[@]}"; do
  if rpm -q "$pkg" &>/dev/null; then
    echo "Removing $pkg..."
    dnf5 -y remove "$pkg"
  fi 
done 

# import Cider Music app (Apple Music)
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
dnf -y install Cider

sed -i 's@Icon=Cider@/usr/share/icons/kora/apps/scalable/cider.svg@g' /usr/share/applications/Cider.desktop

#==Crossover

rm -rf /opt
# remove link so installing crossover is possible
mkdir -p /opt/cxoffice 
dnf -y install http://crossover.codeweavers.com/redirect/crossover.rpm
mv /opt/cxoffice /var/opt/
# Crossover Requires a license file so It needs to be writable
# in theory this should be handled in fix_opt.sh
# relink
rm -rf /opt
ln -s /opt /var/opt

#according to claude If I want certain flatpak apps pre-installed I need to manually layer them -
# in my build scripts or containerfile
#flatpak

#DEBUG
echo -e "\033[31mDNF CHECK UPDATE\033[0m"
if ! dnf check-update --refresh; then
    code=$?
    if [ "$code" -ne 100 ]; then
        echo "dnf check-update failed with error code $RED$code"
        exit $code
    else
        echo "Updates are available (exit code $RED 100$NC), continuing..."
    fi
else
    echo "No updates available."
fi


#### Example for enabling a System Unit File

systemctl enable podman.socket

