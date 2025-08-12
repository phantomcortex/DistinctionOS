#!/bin/bash
#
EXTENSIONS_DIR="/usr/share/gnome-shell/extensions"
TMP="/tmp/gnome-shell"
mkdir -p $TMP

#pip-on-top
git clone "https://github.com/Rafostar/gnome-shell-extension-pip-on-top.git" "$EXTENSIONS_DIR/pip-on-top@rafostar.github.com"
glib-compile-schemas "$EXTENSIONS_DIR/pip-on-top@rafostar.github.com/schemas"

echo -e "\033[31mGNOME SHELL EXTENSIONS\033[0m"
# burn-my-windows
curl -L https://github.com/Schneegans/Burn-My-Windows/releases/download/v46/burn-my-windows@schneegans.github.com.zip -o $TMP/burn-my-windows@schneegans.github.com.zip
unzip -o $TMP/burn-my-windows@schneegans.github.com.zip -d $EXTENSIONS_DIR/burn-my-windows@schneegans.github.com

# clipboard-indicator
git clone https://github.com/Tudmotu/gnome-shell-extension-clipboard-indicator.git "$EXTENSIONS_DIR/clipboard-indicator@tudmotu.com"

#date-menu-formatter
git clone https://github.com/marcinjakubowski/date-menu-formatter.git "$EXTENSIONS_DIR/date-menu-formatter@marcinjakubowski.github.com"

# dash-to-dock 
git clone https://github.com/micheleg/dash-to-dock.git "$EXTENSIONS_DIR/dash-to-dock@micxgx.gmail.com"

# 'User Avatar in Quick Settings'
git clone https://github.com/d-go/quick-settings-avatar.git "$EXTENSIONS_DIR/quick-settings-avatar@d-go"
# 'Gnome 4x UI Improvments'
curl -L https://github.com/axxapy/gnome-ui-tune/releases/download/v1.10.2/gnome-ui-tune@itstime.tech.shell-extension.zip -o $TMP/gnome-ui-tune@itstime.tech.shell-extension.zip
unzip $TMP/gnome-ui-tune@itstime.tech.shell-extension.zip -d "$EXTENSIONS_DIR/gnome-ui-tune@itstime.tech"

#Tophat - gnome top panel resource monitor
curl -L https://github.com/fflewddur/tophat/releases/download/v22/tophat@fflewddur.github.io.v22.shell-extension.zip -o $TMP/tophat@fflewddur.github.io.v22.shell-extension.zip
unzip $TMP/tophat@fflewddur.github.io.v22.shell-extension.zip -d "$EXTENSIONS_DIR/tophat@fflewddur.github.io"

if [[ -d /usr/share/gnome-shell/extensions/hotedge@jonathan.jdoda.ca ]]; then
  rm -rf /usr/share/gnome-shell/extensions/hotedge@jonathan.jdoda.ca
fi

dnf5 -y install wget1 
mkdir -p /tmp/tilingshell 

#Install custom kora-icon-theme
dnf5 -y install https://github.com/phantomcortex/kora/releases/download/1.6.5.12/kora-icon-theme-1.6.5.12-1.fc42.noarch.rpm
echo -e "\033[31mKORA CUSTOM\033[0m"

# Function to verify directory contents
verify_directory_contents() {
    local directory="$1"
    shift
    local patterns=("$@")
    local found_count=0
    
    if [[ ! -d "$directory" ]]; then
        echo -e "${RED}Directory does not exist: $directory${NC}"
        return 1
    fi
    
    echo "Examining: $directory"
    for pattern in "${patterns[@]}"; do
        local matches
        matches=$(find "$directory" -maxdepth 1 -name "*${pattern}*" -type d 2>/dev/null)
        if [[ -n "$matches" ]]; then
            echo -e "  ${GREEN}✓${NC} Pattern '$pattern' matched:"
            echo "$matches" | sed 's/^/    /'
            ((found_count++))
        else
            echo -e "  ${RED}✗${NC} Pattern '$pattern' not found"
        fi
    done
    
    echo "  Summary: $found_count/${#patterns[@]} patterns found"
    return 0
}

# Usage demonstration
verify_directory_contents "/usr/share/themes" "Orchis"
verify_directory_contents "/usr/share/icons" "capitaine" "Deepin"
verify_directory_contents "/usr/share/backgrounds" "skyrim"
verify_directory_contents "/usr/share/gnome-shell" "tophat" "gnome-ui-tune" "burn-my-windows"

# verify
dnf5 -y install akmod
echo -e "\033[31mVERIFY GNOME EXTENSIONS\033[0m"
ls /usr/share/gnome-shell/extensions/
echo "......................."
ls /usr/share/gnome-shell/extensions/ |grep -E 'tophat|gnome-ui-tune|burn-my-windows|tophat'

echo -e "\033[31mCOMPILE GLIB SCHEMAS033[0m"
glib-compile-schemas /usr/share/glib-2.0/schemas/
gtk-update-icon-cache /usr/share/icons/kora 
update-mime-database /usr/share/mime
# cleanup

rm -rf /tmp/gnome-shell

echo -e "\033[31m=======================================================================================================================================================================================================================================================================================================================================================================================\033[0m"
