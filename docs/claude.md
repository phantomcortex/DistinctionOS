# Claude Context: DistinctionOS

## Project Overview

**DistinctionOS** is a custom immutable Linux image built upon the Bazzite foundation, leveraging Universal Blue's infrastructure and tooling. This repository represents a personalised gaming and development environment optimised for a fully-featured experience.

### Key Characteristics
- **Base System**: Bazzite (gaming-focused Fedora Atomic variant)
- **Build System**: Built from Universal Blue's GitHub image template using GitHub Actions to build & push to GHCR
- **Target Audience**: Primarily personal use, with gaming and development focus
- **Deployment**: OCI container images via GitHub Container Registry
- **Philosophy**: "Swiss Army Knife" approach - versatile powerhouse over minimalism
- **Code Quality**: Professional-grade with standardized logging, comprehensive error handling, and utility function library

## Repository Structure

```
DistinctionOS/
├── build_files/               # Build-time execution scripts (numerically ordered)
│   ├── 00-kernel.sh           # CachyOS LTO kernel installation - FIRST
│   ├── 01-kernel-modules.sh   # Initramfs regeneration - SECOND
│   ├── 02-build.sh            # Package management (RPM, repos, keys) - THIRD
│   ├── 03-fix-opt.sh          # /opt persistence configuration - FOURTH
│   ├── 04-config.sh           # System services and misc config - FIFTH
│   ├── 05-cache-install.sh    # Cache RPM install from OCI artifact - SIXTH
│   ├── 06-force-install.sh    # Force-install RPMs from OCI artifact - SEVENTH
│   ├── 07-remote-grabber.sh   # GNOME Shell extension management - EIGHTH
│   ├── 08-validate.sh         # Post-install environment validation - NINTH (FINAL)
│   ├── 95-utility-functions.sh # Shared utility functions library - SOURCED BY ALL
│   └── wine-installer.sh      # Custom Wine builds (INACTIVE - not in build sequence)
│
├── system_files/              # Static files overlaid onto the image at build time
│   ├── usr/
│   │   ├── bin/               # Custom executables (xwm-player, xiso, advmv, advcp, chsh, etc.)
│   │   ├── lib/systemd/user/  # User SystemD services (steam-linker)
│   │   ├── share/distinctionos/
│   │   │   ├── just/          # ujust recipe files
│   │   │   ├── lib/           # Shared housekeeper library
│   │   │   ├── steam-linker/  # Steam Linker script and config
│   │   │   └── xwm-player/    # XWM Player config and handlers
│   │   ├── share/fonts/       # Bundled Nerd Fonts (0xProto, CommitMono, FiraCode, etc.)
│   │   ├── share/icons/       # Cursor themes (capitaine, DeepinDark, DeepinWhite)
│   │   ├── share/themes/      # GTK theme (adw-gtk3-dark)
│   │   ├── share/applications/ # .desktop files
│   │   ├── share/mime/        # MIME type registrations
│   │   └── share/glib-2.0/schemas/ # GNOME schema overrides
│   └── etc/
│       ├── zsh/               # System-wide ZSH configuration
│       ├── sudoers.d/         # Passwordless sudo for wheel group
│       ├── yum.repos.d/       # Pre-installed repository files
│       ├── profile.d/         # Shell environment scripts
│       └── systemd/           # System-level systemd config overrides
│
├── repo_files/                # Resources for just recipes (hosted on GitHub)
│   ├── brews                  # Homebrew package list (for post-install)
│   ├── flatpaks               # Flatpak application list (for post-install)
│   └── rpm/                   # RPM-based resources
│
├── disk_config/               # Configuration for bootable disk creation
│   ├── disk.toml              # QCOW2/RAW VM disk configuration
│   └── iso.toml               # ISO installer configuration
│
├── docs/                      # Project documentation
│   ├── claude.md              # This file - AI assistant context
│   ├── developer.md           # Comprehensive developer documentation
│   ├── steam-linker.md        # Steam Linker housekeeper documentation
│   ├── xwm-player.md          # XWM Player documentation
│   └── ujust-recipes.md       # ujust recipe reference
│
├── Containerfile              # Custom container build instructions
├── Justfile                   # Local development tooling (build, test, lint)
├── cosign.pub                 # Image signing public key
└── .github/workflows/         # GitHub Actions (build.yml, build-mesa.yml, build-disk.yml)
```

