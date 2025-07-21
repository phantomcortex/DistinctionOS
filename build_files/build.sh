#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
#dnf5 install -y steam steam-devices 
# pre-installed on bluefin

#ublue-os staging
dnf5 -y copr enable ublue-os/staging

#ublue-os packages
dnf5 -y copr enable ublue-os/packages

#bazzite things ~ not sure what needs what
dnf5 -y copr enable bazzite-org/bazzite
dnf5 -y copr enable bazzite-org/bazzite-multilib
dnf5 -y copr enable bazzite-org/rom-properties 
dnf5 -y install rom-properties rom-properties-gtk3

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

# maybe install Crossover?
mkdir -p /var/opt/crossover
mkdir -p /opt/crossover
ln -s /opt/crossover /var/opt/crossover
dnf -y install http://crossover.codeweavers.com/redirect/crossover.rpm
# Crossover Requires a license file so It needs to be writable
# The alternative is to run it in a container

# Brave Browser (Could I use it with flatpak? Yes. Am I going to? No.)
dnf5 -y install dnf-plugins-core
dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
dnf5 -y install brave-browser

# internal copr repos
dnf5 -y copr enable ilyaz/LACT
dnf5 -y install lact
dnf5 -y copr enable fernando-debian/dysk
dnf5 -y install dysk
dnf5 -y copr enable atim/nushell
dnf5 -y install nushell
#==========================
# internal package non-sense
dnf5 install -y zoxide \
            gnome-randr-rust \
            gnome-shell-extension-appindicator \
            gnome-shell-extension-user-theme \
            gnome-shell-extension-just-perfection \
            gnome-shell-extension-blur-my-shell \
            gnome-shell-extension-caffeine \
            gnome-shell-extension-restart-to \
            gnome-shell-extension-burn-my-windows 
            
    # various things
    dnf5 -y install \
        nvim \
        zstd \
        zenity \
        rust \
        cargo \
        zsh \
        zsh-autosuggestions \
        zsh-syntax-highlighting \
        blackbox-terminal
        
dnf5 -y copr enable monkeygold/nautilus-open-any-terminal
dnf5 -y install nautilus-open-any-terminal
# extras
dnf5 -y install blender \
            ardour \
            audacity-freeworld 

# remove annoying gnome things
dnf5 -y remove \
            gnome-classic-session \
            gnome-tour \
            gnome-extensions-app \
            gnome-system-monitor \
            gnome-initial-setup \
            gnome-shell-extension-background-logo \
            gnome-shell-extension-apps-menu && \
# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

