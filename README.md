# DistinctionOS

> A fully-featured [Bazzite](https://github.com/ublue-os/bazzite)-based gaming and development environment

[![Built on Bazzite](https://img.shields.io/badge/Built%20on-Bazzite-blue)](https://github.com/ublue-os/bazzite)
[![Fedora Atomic](https://img.shields.io/badge/Fedora-Atomic-51A2DA)](https://fedoraproject.org/)
[![License](https://img.shields.io/github/license/phantomcortex/distinctionos)](./LICENSE)

**DistinctionOS** embraces the philosophy of abundance. a curated experience built for creators, gamers, and tinkerers who want it all, out of the box.

---

## 🚀 Quick Start

Rebase your existing system to DistinctionOS:

```bash
# Using bootc (recommended)
sudo bootc switch ghcr.io/phantomcortex/distinctionos

# Using rpm-ostree
rpm-ostree rebase ostree-unverified-registry:docker://ghcr.io/phantomcortex/distinctionos:latest
```

After reboot, run the first-time setup:
```bash
ujust distinction-install
```

---

## ✨ What's Included

### 🎮 Gaming Enhancements
- **kernel-cachyos-lto** - Custom Kernel for the best gaming experience possible.

### 🎨 Creative Tools
- **Cider** - Premium Apple Music client ([requires license](https://cidercollective.itch.io/cider))
- **Audacity Freeworld** - Full codec support for audio editing
- **dcraw** - RAW image format support with thumbnail generation
- **ImageMagick DDS thumbnailer** - Texture file previews

### 🛠️ Development & Productivity
- Docker & Docker Compose
- Flatpak Builder
- FreeRDP (for remote Windows applications)
- Pandoc (universal document converter)

### 📦 Quality of Life
- **zoxide** - Smart directory navigation (`z` command)
- **dysk** - Modern disk usage analyzer
- **advcp/advmv** - Progress bars for copy/move operations
- Video thumbnail generation
- HEIC image format support

---

## 🔑 Key Features

| Feature | Description |
|---------|-------------|
| **Immutable Base** | Built on Fedora Atomic for reliability and easy rollback |
| **Automatic Updates** | Fresh images built every 5 days with latest packages |
| **TPM Auto-Unlock** | Optional LUKS unlock with TPM 2.0 (setup via `ujust distinction-tpm-unlock-setup`) |
| **ZSH by Default** | Oh My Zsh + Powerlevel10k configured automatically |
| **Just Recipes** | Simple commands for common tasks (`ujust` for menu) |

---

## 🎯 Philosophy

**DistinctionOS is for those who want:**
- A complete, ready-to-use system without manual configuration
- Gaming performance with development tools side-by-side
- Professional applications without hunting through repositories

If you prefer minimalism and building from scratch, this isn't your distribution—and that's perfectly fine.

---

## 📚 Documentation

- **[Developer Documentation](./docs/developer.md)** - Build process, architecture, contributing
- **[AI Assistant Context](./docs/claude.md)** - Complete project context for AI tools

---

## 🙏 Acknowledgements

Special Thanks:

- **[Fedora Project](https://fedoraproject.org)** - The foundation of it all
- **[Universal Blue](https://github.com/ublue-os)** - Bazzite, Bluefin, and the image template
- **[Bazzite](https://github.com/ublue-os/bazzite)** - The direct parent of this project
- **Community Examples**: [Amy OS](https://github.com/astrovm/amyos), [vst-name's Aurora DX](https://github.com/vst-name/ublue-aurora-dx), [m2OS](https://github.com/m2giles/m2os), [bOS](https://github.com/bsherman/bos), [Homer](https://github.com/bketelsen/homer/), [VeneOS](https://github.com/Venefilyn/veneos)


---

<div align="center">

**Built with ❤️ by [phantomcortex](https://github.com/phantomcortex)**

*For those who want it all*

</div>
