#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos


dnf5 -y copr enable bazzite-org/rom-properties 
dnf5 -y install rom-properties rom-properties-gtk3


#==========================
# internal package non-sense
dnf5 install -y zoxide \
            gnome-randr-rust \
            gnome-shell-extension-just-perfection \
            gnome-shell-extension-restart-to \
            gnome-shell-extension-burn-my-windows 
            
    # various things
    dnf5 -y install \
        nvim \
        rust \
        cargo \
        zsh \
        zsh-autosuggestions \
        zsh-syntax-highlighting \
        blackbox-terminal
        
dnf5 -y copr enable monkeygold/nautilus-open-any-terminal
dnf5 -y install nautilus-open-any-terminal
# extras
#dnf5 -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
ls /etc/yum.repos.d/ | grep rpmfusion #
dnf5 -y reinstall https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-42.noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-42.noarch.rpm
ls /etc/yum.repos.d/ | grep rpmfusion #
dnf5 -y install blender 
dnf5 -y install ardour8 
echo "==========================================="
#Looks like github isn't able to ship audacity-freeworld for some reason... so I'll have to do it manually
dnf5 -y install https://mirror.fcix.net/rpmfusion/free/fedora/releases/42/Everything/x86_64/os/Packages/a/audacity-freeworld-3.7.3-1.fc42.x86_64.rpm
#and refuses to install anything from rpmfusion free or nonfree
dnf5 -y install libheif-tools heif-pixbuf-loader https://ftp-stud.hs-esslingen.de/pub/Mirrors/rpmfusion.org/free/fedora/releases/42/Everything/x86_64/os/Packages/l/libheif-freeworld-1.19.7-1.fc42.x86_64.rpm
dnf5 -y remove totem
dnf5 -y install totem-video-thumbnailer clapper mpv decibels
dnf5 -y install gnome-tweaks dconf
dnf5 -y install tealdeer 


# remove annoying gnome things
dnf5 -y remove \
            gnome-classic-session \
            gnome-tour \
            gnome-extensions-app \
            gnome-system-monitor \
            gnome-initial-setup \
            gnome-shell-extension-background-logo \
            gnome-shell-extension-apps-menu \
            firefox && \
            
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

# Brave Browser (Could I use it with flatpak? Yes. Am I going to? No.)
dnf5 -y install dnf-plugins-core
dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
dnf5 -y install brave-browser

echo -e "\e[31mDEBUG:\e[0m"
ls /opt
mv /opt/* /usr/share/factory/var/opt/
echo -e "\e[31mDEBUG:\e[0m"
ls /usr/share/factory/var/opt
#Testing in a VM shows that crossover and brave are installed to /usr/share/factory/var/opt however, -
# they aren't copied over to /opt [!] I'm missing systemd tmpfiles!
tee /etc/tmpfiles.d/systemd-tmpfiles-setup.service << 'EOF'
C+    /var/opt        -    -    -    -
EOF
#Hopefully on startup this will just overwrite existing copies

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

#Install custom kora-icon-theme
dnf5 -y install https://github.com/phantomcortex/kora/releases/download/1.6.5.12/kora-icon-theme-1.6.5.12-1.fc42.noarch.rpm

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