## Housekeeper Architecture

The Housekeeper Architecture is an ecosystem of simple automation services for home directory management. All housekeepers share common infrastructure:

### Directory Convention
| Purpose | Location |
|---------|----------|
| System defaults | `/usr/share/distinctionos/<service>/` |
| Local overrides | `/usr/local/share/distinctionos/<service>/` |
| User overrides | `~/.config/distinctionos/` |
| Runtime state | `~/.local/share/distinctionos/<service>/` |
| Logs | `/var/log/distinctionos/` (500MiB limit with rotation) |

### Shared Library
`/usr/share/distinctionos/lib/housekeeper-common.sh` provides:
- Standardised logging with automatic rotation
- Configuration management with override hierarchy
- State persistence utilities
- Symlink management functions
- Locking to prevent concurrent execution

### Current Housekeepers
| Service | Purpose | Status |
|---------|---------|--------|
| Steam Linker | Unified game library symlinks | ✅ Complete |
| XWM Player | Bethesda audio format playback | ✅ Complete |

## Steam Linker

Automatically creates symlinks to `~/Games/Steamlibrary/` from all Steam library locations.

### Features
- Auto-discovers libraries via `libraryfolders.vdf`
- Tracks managed symlinks for restoration if accidentally deleted
- Removes broken symlinks automatically
- Duplicate detection with warnings

### Quick Commands
```bash
ujust steam-link           # Update symlinks
ujust steam-link-status    # Show status
ujust steam-link-enable    # Enable at login
ujust steam-link-logs      # View logs
```

### Files
- Script: `/usr/share/distinctionos/steam-linker/steam-linker.sh`
- Service: `/usr/lib/systemd/user/distinctionos-steam-linker.service`
- Recipes: `/usr/share/distinctionos/just/steam-linker.just`
- Docs: `docs/steam-linker.md`

## XWM Player

Transparent playback of Bethesda game audio formats (`.xwm`, `.fuz`) via FFmpeg conversion and a configurable audio player.

### Features
- Double-click playback via MIME type registration
- Flatpak-aware player launching
- Extensible format handler system
- Hierarchical configuration (system → local → user)

### Quick Commands
```bash
xwm-player music.xwm                      # Play a file
xwm-player --convert voice.fuz voice.ogg  # Convert without playing
xwm-player --cleanup                       # Remove temp files
```

### Files
- Script: `/usr/bin/xwm-player`
- Config: `/usr/share/distinctionos/xwm-player/config`
- Handlers: `/usr/share/distinctionos/xwm-player/handlers/`
- Desktop: `/usr/share/applications/xwm-player.desktop`
- Docs: `docs/xwm-player.md`

## Technical Architecture

### Build Process Overview
1. **Base Layer**: Starts with Bazzite's gaming-optimized foundation
2. **Customization Layer**: Applies personal configurations and packages via numbered build scripts
3. **Distribution**: Publishes to GHCR for atomic updates with Rechunker optimization

### Build Script Execution Order

**CRITICAL**: Scripts execute in numerical order (00 → 06), with `95-utility-functions.sh` sourced by all scripts.

