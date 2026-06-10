<div align="center">

# DistinctionOS

**A curated, immutable desktop for gamers and creators — built on Bazzite.**

[![Built on Bazzite](https://img.shields.io/badge/Built%20on-Bazzite-blue?style=flat-square)](https://github.com/ublue-os/bazzite)
[![Fedora Atomic](https://img.shields.io/badge/Fedora-Atomic-51A2DA?style=flat-square)](https://fedoraproject.org/)
[![License](https://img.shields.io/github/license/phantomcortex/distinctionos?style=flat-square)](./LICENSE)
[![Build](https://img.shields.io/github/actions/workflow/status/phantomcortex/distinctionos/build.yml?style=flat-square)](https://github.com/phantomcortex/distinctionos/actions)

</div>

---

DistinctionOS is an opinionated layer on top of [Bazzite](https://github.com/ublue-os/bazzite) — a Fedora Atomic gaming desktop. It ships original system tooling, GNOME Shell extensions, and a curated application set so you have a complete, ready-to-use system with nothing left to hunt down.

Images are built every 5 days, signed with Cosign, and pushed to GHCR.

## Installation

```bash
sudo bootc switch ghcr.io/phantomcortex/distinctionos:latest
```

After rebooting, run post-install setup:

```bash
ujust distinction-install
```

This installs Flatpaks, Homebrew packages, ZSH, and NvChad in a single command.

## Features

| Component | Description |
|-----------|-------------|
| **Glycin BC7 Patch** | DDS texture thumbnails for BC4/5/6H/BC7 formats not covered by upstream |
| **Steam Linker** | Systemd service unifying all Steam library locations under `~/Games/Steamlibrary/` |
| **XWM Player** | Transparent playback of Bethesda game audio formats (`.xwm`, `.fuz`) |
| **ZSH System-Wide** | Oh My Zsh + Powerlevel10k configured at the system level |
| **GNOME Extensions** | Pre-installed: Dash to Dock, Burn My Windows, TopHat, and more |
| **Brave Browser** | Ships as the default browser |
| **Cider** | Premium Apple Music client (license required) |
| **CrossOver** | Commercial Wine implementation for Windows applications |
| **Rechunker** | Efficient layer compression for faster, smaller OTA updates |
| **Cosign Signing** | Every image signed and verifiable with the included public key |

## What Makes It Different

### Glycin — BC7 DDS Patch

Stock Fedora `glycin-*` packages are replaced with [`phantomcortex/glycin`](https://github.com/phantomcortex/glycin) release RPMs (`v2.1.1-bc7fix1`). Adds BC4, BC5, BC6H, and BC7 DDS compression support to `glycin-image-rs`, enabling thumbnail generation in Nautilus for compressed game textures. Upstream glycin ships BC1/BC2/BC3 only. The release version sorts above Fedora's `1.fc44` for a clean upgrade.

### Steam Linker

A systemd user service that parses Steam's `libraryfolders.vdf` and maintains a symlink tree under `~/Games/Steamlibrary/` covering all detected library paths. State-tracked in JSON for restoration after deletion. Exclusion patterns filter Proton runtimes, GE-Proton, and SteamLinuxRuntime by default.

```bash
ujust steam-link-enable    # Run at login
ujust steam-link           # Run now
ujust steam-link-status    # Current state
```

See [docs/steam-linker.md](./docs/steam-linker.md).

### XWM Player

`/usr/bin/xwm-player` converts `.xwm` (xWMA) and `.fuz` (Bethesda voice container) to WAV on the fly via FFmpeg and opens the result in the configured audio player. MIME types are registered for transparent file-manager double-click. Flatpak-aware; defaults to `org.gnome.Decibels`. FUZ handling strips the lip-sync header before passing the embedded xWMA to FFmpeg.

See [docs/xwm-player.md](./docs/xwm-player.md).

## Post-Install Recipes

```bash
ujust distinction-install              # Full setup
ujust distinction-install-flatpaks     # Flatpaks only
ujust distinction-install-brews        # Homebrew packages only
ujust distinction-install-custom-shell # ZSH + dotfiles
ujust distinction-install-nvchad       # NvChad for user and root
ujust steam-link-enable                # Steam Linker at login
```

See [docs/ujust-recipes.md](./docs/ujust-recipes.md).

## Verification

```bash
cosign verify --key cosign.pub ghcr.io/phantomcortex/distinctionos:latest
```

## Documentation

| Document | Contents |
|----------|----------|
| [Developer Guide](./docs/developer.md) | Build architecture, script reference, contributing |
| [ujust Recipes](./docs/ujust-recipes.md) | All `ujust` commands and their purpose |
| [Steam Linker](./docs/steam-linker.md) | Game library symlink manager |
| [XWM Player](./docs/xwm-player.md) | Bethesda audio format player |

## Acknowledgements

- **[Universal Blue](https://github.com/ublue-os)** — Bazzite, Bluefin, and the image template
- **[Bazzite](https://github.com/ublue-os/bazzite)** — The direct upstream
- **[Fedora Project](https://fedoraproject.org)** — The foundation
- Community: [AmyOS](https://github.com/astrovm/amyos) · [Aurora DX](https://github.com/vst-name/ublue-aurora-dx) · [m2OS](https://github.com/m2giles/m2os) · [bOS](https://github.com/bsherman/bos) · [Homer](https://github.com/bketelsen/homer) · [VeneOS](https://github.com/Venefilyn/veneos)

---

<div align="center">Built by <a href="https://github.com/phantomcortex">phantomcortex</a></div>
