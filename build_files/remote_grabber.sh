#!/bin/bash
#
EXTENSIONS_DIR="/usr/share/gnome-shell/extensions"
TMP="/tmp/gnome-shell"
#pip-on-top
git clone "https://github.com/Rafostar/gnome-shell-extension-pip-on-top.git" "$EXTENSION_DIR/pip-on-top@rafostar.github.com"
glib-compile-schemas "$EXTENSION_DIR/pip-on-top@rafostar.github.com/schemas"
mkdir -p $TMP
echo -e "\033[31mGNOME SHELL EXTENSIONS\033[0m" && \
# burn-my-windows
curl -L https://github.com/Schneegans/Burn-My-Windows/releases/download/v46/burn-my-windows@schneegans.github.com.zip -o $TMP
unzip -o $TMP/burn-my-windows@schneegans.github.com.zip -d $EXTENSION_DIR/burn-my-windows@schneegans.github.com
# clipboard-indicator
git clone https://github.com/Tudmotu/gnome-shell-extension-clipboard-indicator.git "$EXTENSIONS_DIR/clipboard-indicator@tudmotu.com"

#date-menu-formatter
git clone https://github.com/marcinjakubowski/date-menu-formatter.git "$EXTENSIONS_DIR/date-menu-formatter@tudmotu.com"


curl -L https://github.com/axxapy/gnome-ui-tune/releases/download/v1.10.2/gnome-ui-tune@itstime.tech.shell-extension.zip -o $TMP/gnome-ui-tune@itstime.tech.shell-extension.zip
unzip $TMP/gnome-ui-tune@itstime.tech.shell-extension.zip -d "$EXTENSIONS_DIR/gnome-ui-tune@itstime.tech"

#Tophat - gnome top panel resource monitor
curl -L https://github.com/fflewddur/tophat/releases/download/v22/tophat@fflewddur.github.io.v22.shell-extension.zip -o $TMP/tophat@fflewddur.github.io.v22.shell-extension.zip
unzip $TMP/tophat@fflewddur.github.io.v22.shell-extension.zip -d "$EXTENSIONS_DIR/tophat@fflewddur.github.io"

dnf5 -y install wget1 
mkdir -p /tmp/tilingshell 

#Install custom kora-icon-theme
dnf5 -y install https://github.com/phantomcortex/kora/releases/download/1.6.5.12/kora-icon-theme-1.6.5.12-1.fc42.noarch.rpm
echo -e "\033[31mKORA CUSTOM\033[0m" && \

curl -s https://api.github.com/repos/domferr/tilingshell/releases/latest | \
            jq -r '.assets | sort_by(.created_at) | .[] | select (.name|test("^tilingshell@.*zip$")) | .browser_download_url' | \
            wget -qi - -O /tmp/tilingshell/tilingshell@ferrarodomenico.com.zip && \
        unzip /tmp/tilingshell/tilingshell@ferrarodomenico.com.zip -d /usr/share/gnome-shell/extensions/tilingshell@ferrarodomenico.com && \
        curl -Lo /usr/share/thumbnailers/exe-thumbnailer.thumbnailer https://raw.githubusercontent.com/jlu5/icoextract/master/exe-thumbnailer.thumbnailer && \
        systemctl enable dconf-update.service \

# verify
dnf5 -y install akmod
echo -e "\033[31mVERIFY GNOME EXTENSIONS\033[0m"
ls /usr/share/gnome-shell/extensions/
echo "......................."
ls /usr/share/gnome-shell/extensions/ |grep -E 'tophat|gnome-ui-tune|burn-my-windows|tophat'

echo -e "\033[31mVERIFY THEMES\033[0m"
ls /usr/share/themes/ |grep -e 'Orchis'
echo -e "\033[31mVERIFY ICONS\033[0m"
ls /usr/share/icons/ |grep -E 'capitaine|Deppin'
echo -e "\033[31mVERIFY BACKGROUNDS\033[0m"
ls /usr/share/backgrounds |grep -e 'skyrim'

# cleanup
rm -rf /tmp/gnome-shell
rm -rf /tophat*



echo -e "\033[31m=======================================================================================================================================================================================================================================================================================================================================================================================\033[0m"