```
Containerfile Execution:
  │
  ├─→ COPY system_files/ → /         (overlay static files)
  ├─→ COPY --from=mesa-rpms / …      (pre-built Mesa OCI artifact)
  │
  ├─→ 00-kernel.sh
  │    ├─ Remove stock Fedora/Bazzite kernel packages
  │    ├─ Install CachyOS LTO kernel via COPR
  │    └─ Version-lock the kernel
  │
  ├─→ 01-kernel-modules.sh
  │    ├─ Detect installed CachyOS kernel version
  │    └─ Regenerate initramfs (dracut, zstd, ostree-compatible)
  │
  ├─→ 02-build.sh
  │    ├─ Source utility-functions.sh
  │    ├─ Remove unwanted Bazzite packages
  │    ├─ Install RPM packages with resilient best-effort strategy
  │    ├─ Configure repositories (Brave, COPR, etc.)
  │    └─ Validate critical packages
  │
  ├─→ 03-fix-opt.sh
  │    ├─ Source utility-functions.sh
  │    ├─ Scan /var/opt directory
  │    ├─ Move directories to /usr/lib/opt
  │    └─ Generate tmpfiles.d config for runtime persistence
  │
  ├─→ 04-config.sh
  │    ├─ Source utility-functions.sh
  │    ├─ Configure default shell (ZSH)
  │    ├─ Integrate Just recipes
  │    ├─ Hide incompatible Bazzite recipes
  │    ├─ Customize applications
  │    ├─ Update system caches (MIME, desktop, glib schemas)
  │    └─ Remove unwanted files (Waydroid, Wine utilities, Bazzite remnants)
  │
  ├─→ 05-cache-install.sh
  │    ├─ Source utility-functions.sh
  │    └─ dnf install /var/tmp/cache-rpms/*.rpm  (clean-install OCI artifact)
  │
  ├─→ 06-force-install.sh
  │    ├─ Source utility-functions.sh
  │    └─ rpm --force --nodeps -i /var/tmp/force-install-rpms/*.rpm
  │
  ├─→ 07-remote-grabber.sh
  │    ├─ Source utility-functions.sh
  │    ├─ Download GNOME Shell extensions
  │    └─ Compile gschemas for extensions
  │
  └─→ 08-validate.sh
       ├─ Source utility-functions.sh
       ├─ Verify ldconfig, icon caches, pixbuf loaders, schemas, fonts
       └─ Hard-fail on broken environment (VALIDATION_SOFT=1 to bypass)
```

### Key Technologies
- **Fedora Atomic**: Immutable base system with atomic updates
- **rpm-ostree**: Package layer management (runtime)
- **dnf5**: Package management (build-time)
- **Podman/Buildah**: Container runtime and build system
- **GitHub Actions**: Automated CI/CD pipeline
- **OCI Images**: Distribution format
- **Rechunker**: Layer optimization for efficient updates

## Customization Philosophy

### Design Principles
- **Fully Featured OS**: Focus on versatility and completeness
- **Development-Friendly**: Include essential development tools
- **Reproducible**: Declarative configuration for consistent builds
- **Personal**: Tailored to individual workflow preferences
- **Professional Quality**: Industry-standard code practices, comprehensive documentation
- **Maintainable**: DRY principle, utility function library, standardized patterns

### Package Management Strategy
- **System Packages (Build-time)**: Added during build via dnf5 for base image inclusion
- **User Packages (Runtime)**: Installed via Flatpak, Homebrew, or distrobox containers
- **Development Tools**: Integrated into base image for immediate availability

## Configuration Areas

### System Customizations
- **Desktop Environment**: GNOME with personal extensions and themes
- **Shell Configuration**: ZSH with Oh My Zsh and Powerlevel10k (installed via just recipe post-rebase)
- **Development Environment**: Pre-configured toolchains and editors
- **Gaming Optimizations**: Inherited from Bazzite base + xpadneo for Xbox controllers

### User Experience Enhancements
- **Dotfiles Integration**: Automated personal configuration deployment
- **Theme Consistency**: Kora icon theme, coordinated visual styling
- **Workflow Optimization**: Shortcuts and automation for common tasks
- **First-Run Automation**: SystemD service runs ujust distinction-install on first boot


## Key Files and Their Purposes

### Build Scripts (Executed at Build-Time)

#### `00-kernel.sh` - CachyOS LTO Kernel Installation
**Purpose**: Replace the stock Bazzite kernel with the CachyOS LTO (Link-Time Optimized) kernel
**Key Features**:
- Removes stock kernel packages before installing the replacement
- Installs via the `bieszczaders/kernel-cachyos-lto` COPR
- Version-locks the kernel to prevent unintended upgrades

