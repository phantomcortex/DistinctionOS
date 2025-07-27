#!/bin/bash

set -ouex pipefail

RED='\033[0;31m'
NC='\033[0m'
ORANGE='\033[0;33m'
CRITICAL='\033[31;5m'
### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos

# Define the COPR repo and package
dnf5 -y config-manager setopt "*rpmfusion*".enabled=1 
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

dnf5 -y remove totem
# for 
#
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
  ardour8)

for pkg in "${install_packages[@]}"; do
    if ! rpm -q "$pkg" &>/dev/null; then
        echo "Installing $pkg..."
        dnf5 -y install "$pkg"
    fi
done

remove_packages=(waydroid \
  sunshine \
  gnome-classic-session \
  gnome-tour \
  gnome-extensions-app \
  gnome-system-monitor \
  gnome-initial-setup \
  gnome-shell-extension-background-logo \
  gnome-shell-extension-apps-menu)

for pkg in "${remove_packages[@]}"; do
  if ! rpm -q "$pkg" &>/dev/null; then
    echo "Removing $pkg..."
    dnf5 -y remove "$pkg"
  fi 
done 

#ffmpeg includes non-free/patent encumbered codecs
#should allow for ffmpeg & libavcodec-freeworld to be installed simultaneously
dnf5 -y install ffmpeg --allowerasing

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

# Gonna try something courtesy of this pull: https://github.com/ublue-os/image-template/pull/100
mkdir -p /usr/share/factory/var/opt
#==
mkdir -p /var/opt/cxoffice
mkdir -p /opt/cxoffice 
dnf -y install http://crossover.codeweavers.com/redirect/crossover.rpm
# Crossover Requires a license file so It needs to be writable
# Crossover doesn't seem to appear on my bazzite image nor does anything installed to /opt

# Brave Browser 
#dnf5 -y install dnf-plugins-core
#dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
#dnf5 -y install brave-browser

echo -e "\e[31mDEBUG:\e[0m"
# is opt2 a good solution? definitly not. I'd still strongly prefer crossover to be natively installed rather a container
# I'll have to think of a cleaner solution
ls /opt
mv /opt/cxoffice /opt2
echo -e "\e[31mDEBUG:\e[0m"
ls /opt2

# internal copr repos
dnf5 -y copr enable ilyaz/LACT
dnf5 -y install lact
dnf5 -y copr enable fernando-debian/dysk
dnf5 -y install dysk
dnf5 -y copr enable atim/nushell
dnf5 -y install nushell

dnf5 -y copr enable atim/xpadneo
dnf5 -y install xpadneo
# Note: I've previously used sentry's xpadneo kmod but it's not signed so secure boot won't work
# it's unclear if atim's xpadneo is signed, but I doubt it severely.
# depending on if it install kmod to to the kernel correctly 
# I might have to run some extra commands to make sure this kernel module is loaded
#
#########################################################################


# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

