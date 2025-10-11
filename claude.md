# Claude Context: DistinctionOS

## Project Overview

**DistinctionOS** is a custom immutable Linux image built upon the Bazzite foundation, leveraging Universal Blue's infrastructure and tooling. This repository represents a personalised gaming and development environment optimised for a fully-featured experience.

### Key Characteristics
- **Base System**: Bazzite (gaming-focused Fedora Atomic variant)
- **Build System**: Built from Universal Blue's github Image template and uses github-actions to build & push to ghcr
- **Target Audience**: Mainly Personal use, with gaming and development focus
- **Deployment**: OCI container images via GitHub Container Registry
- **Philosophy**: "Swiss Army Knife" approach - versatile powerhouse over minimalism

## Repository Structure

```
DistinctionOS/
├── system_files/               # Static files copied into the image
│   ├── usr/
│   │   ├── bin/               # Custom executables (firstrun, tpm-monitor, advmv, advcp)
│   │   ├── lib/systemd/       # SystemD services and timers
│   │   └── share/DistinctionOS/just/  # Just recipes
│   └── etc/
│       └── sudoers.d/         # Sudo configuration
├── build_files/                # Build-time scripts
│   ├── build_new.sh           # Main package installer
│   ├── fix_opt.sh             # Fixes /opt packages at runtime
│   ├── kernel_modules.sh      # Compiles xpadneo kernel module
│   ├── config.sh      			# Intended for System Configuration or miscellaneous things that don't have a proper place
│   ├── layered_appimages.sh   # Layers AppImages (user aware of unconventional approach)
│   ├── remote_grabber.sh      # GNOME Shell extension management
│   └── wine_installer.sh      # Installs Kron4ek Wine builds
├── repo_files/                # Resources for just recipes
├── disk_config/               # Configuration for build-disk.yml
├── Containerfile              # Custom container build instructions
└── .github/workflows/         # GitHub Actions (build.yml & build-disk.yml)
```

## Technical Architecture

### Build Process
1. **Base Layer**: Starts with Bazzite's gaming-optimized foundation
2. **Customization Layer**: Applies personal configurations and packages
3. **Distribution**: Publishes to GHCR for atomic updates

### Key Technologies
- **Fedora Atomic**: Immutable base system with atomic updates
- **rpm-ostree**: Package layer management
- **Podman/Docker**: Container runtime and build system
- **GitHub Actions**: Automated CI/CD pipeline
- **OCI Images**: Distribution format

## Customization Philosophy

### Design Principles
- **Fully Featured OS**: Focus on versatility,  
- **Development-Friendly**: Include essential development tools
- **Reproducible**: Declarative configuration for consistent builds
- **Personal**: Tailored to individual workflow preferences
- ****

### Package Management Strategy
- **System Packages**: Added during build process for base image inclusion
- **User Packages**: Installed via RPM packages, flatpak, distrobox containers, or homebrew packages
- **Development Tools**: Integrated into base image for immediate availability

## Configuration Areas

### System Customizations
- **Desktop Environment**: GNOME with personal extensions and themes
- **Shell Configuration**: Zsh with Oh My Zsh and Powerlevel10k installed via just script from a seperate repo
- **Development Environment**: Pre-configured toolchains and editors
- **Gaming Optimizations**: Inherited from Bazzite base

### User Experience Enhancements
- **Dotfiles Integration**: Automated personal configuration deployment
- **Theme Consistency**: Coordinated visual styling across applications
- **Workflow Optimization**: Shortcuts and automation for common tasks

## Development Workflow
- **w**:

### CI/CD Pipeline
- **Trigger**: Push to main branch or pull requests
- **Build**: Multi-architecture container builds
- **Test**: Validation of image integrity and functionality
- **Deploy**: Automatic publishing to GitHub Container Registry

## Key Files and Their Purposes

### `build_files/build.sh`
The main package installer of the configuration, defining:
- Package installations and removals 
- RPM repos configuration 
- asc key additions

### `build_files/fix_opt.sh`
For packages installed to /opt:
- Fixes packages installed to opt vanishing at run-time

### `build_files/kernel_modules.sh`
For one kernel compilied from source:
- Compiles and adds xpadneo kernel module
- Other dkms modules can added to build process later

### `build_files/layered_appimages.sh`
As the name implies adds directly to the OS image:
- user states that he is aware that you probably shouldn't layer appimages onto OCI images but is currently adament that these appimages stay in place

### `build_files/install_zfs.sh`
complete build process for the zfs kernel module:
- currently inactive

### `build_files/remote_grabber.sh`
This script adds gnome-shell extenstions to OS image:
- Manages the addition, removal, and compiles the gschemas for certain extensions

### `build_files/wine_installer.sh`
This Installs custom wine-builds from Kron4ek:
- A full script dedicated to grabbing the most recent wine version from Kron4ek/Wine-builds release page and installing it
- will add the release with this string: 'staging-tkg-ntsync-amd64-wow64'

### `Containerfile`
Advanced container build instructions for:
- Base Image
- Multi-stage builds
- Custom optimization steps

### `system_files/` Directory
Contains custom files added at build time:
- Probably akin to Bluebuild's 'overlay'

## Maintenance Considerations

