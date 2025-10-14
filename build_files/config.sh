#!/usr/bin/bash
set -euo pipefail

# script for things that don't really have a specific place
log() {
  echo "=== $* ==="
}


# Change the default shell to zsh
if [ -e /etc/default/useradd ];then
 sed -i 's|SHELL=/bin/bash|SHELL=/usr/bin/zsh|' /etc/default/useradd
fi 
usermod -s /usr/bin/zsh root
#

# enable distictionos-firstrun
#systemctl enable distinction-firstrun.service

# Enable TPM monitoring services
echo "Enabling TPM monitor services..."
#systemctl enable distinction-tpm-monitor.timer
#systemctl enable distinction-tpm-monitor.service

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


gtk-update-icon-cache -f /usr/share/icons/kora
#few updates ()
update-desktop-database
glib-compile-schemas /usr/share/glib-2.0
update-mime-database -V /usr/share/mime


# remove pesky askpass 
if [ -e /etc/profile.d/askpass.sh ]; then
  rm -f /etc/profile.d/askpass.sh 
  [ -e /usr/libexec/openssh/gnome-ssh-askpass ] && rm -f /usr/libexec/openssh/gnome-ssh-askpass 
fi 

# rm other bazzite things
 [ -e /etc/profile.d/bazzite-neofetch.sh ] && rm -f /etc/profile.d/bazzite-neofetch.sh
 [ -e /usr/share/applications/gnome-ssh-askpass.desktop ] && rm -f /usr/share/applications/gnome-ssh-askpass.desktop