**When to Edit**:
- Switching kernel variants
- Updating version lock

#### `01-kernel-modules.sh` - Initramfs Regeneration
**Purpose**: Detect the installed CachyOS kernel and regenerate the initramfs
**Key Features**:
- Detects the kernel version from `/usr/lib/modules/`
- Runs `dracut` with zstd compression and ostree compatibility flags
- Runs after the kernel install, before package installation

**When to Edit**: Rarely — only if dracut flags or initramfs composition needs changing.

#### `02-build.sh` - Package Management & Repository Configuration
**Purpose**: Core package installation with resilient best-effort strategy
**Key Features**:
- Attempts bulk installation per-repo, falls back to per-package on failure
- Tracks succeeded/failed/skipped packages separately
- Organized package installation by repository
- Repository outage tolerance (openzfs, CrossOver, Cider have had outages)

**When to Edit**:
- Adding new RPM packages
- Adding/removing repositories
- Modifying package removal list
- Updating version locks

#### `03-fix-opt.sh` - /opt Directory Persistence
**Purpose**: Ensure packages in /opt persist across reboots on an immutable system
**Key Features**:
- Dynamically scans /var/opt
- Generates tmpfiles.d configuration
- Executed at runtime by systemd-tmpfiles

**Technical Background**: On immutable systems, /opt can be ephemeral. This creates symlinks from /var/opt to /usr/lib/opt, ensuring packages like CrossOver remain accessible.

**When to Edit**: Rarely needed — automatically handles all /opt packages.

#### `04-config.sh` - System Configuration & Cleanup
**Purpose**: System service config, application customization, file cleanup
**Key Features**:
- Shell configuration (ZSH default via useradd)
- Just recipe integration
- Application .desktop file modifications
- System cache updates (MIME, desktop, glib schemas)
- Cleanup of unwanted Bazzite/Waydroid files (documented reasons for each)

**When to Edit**:
- Enabling/disabling SystemD services
- Adding Just recipe customizations
- Customizing application behavior
- Adding files to cleanup lists

#### `05-mesa-install.sh` - Custom Mesa Stack Installation
**Purpose**: Install a pre-built Fedora SRPM Mesa with freeworld codec patches
**Key Features**:
- Reads from the `mesa-rpms` OCI artifact stage (built weekly by `build-mesa.yml`)
- All packages come from one SRPM guaranteeing version coherency
- Uses `rpm --force --nodeps` to override conflicting Bazzite mesa packages

**When to Edit**:
- Never directly — the Mesa OCI stage is built separately
- To change Mesa packages, update `build-mesa.yml`

#### `07-remote-grabber.sh` - GNOME Extension Management
**Purpose**: Install and configure GNOME Shell extensions system-wide
**Key Features**:
- Extension download and installation
- Gschema compilation
- System-wide enablement

**When to Edit**:
- Adding/removing GNOME Shell extensions
- Updating extension sources

#### `95-utility-functions.sh` - Shared Utility Library
**Purpose**: Centralized functions and constants for all build scripts
**Key Features**:
- 8 ANSI color codes
- 6 logging functions (header, section, success, warning, error, info)
- Debug tracing functions
- Package validation functions
- File management helpers
- Command execution wrappers
- Counter utilities
- System information helpers
- Script lifecycle functions (`script_start`, `script_complete`)

**Usage**: `source /ctx/95-utility-functions.sh` at the start of every build script

**Benefits**:
- Eliminates ~300 lines of code duplication across scripts
- Single source of truth for logging behavior
- Consistent formatting and error handling

**CRITICAL**: Changes affect ALL build scripts — test thoroughly.

#### `wine-installer.sh` - Custom Wine Build Installation (INACTIVE)
**Purpose**: Install Kron4ek Wine builds with specific features
**Status**: Currently inactive, not in build sequence
**When Active**: Installs wine-staging-tkg-ntsync-amd64-wow64 from GitHub releases

**Note**: Remains separate from numbered sequence as it's intermittently used.