### Update Strategy
- **Base Image Updates**: Automatic rebuilds when Bazzite releases updates
- **Security Updates**: Regular rebuilds for security patches
- **Feature Updates**: Manual integration of new customizations

### Testing Approach
- **Build Verification**: Ensure successful image creation
- **Functionality Testing**: Validate key features and applications
- **Integration Testing**: Verify compatibility with upstream changes

## Common Modification Areas

### Adding New Packages
- Edit `build.sh` where it declares packages and corresponding repositories
- Edit `config.sh` for enabling system services

## Current Implementation Status

### ✅ Completed Features

#### Default Shell Configuration
- **ZSH as System Default**: Configured for all new users via `/etc/default/useradd`
- **First-Run Automation**: SystemD service (`distinction-firstrun.service`) that:
  - Triggers on first boot after rebase
  - Runs `ujust distinction-install` automatically
  - Creates log at `/var/DistinctionOS/DistinctionOS_firstrun.log`
  - Only runs once (checks for log file existence)

#### TPM Unlock System
- **Interactive Setup**: `ujust distinction-tpm-unlock-setup` with preset PCR configurations:
  - Maximum Security (PCR 0,1,4,5,7,8,9)
  - Balanced (PCR 0,4,7,9)
  - Convenience (PCR 7)
  - Custom selection
- **Proactive Monitoring**: `distinction-tpm-monitor` service that:
  - Detects kernel, bootloader, firmware changes
  - Warns BEFORE reboot when updates will break TPM
  - Monitors rpm-ostree deployments
  - Runs every 30 minutes via SystemD timer
- **Recovery Tools**:
  - `ujust distinction-tpm-reenrol`: Quick re-enrollment
  - `ujust distinction-tpm-verify`: Status check
  - `ujust distinction-tpm-reset`: Complete reset with auth
  - `ujust distinction-tpm-logs`: View monitor logs

#### Just Recipe System
- **Main Recipe**: `distinction.just` with modular imports
- **Installation Recipes**:
  - Flatpak installation from GitHub-hosted list
  - Homebrew package management
  - Oh-my-zsh with Powerlevel10k theme
  - NvChad configuration for Neovim
  - Nautilus scripts integration
  - **TPM Management**: Separate recipe file for TPM operations

#### Security Configuration
  - **Passwordless Sudo**: Configured for wheel group (user aware of security implications)
  - Located at `/etc/sudoers.d/99-distinction-wheel-nopasswd`

### 🚧 Known Issues
- NvChad installation for root may need verification after first run
- Some just recipes need error handling improvements
- TPM re-enrollment requires manual password entry (by design for security)
- In testing System sometimes hangs at plymouth screen for a short while after system receives shutdown signal 
## Maintenance Procedures

### After System Updates
```bash
rpm-ostree upgrade
# Monitor will detect and notify about TPM changes
ujust distinction-tpm-reenrol  # If notified
systemctl reboot
```

### TPM Management
```bash
ujust distinction-tpm-check     # Check if re-enrollment needed
ujust distinction-tpm-verify    # Verify current status
ujust distinction-tpm-logs      # View recent activity
```

### Theme and Appearance
1. Add theme files to `system_files/usr/share/themes/`
2. Configure default selections in system settings
3. Test across different applications

### User Data Management
- **Persistent Storage**: User data remains intact across image updates
- **Configuration Persistence**: Personal settings preserved in `/var/home/`
- **Application Data**: Flatpak and container app data maintained

### Debug Approaches
- **Build Logs**: Examine GitHub Actions output for build-time issues
- **System Logs**: Use `journalctl` for runtime problem diagnosis
- **Layer Inspection**: Analyze image layers with `podman history`

## Future Roadmap

### Eventual Goals
- [ ] Standalone installable ISO image file (that actually works)
- [ ] Rechunker support
- [ ] Ship CachyOS-lto kernel by default
- [ ] Steam icon/.desktop manager service
- [x] User uses ZSH by default ✅ (untested)
- [x] Auto-install oh-my-zsh, powerlevel10k on fresh installation ✅ (untested)
- [x] TPM auto-recovery mechanism ✅ (untested)

---

## Notes for AI Assistants
Note: This project does not use BlueBuild. Some legacy scripts may not follow style conventions fully. 
- Values Posh British delivery of refined communication akin to a butler serving Champagne to the lord of the castle
- 
### Code Style Preferences
- **Shell Scripts**: Follow Google Shell Style Guide conventions
- **YAML Files**: 2-space indentation, explicit string quoting where beneficial
- **Documentation**: Clear, concise explanations with practical examples
- **Context Generation**: At the end of a session, user will ask for an updated claude.md context file

### Project Philosophy
- Fully-featured experience prioritized over minimalism
- Native RPM packages preferred over Flatpaks where sensible
- Elegant solutions balancing functionality with maintainability
- Proactive problem prevention over reactive fixes
- This is a personal project focused on creating an optimal Linux environment for both gaming and development work. The user values clean, maintainable configurations and appreciates detailed explanations of technical concepts. 

### User Technical Level
- Intermediate Linux system administration skills
- Comfortable with containers, package management, system configuration
- Appreciates detailed technical explanations with practical application
