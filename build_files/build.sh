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
mkdir -p /opt/crossover #Might be a requirement for crossover
ln -s /opt/crossover /var/opt/crossover
dnf -y install http://crossover.codeweavers.com/redirect/crossover.rpm
# Crossover Requires a license file so It needs to be writable
# The alternative is to run it in a container

# Brave Browser (Could I use it with flatpak? Yes. Am I going to? No.)
dnf5 -y install dnf-plugins-core
dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
dnf5 -y install brave-browser

ls /opt
ls /opt/crossover
ls /var/opt
ls /var/opt/crossover
# internal copr repos
dnf5 -y copr enable ilyaz/LACT
dnf5 -y install lact
dnf5 -y copr enable fernando-debian/dysk
dnf5 -y install dysk
dnf5 -y copr enable atim/nushell
dnf5 -y install nushell

#remove old kernel?
dnf5 -y remove kernel kernel-devel-matched
dnf5 -y copr enable bieszczaders/kernel-cachyos
#dnf5 -y copr enable bieszczaders/kernel-cachyos-lto
dnf5 -y install kernel-cachyos kernel-cachyos-devel-matched
#dnf5 -y install kernel-cachyos-lto kernel-cachyos-lto-devel-matched
# Note: bluefin ships with a slightly older kernel 
# but shipping the cachyos kernel will be delayed until I can confirm secure-boot works with and without the custom kernel
dnf5 -y copr enable atim/xpadneo
dnf5 -y install xpadneo
# Note: I've previously used sentry's xpadneo kmod but it's not signed so secure boot won't work
# it's unclear if atim's xpadneo is signed, but I doubt it severely.
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
dnf5 -y install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

dnf5 -y install blender 
dnf5 -y install ardour8 
dnf5 -y install audacity-freeworld 
dnf5 -y install libheif-tools heif-pixbuf-loader libheif-freeworld
dnf5 -y remove totem
dnf5 -y install totem-video-thumbnailer clapper mpv decibels
dnf5 -y install gnome-tweaks dconf


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
# since i use brave and firefox just collects dust we're just gonna get rid of it
# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

