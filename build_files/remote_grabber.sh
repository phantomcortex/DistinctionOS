#
EXTENSIONS_DIR="/usr/share/gnome-shell/extensions"
TMP="/tmp/gnome-shell"
#pip-on-top
git clone "https://github.com/Rafostar/gnome-shell-extension-pip-on-top.git" "$EXTENSION_DIR/pip-on-top@rafostar.github.com"
glib-compile-schemas "$EXTENSION_DIR/pip-on-top@rafostar.github.com/schemas"
mkdir -p $TMP

# burn-my-windows
curl -L https://github.com/Schneegans/Burn-My-Windows/releases/download/v46/burn-my-windows@schneegans.github.com.zip -o $TMP
unzip -o $TMP/burn-my-windows@schneegans.github.com.zip -d $EXTENSION_DIR/burn-my-windows@schneegans.github.com
# clipboard-indicator
git clone https://github.com/Tudmotu/gnome-shell-extension-clipboard-indicator.git "$EXTENSIONS_DIR/clipboard-indicator@tudmotu.com"

#date-menu-formatter
git clone https://github.com/marcinjakubowski/date-menu-formatter.git "$EXTENSIONS_DIR/date-menu-formatter@tudmotu.com"


curl -L https://github.com/axxapy/gnome-ui-tune/releases/download/v1.10.2/gnome-ui-tune@itstime.tech.shell-extension.zip -o $TMP
unzip gnome-ui-tune@itstime.tech.shell-extension.zip -d "$EXTENSIONS_DIR/gnome-ui-tune@itstime.tech"

#Tophat - gnome top panel resource monitor
curl -L https://github.com/fflewddur/tophat/releases/download/v22/tophat@fflewddur.github.io.v22.shell-extension.zip -o $TMP 
unzip tophat@fflewddur.github.io.v22.shell-extension.zip -d "$EXTENSIONS_DIR/tophat@fflewddur.github.io"

# cleanup
rm -rf /tmp/gnome-shell



echo "======================================================================================================================================================================================================================================================================================================================================================================================="