### `Containerfile` - Container Build Instructions
**Purpose**: Define the multi-stage build process
**Key Features**:
- Base image selection (Bazzite GNOME)
- Build context layer for script access
- system_files/ overlay copy
- Sequential script execution (00-06)
- Pre-built Mesa OCI artifact stage
- Color-coded build progress output
- OSTree container commit

**When to Edit**:
- Changing base image
- Modifying script execution order (rare)
- Enabling/disabling scripts (comment out execution line)
- Adjusting build optimizations

### `system_files/` Directory
Contains custom files overlaid at build time (akin to BlueBuild's 'overlay'):
- **usr/bin/**: Custom executables — `xwm-player`, `xiso`, `advmv`, `advcp`, `chsh`, `rpm-ostree-search-hl`, `xdg-terminal-exec`
- **usr/lib/systemd/user/**: User SystemD services (`distinctionos-steam-linker.service`)
- **usr/share/distinctionos/**: DistinctionOS project files (just recipes, housekeeper scripts, configs)
- **usr/share/fonts/**: Bundled Nerd Fonts — 0xProto, CommitMono, FiraCode, DejaVuSansMono, and others
- **usr/share/icons/**: Cursor themes — capitaine-cursors, DeepinDark-cursors, DeepinWhite-cursors
- **usr/share/themes/**: GTK theme — adw-gtk3-dark (GTK3 + GTK4 + libadwaita)
- **usr/share/glib-2.0/schemas/**: GNOME schema overrides for desktop settings
- **usr/share/applications/**: Custom .desktop files
- **usr/share/mime/**: MIME type registrations (xwm-player, rom-properties)
- **usr/lib/bootc/install/**: bootc install config (`20-distinction.toml`)
- **usr/lib64/**: Blur effect shared library for GNOME Shell effects
- **etc/zsh/**: System-wide ZSH config (zshrc, zprofile, zlogin, zshenv, zlogout)
- **etc/sudoers.d/**: Passwordless sudo for wheel group
- **etc/yum.repos.d/**: Pre-installed repository configs (Brave, COPR repos)
- **etc/rpm-ostreed.conf.d/**: TPM configuration for rpm-ostree daemon
- **etc/systemd/logind.conf.d/**: Power button / lid behaviour overrides
- **etc/dracut.conf.d/**: Dracut configuration for initramfs
- **etc/sysctl.conf**: Kernel parameter overrides

## Maintenance Considerations

### Update Strategy
- **Base Image Updates**: Automatic rebuilds when Bazzite releases updates (every 5 days scheduled)
- **Security Updates**: Regular rebuilds for security patches
- **Feature Updates**: Manual integration of new customizations via feature branches

### Testing Approach
- **Local Testing**: `just build` → `just run-vm-qcow2` for VM validation
- **Build Verification**: GitHub Actions logs for build-time issues
- **Functionality Testing**: Validate key features in VM before merge
- **Integration Testing**: Verify compatibility with upstream Bazzite changes

### Debug Approaches
- **Build Logs**: Examine GitHub Actions output for build-time issues (color-coded logging)
- **System Logs**: Use `journalctl` for runtime problem diagnosis
- **Layer Inspection**: Analyze image layers with `podman history`
- **Local Debugging**: `podman run -it localhost/distinctionos:test /bin/bash`

## Current Implementation Status

### ✅ Completed Features

#### Build System (2025-10-27 Major Refactoring)
- **Utility Functions Library**: Centralized logging, validation, and helper functions
- **Color-Coded Logging**: Consistent visual feedback across all build scripts
- **Comprehensive Error Handling**: Validation, error reporting, graceful degradation
- **Professional Code Quality**: DRY principle, documentation standards, consistent patterns
- **Script Organization**: Numerically ordered execution (01-06)

#### Default Shell Configuration
- **ZSH System Config**: Full system-wide ZSH configuration via `/etc/zsh/` (zshrc, zprofile, zlogin, zshenv, zlogout)
- **User Shell**: Post-rebase `ujust distinction-install-custom-shell` changes login shell and installs dotfiles
- **Root Shell**: Also configured during post-rebase setup

#### TPM Configuration
- **rpm-ostree TPM config**: `/etc/rpm-ostreed.conf.d/distinction.tpm.conf` provides TPM unlock hints to the rpm-ostree daemon
- **Status**: TPM auto-unlock system being redesigned — current implementation is partial; full ujust recipes and monitoring service are planned

#### Just Recipe System
- **Main Recipe**: `distinction.just` — post-install setup (Flatpaks, Homebrews, shell, NvChad, Nautilus scripts)
- **Steam Linker Recipe**: `steam-linker.just` — full Steam library symlink management
- **See**: `docs/ujust-recipes.md` for complete recipe reference

#### Security Configuration
- **Passwordless Sudo**: Configured for wheel group (user aware of security implications)
- Located at `/etc/sudoers.d/99-distinction-wheel-nopasswd`

### 🚧 Known Issues
- **NvChad root installation**: May need verification after first run (`sudo nvim` to complete)
- **TPM auto-unlock**: System being redesigned — current state is partial (config file only, no ujust recipes or monitor service)

## Maintenance Procedures

### After System Updates
```bash
rpm-ostree upgrade
systemctl reboot
# If TPM auto-unlock breaks after reboot, re-enroll manually
# (full TPM ujust recipes are planned but not yet implemented)
```

### Adding Packages

#### Build-Time Packages (in the image)
Edit `02-build.sh`. Packages are added to the repo-keyed arrays used by `install_packages_resilient`:
```bash
# Example: add to fedora repo array
install_packages_resilient "fedora" existing-packages new-package
```

#### Runtime Packages (post-install)
- **Flatpaks**: Add to `repo_files/flatpaks` on GitHub
- **Homebrews**: Add to `repo_files/brews` on GitHub
- Run: `ujust distinction-install` or specific recipe


## Future Roadmap

### Short-Term Goals 
- [ ] Revisit and redesign TPM auto-unlock (including ujust recipes and monitor service)
- [ ] Expand 'housekeeper' functionality (future: `.housekeeper` config files that maintain expansive directory structures)
- [ ] Update GitHub Actions to more closely match Bazzite (release pages with package changelogs per build)

### Long-Term Goals 
- [ ] **Standalone ISO**: Fully functional installer ISO (in progress via build-disk.yml)
- [ ] **Build Caching**: Implement layer caching for faster iteration

### Completed Goals ✅
- [x] Rechunker support for efficient updates
- [x] ZSH as default shell with system-wide config
- [x] Oh-my-zsh with Powerlevel10k (via post-install ujust)
- [x] Steam library symlink automation (Steam Linker housekeeper)
- [x] XWM Player — Bethesda audio format playback
- [x] CachyOS LTO kernel as default (`00-kernel.sh`)
- [x] Custom Mesa stack with freeworld codecs (`05-mesa-install.sh` + `build-mesa.yml`)
- [x] Build Script Refactoring:
  - [x] Utility functions library (`95-utility-functions.sh`)
  - [x] Color-coded logging and error handling across all scripts
  - [x] Resilient best-effort package installation strategy

## Notes for AI Assistants

### Code Style Preferences
- **Shell Scripts**: Follow Google Shell Style Guide conventions
- **Utility Functions**: Always source `/ctx/utility-functions.sh` in build scripts
- **Logging**: Use utility function logging (log_header, log_section, log_success, etc.)
- **Error Handling**: Use utility wrappers (run_with_log, check_file_exists, etc.)
- **Validation**: Use validation functions (validate_critical_packages, etc.)
- **YAML Files**: 2-space indentation, explicit string quoting where beneficial
- **Documentation**: Clear, concise explanations with practical examples
- **Context Generation**: At end of session, update claude.md and developer.md

### Project Philosophy
- Fully-featured experience prioritized over minimalism
- Native RPM packages preferred over Flatpaks where sensible
- Elegant solutions balancing functionality with maintainability
- Proactive problem prevention over reactive fixes
- Professional code quality with comprehensive documentation
- DRY principle - don't repeat yourself
- This is a personal project focused on creating an optimal Linux environment for both gaming and development work

### Build Script Development Guidelines

#### When Creating/Modifying Build Scripts:
1. **Always source utility functions first**: `source /ctx/utility-functions.sh`
2. **Use consistent logging**: log_header → log_section → log_success/error/warning
3. **Validate critical operations**: Use validation functions for important packages/files
4. **Document WHY, not just WHAT**: Inline comments should explain rationale
5. **Follow the established pattern**: Look at existing scripts for reference
6. **Test locally first**: `just build` before committing
7. **Use helper functions**: Take advantage of utility functions library (30+ functions)

#### Script Structure Template:
```bash
#!/usr/bin/bash
set -euo pipefail

# ============================================================================
# Script Name
# ============================================================================
# Purpose: Brief description
# Execution: Position in sequence
# ============================================================================

source /ctx/95-utility-functions.sh

script_start "Script Name" "Brief description"

log_section "Major operation"
# ... operations with logging ...
log_success "Operation complete"

script_complete "Script Name" "Next step: ..."
exit 0
```

### Important Distinctions

#### Build-Time vs Runtime:
- **Build-Time**: Scripts in build_files/ execute during image creation
  - Use `dnf5` for package management
  - Use utility functions for logging/validation
  - Changes require rebuild
  - Files go into /usr (immutable)
  
- **Runtime**: User operations after rebase
  - Use `rpm-ostree` for system packages
  - Use `flatpak` or `brew` for user packages
  - Use `ujust` recipes for automation
  - Changes persist in /var or /home

#### Directory Naming:
- All directories use **underscores**: `build_files/`, `system_files/`, `repo_files/`, `disk_config/`

### Housekeeper Standards
When creating new housekeepers:
1. Source `/usr/share/distinctionos/lib/housekeeper-common.sh`
2. Use `hk_init_logging` for standardised logging
3. Use `hk_load_config` for configuration hierarchy
4. Use `hk_lock` to prevent concurrent execution
5. Store state in `~/.local/share/distinctionos/<service>/`
6. Create corresponding `.just` recipe file

### DistinctionOS file structure
Some DistinctionOS projects should have their own directories inside `/usr/share/distinctionos/` and should respect overrides in `/usr/local/share/distinctionos/` and `~/.local/share/distinctionos/` and use `/var/log/distinctionos/` for logs(respecting a 500MiB size limit); Use of these directories depends on if a project has functionality that needs organization and should include a documentation file per project (documentation file should also include a tree-view for all files relavent to a project).


### User Technical Level
- Intermediate Linux system administration skills
- Comfortable with containers, package management, system configuration
- Appreciates detailed technical explanations with practical application
- Values clean, maintainable code with comprehensive documentation
- Prefers professional-grade solutions over quick hacks

### When Generating Context Updates
At the end of a session, user will request updated context files:
- **claude.md**: Comprehensive overview for AI assistants (this file)
- **developer.md**: Detailed technical documentation for human developers
- Include all architectural changes, new features, and rationale
- Update roadmap and completed goals
- Reflect current state accurately

---

## Document Metadata

**Version**: 3.4  
**Last Updated**: 2026-05-28  
**Major Changes**: 
- Fix all directory names to use underscores (build_files, system_files, etc.)
- Update build script sequence: 00-kernel, 01-kernel-modules, 02-build, 03-fix-opt, 04-config, 05-mesa-install, 06-remote-grabber
- Remove ZFS references (no longer in use)
- Add 00-kernel.sh (CachyOS LTO kernel) and 05-mesa-install.sh (custom Mesa OCI)
- Add XWM Player to Housekeeper Architecture and Completed Goals
- Update system_files/ contents to reflect actual files (fonts, cursors, themes, MIME, etc.)
- Correct TPM status (partial/planned, not complete)
- Add docs/xwm-player.md and docs/ujust-recipes.md to structure
- Remove references to non-existent firstrun and tpm-monitor binaries

**Maintainer**: phantomcortex  
**Purpose**: Provide comprehensive context to AI assistants working with DistinctionOS
