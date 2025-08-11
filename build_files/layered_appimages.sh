#!/usr/bin/bash
set -euo pipefail

# is it wise or should i really be layering appimages on the OS?
# Probably not. maybe this 'fixation' will pass and I'll use those appimages \
# like I'm supposed to 


mkdir -p /var/opt/cemu/
curl -L https://github.com/cemu-project/Cemu/releases/download/v2.6/Cemu-2.6-x86_64.AppImage -o /var/opt/cemu/cemu-2.6.AppImage

mkdir -p /var/opt/yuzu/
curl -L https://github.com/phantomcortex/yuzu/releases/download/r_limbo_1/Yuzu-EA-4176.AppImage -o /var/opt/yuzu/yuzu-4176.AppImage 

tee /usr/share/applications/yuzu.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Yuzu 
GenericName=Switch Emulator
Exec=env DESKTOPINTEGRATION=1 /opt/yuzu/yuzu-4176.AppImage
Icon=/usr/share/icons/kora/apps/scalable/yuzu.svg
Categories=Game;Emulator;Qt;
MimeType=application/x-nx-nro;application/x-nx-nso;application/x-nx-nsp;application/x-nx-xcii
Keywords=Nintendo;Switch;
StartupWMClass=yuzu
x-AppImage-Integrate=false
x-AppImage-Version=9f20b0
EOF

tee /usr/share/applications/cemu.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Name=Cemu 
GenericName=Wii U Emulator
Terminal=false
Exec=env DESKTOPINTEGRATION=1 /opt/cemu/cemu-2.6.AppImage 
TryExec=/opt/cemu/cemu-2.6.AppImage
Icon=/usr/share/icons/kora/apps/scalable/cemu.svg
Categories=Game;Emulator;Qt;
Keywords=Nintendo;
MimeType=application/x-wii-u-rom;
x-AppImage-Version=a6fb0a4
EOF

