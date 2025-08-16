#!/usr/bin/bash
set -euo pipefail

# CREDIT: https://github.com/ExistingPerson08/amyos-gnome/blob/main/build_files/install-apps.sh
# A good example on what to improve upon

trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG

log() {
  echo "=== $* ==="
}

#
rpmkeys --import https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg 
printf "[gitlab.com_paulcarroty_vscodium_repo]\nname=download.vscodium.com\nbaseurl=https://download.vscodium.com/rpms/\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg\nmetadata_expire=1h\n" | sudo tee -a /etc/yum.repos.d/vscodium.repo

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
    clang"

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
  ["com_paulcarroty_vscodium_repo"]="codium"
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

#remove pesky bazzite things (mainly askpass)
remove_packages=(waydroid \
  sunshine \
  gnome-shell-extension-compiz-windows-effect \
  openssh-askpass \
  cockpit-bridge)

for pkg in "${remove_packages[@]}"; do
  if rpm -q "$pkg" &>/dev/null; then
    echo "Removing $pkg..."
    dnf5 -y remove "$pkg"
  fi 
done 

# remove bazzite things intended for waydroid
find /usr/share/applications -iname '*waydroid*' -exec rm -rf {} + 

# custom icon for Cider because it doesn't seem to use it regardless of what icon theme is used
sed -i 's@Icon=Cider@Icon=/usr/share/icons/kora/apps/scalable/cider.svg@g' /usr/share/applications/Cider.desktop

# modify winetricks due to winetricks telling me 'You are using 64 bit verb' or 'You seem to be using wow64 mode!' five-thousand times... 
sed -i 's@Exec=winetricks --gui@Exec=/usr/bin/env WINEDEBUG-all winetricks -q --gui@g' /usr/share/applications/winetricks.desktop

if [[ ! -d /var/opt ]]; then
  echo -e "$RED /var/opt does not exist for some reason...\n $CYAN CREATING... $NC"
  mkdir -p /var/opt
fi #sanity check

dnf5 -y install http://crossover.codeweavers.com/redirect/crossover.rpm # Crossover net install::I hope they don't change their website so I can't grab it


log "Enabling system services"

log "Adding DistinctionOS just recipes"
echo "import \"/usr/share/DistinctionOS/just/distinction.just\"" >>/usr/share/ublue-os/justfile

log "Hide incompatible Bazzite just recipes"
for recipe in "install-coolercontrol" "install-openrgb"; do
  if ! grep -l "^$recipe:" /usr/share/ublue-os/just/*.just | grep -q .; then
    echo "Error: Recipe $recipe not found in any just file"
    exit 1
  fi
  sed -i "s/^$recipe:/_$recipe:/" /usr/share/ublue-os/just/*.just
done

log "Build process completed"

#last minute grabs
mkdir -p /etc/zsh/
curl -L https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/shared/etc/zsh/zlogin -o /etc/zsh/zlogin
curl -L https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/shared/etc/zsh/zlogout -o /etc/zsh/zlogout
curl -L https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/shared/etc/zsh/zprofile -o /etc/zsh/zprofile
curl -L https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/shared/etc/zsh/zshenv -o /etc/zsh/zshenv
curl -L https://raw.githubusercontent.com/ublue-os/bluefin/main/system_files/shared/etc/zsh/zshrc -o /etc/zsh/zshrc
#
dnf5 -y install https://github.com/phantomcortex/kora/releases/download/1.6.5.12/kora-icon-theme-1.6.5.12-1.fc42.noarch.rpm
