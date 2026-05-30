# ============================================================================
# DistinctionOS — Developer Experience & Modding Recipes
# ============================================================================

# Install Docker CE and stage it for the next boot
[group('DistinctionOS Development')]
distinction-setup-docker:
    #!/usr/bin/env bash
    set -euo pipefail

    if command -v docker &>/dev/null; then
        echo "Docker is already installed ($(docker --version))"
        exit 0
    fi

    echo "Adding Docker CE repository..."
    sudo tee /etc/yum.repos.d/docker-ce.repo > /dev/null <<'REPO'
[docker-ce-stable]
name=Docker CE Stable - Fedora $releasever
baseurl=https://download.docker.com/linux/fedora/$releasever/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
skip_if_unavailable=1
REPO

    echo "Layering Docker CE packages via rpm-ostree (reboot required)..."
    sudo rpm-ostree install \
        containerd.io \
        docker-ce \
        docker-ce-cli \
        docker-buildx-plugin \
        docker-compose-plugin

    echo ""
    echo "Docker CE staged. After rebooting, run:"
    echo "  sudo systemctl enable --now docker"
    echo "  sudo usermod -aG docker \$USER"
    echo "  newgrp docker"

# Install libvirt/KVM virtualisation stack
[group('DistinctionOS Development')]
distinction-setup-virt:
    #!/usr/bin/env bash
    set -euo pipefail

    if systemctl is-enabled --quiet libvirtd.service 2>/dev/null; then
        echo "libvirtd is already enabled."
        exit 0
    fi

    echo "Layering libvirt and QEMU packages via rpm-ostree (reboot required)..."
    sudo rpm-ostree install \
        libvirt \
        libvirt-nss \
        qemu-kvm \
        qemu-img \
        virt-install

    echo "Installing virt-manager via Flatpak..."
    flatpak install --system -y flathub org.virt_manager.virt-manager 2>/dev/null || \
        echo "virt-manager Flatpak install failed — install manually from Flathub"

    echo ""
    echo "Packages staged. After rebooting, run:"
    echo "  sudo systemctl enable --now libvirtd"
    echo "  sudo usermod -aG libvirt \$USER"

# Set up game modding tools and print a workflow reference
[group('DistinctionOS Modding')]
distinction-setup-modding:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Setting up game modding environment..."
    echo ""

    # Protontricks — run Windows modding tools inside a game's Proton prefix
    if ! flatpak info --system com.github.Matoking.protontricks &>/dev/null; then
        echo "Installing Protontricks..."
        flatpak install --system -y flathub com.github.Matoking.protontricks
        echo "Protontricks installed."
    else
        echo "Protontricks already installed."
    fi

    # .NET SDK — required by Synthesis patcher (Skyrim/FO4 FOMOD patcher framework)
    if ! command -v dotnet &>/dev/null; then
        echo ""
        echo "Installing .NET SDK via rpm-ostree (requires reboot)..."
        sudo rpm-ostree install dotnet-sdk-9.0
        echo "NOTE: Reboot to complete .NET SDK installation."
    else
        echo ".NET SDK already available ($(dotnet --version))"
    fi

    echo ""
    echo "========================================================"
    echo "  DistinctionOS Modding Tool Reference"
    echo "========================================================"
    echo ""
    echo "MORROWIND (native Linux)"
    echo "  Engine:         openmw"
    echo "  Editor:         openmw-cs"
    echo "  Utilities:      openmw-tools"
    echo ""
    echo "BETHESDA GAMES — Skyrim / Fallout 4 / Starfield"
    echo "  Most Windows tools run via Protontricks:"
    echo "    protontricks <SteamAppID> <verb>   (replaces Wine prefix)"
    echo ""
    echo "  xEdit / SSEEdit:     protontricks <AppID> wmp10 dotnet48"
    echo "  LOOT:                protontricks <AppID> d3dx9"
    echo "  BSA Browser:         protontricks <AppID> vcrun2019"
    echo "  Mod Organizer 2:     Run MO2.exe via Proton in Steam"
    echo "    Tip: Add MO2 as a non-Steam game and set Proton compatibility"
    echo ""
    echo "SYNTHESIS PATCHER (needs .NET SDK — run after reboot if just installed)"
    echo "  Download: https://github.com/Mutagen-Modding/Synthesis/releases"
    echo "  Run:      dotnet Synthesis.exe"
    echo ""
    echo "ARCHIVE SUPPORT"
    echo "  p7zip is pre-installed — extract .7z mod archives with:"
    echo "    7z x archive.7z"
    echo ""
    echo "TEXTURE / MESH WORK"
    echo "  GIMP, Krita, Blender — available via Flatpak"
    echo "  DDS thumbnails (BC7) are pre-patched in the image (glycin)"
    echo "========================================================"

# Look up a Steam AppID for use with Protontricks
[group('DistinctionOS Modding')]
distinction-modding-appid game="":
    #!/usr/bin/env bash
    GAME={{ game }}
    if [[ -z "$GAME" ]]; then
        echo "Usage: ujust distinction-modding-appid \"Game Name\""
        echo "Common AppIDs:"
        printf "  %-30s %s\n" "The Elder Scrolls V: Skyrim SE" "489830"
        printf "  %-30s %s\n" "The Elder Scrolls V: Skyrim"    "72850"
        printf "  %-30s %s\n" "Fallout 4"                       "377160"
        printf "  %-30s %s\n" "Fallout: New Vegas"              "22380"
        printf "  %-30s %s\n" "Starfield"                       "1716740"
        printf "  %-30s %s\n" "Oblivion Remastered"             "2623190"
        exit 0
    fi
    # Use Steam's search if steamcmd is available, otherwise direct to SteamDB
    echo "Searching SteamDB for: $GAME"
    xdg-open "https://www.steamdb.info/search/?a=app&q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$GAME'))")" 2>/dev/null || \
        echo "Open: https://www.steamdb.info/search/?a=app&q=${GAME// /+}"
