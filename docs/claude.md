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
├── build-files/               # Build-time execution scripts (numerically ordered)
│   ├── 01-build.sh            # Package management (RPM, repos, keys) - FIRST
│   ├── 02-install-zfs.sh      # ZFS package installation - SECOND
│   ├── 03-fix-opt.sh          # /opt persistence configuration - THIRD
│   ├── 04-config.sh           # System services and misc config - FOURTH
│   ├── 05-kernel-modules.sh   # xpadneo & ZFS DKMS compilation - FIFTH
│   ├── 06-remote-grabber.sh   # GNOME Shell extension management - SIXTH (FINAL)
│   ├── 95-utility-functions.sh # Shared utility functions library - SOURCED BY ALL
│   └── wine-installer.sh      # Custom Wine builds (INACTIVE - not in build sequence)
│
├── system-files/              # Static files copied into the image
│   ├── usr/
│   │   ├── bin/               # Custom executables (firstrun, tpm-monitor, advmv, advcp)
│   │   ├── lib/systemd/       # SystemD services and timers
│   │   └── share/DistinctionOS/just/  # Just recipes
│   └── etc/
│       └── sudoers.d/         # Sudo configuration
│
├── repo-files/                # Resources for just recipes (hosted on GitHub)
│   ├── brews                  # Homebrew package list (for post-install)
│   └── flatpaks               # Flatpak application list (for post-install)
│
├── disk-config/               # Configuration for bootable disk creation
│   ├── disk.toml              # QCOW2/RAW VM disk configuration
│   └── iso.toml               # ISO installer configuration
│
├── docs/                      # Project documentation
│   ├── claude.md              # This file - AI assistant context
│   ├── developer.md           # Comprehensive developer documentation
│   └── (planned: wine.md, planning.md)
│
├── Containerfile              # Custom container build instructions
├── Justfile                   # Local development tooling (build, test, lint)
├── cosign.pub                 # Image signing public key
└── .github/workflows/         # GitHub Actions (build.yml & build-disk.yml)
```

## Technical Architecture

### Build Process Overview
1. **Base Layer**: Starts with Bazzite's gaming-optimized foundation
2. **Customization Layer**: Applies personal configurations and packages via numbered build scripts
3. **Distribution**: Publishes to GHCR for atomic updates with Rechunker optimization

### Build Script Execution Order

**CRITICAL**: Scripts execute in numerical order (01 → 06), with 95-utility-functions.sh sourced by all scripts.

```
Containerfile Execution:
  │
  ├─→ COPY system-files/ → /
  │
  ├─→ 01-build.sh
  │    ├─ Source utility-functions.sh
  │    ├─ Remove unwanted Bazzite packages
  │    ├─ Configure repositories (Cider, COPR, etc.)
  │    ├─ Install RPM packages by repository
  │    ├─ Version-lock Wine
  │    ├─ Install CrossOver and themes
  │    └─ Validate critical packages
  │
  ├─→ 02-install-zfs.sh
  │    ├─ Source utility-functions.sh
  │    ├─ Install ZFS repository
  │    └─ Install ZFS packages (DKMS compilation happens later)
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
  │    ├─ Setup SystemD services (currently disabled)
  │    ├─ Integrate Just recipes
  │    ├─ Hide incompatible Bazzite recipes
  │    ├─ Customize applications (Cider, Winetricks)
  │    ├─ Update system caches
  │    └─ Remove unwanted files (Waydroid, Wine utilities, Bazzite remnants)
  │
  ├─→ 05-kernel-modules.sh
  │    ├─ Source utility-functions.sh
  │    ├─ Detect Bazzite kernel version
  │    ├─ Clone & compile xpadneo module
  │    ├─ Verify module installation
  │    ├─ Run DKMS autoinstall (compiles ZFS + xpadneo)
  │    └─ Regenerate initramfs with new modules
  │
  └─→ 06-remote-grabber.sh
       ├─ Source utility-functions.sh
       ├─ Download GNOME Shell extensions
       └─ Compile gschemas for extensions
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

## Development Workflow

### CI/CD Pipeline
- **Trigger**: Push to main branch, pull requests, scheduled (every 5 days), or manual dispatch
- **Build**: Multi-stage container build with Buildah
- **Rechunker**: Layer optimization for efficient updates
- **Test**: Validation of image integrity
- **Sign**: Cosign image signing
- **Deploy**: Automatic publishing to GitHub Container Registry

### Local Development
```bash
# Build locally
just build

# Build and test in VM
just build-qcow2
just run-vm-qcow2

# Lint and format shell scripts
just lint
just format

# Clean build artifacts
just clean
```

## Key Files and Their Purposes

### Build Scripts (Executed at Build-Time)

#### `01-build.sh` - Package Management & Repository Configuration
**Purpose**: Core package installation, repository setup, package removal
**Key Features**:
- Color-coded logging with validation
- Organized package installation by repository (associative array)
- HEIF/Glycin workaround for image rendering
- Wine version-locking
- Critical package validation
- CrossOver and theme installation from GitHub releases

**When to Edit**:
- Adding new RPM packages
- Adding/removing repositories
- Modifying package removal list
- Updating version locks

#### `02-install-zfs.sh` - ZFS Package Installation
**Purpose**: Install ZFS packages for later DKMS compilation
**Key Features**:
- Minimal, concise design
- Repository configuration
- Package installation only (compilation happens in 05-kernel-modules.sh)

**When to Edit**:
- Updating ZFS repository URL
- Changing ZFS version

**Note**: Can be disabled by commenting out in Containerfile during rapid development to speed builds.

#### `03-fix-opt.sh` - /opt Directory Persistence
**Purpose**: Ensure packages in /opt persist across reboots
**Key Features**:
- Dynamically scans /var/opt
- Generates tmpfiles.d configuration
- Executed at runtime by systemd-tmpfiles

**Technical Background**: On immutable systems, /opt can be ephemeral. This creates symlinks from /var/opt to /usr/lib/opt, ensuring packages like Brave Browser and CrossOver remain accessible.

**When to Edit**: Rarely needed - automatically handles all /opt packages.

#### `04-config.sh` - System Configuration & Cleanup
**Purpose**: System service config, application customization, file cleanup
**Key Features**:
- Six major organized sections
- Shell configuration (ZSH default)
- Just recipe integration
- Application .desktop file modifications
- System cache updates
- Cleanup of unwanted files (documented reasons for each)

**When to Edit**:
- Enabling/disabling SystemD services
- Adding Just recipe customizations
- Customizing application behavior
- Adding files to cleanup lists

#### `05-kernel-modules.sh` - Kernel Module Compilation
**Purpose**: Compile xpadneo module and run DKMS autoinstall
**Key Features**:
- Kernel version detection
- Custom makefile generation for ostree compatibility
- Module compilation and verification
- DKMS autoinstall (compiles both xpadneo and ZFS)
- Initramfs regeneration with secure permissions

**When to Edit**:
- Adding new kernel modules
- Modifying xpadneo compilation parameters

**Note**: Custom makefile is critical for ostree systems - do not modify heredoc section.

#### `06-remote-grabber.sh` - GNOME Extension Management
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
- Script lifecycle functions

**Usage**: `source /ctx/utility-functions.sh` at the start of every build script

**Benefits**:
- Eliminates ~300 lines of code duplication across scripts
- Single source of truth for logging behavior
- Consistent formatting and error handling
- Enhanced functionality (25+ utility functions)
- Easier maintenance (change once, affects all scripts)

**When to Edit**:
- Modifying logging format/behavior globally
- Adding new shared utility functions
- Changing color scheme
- Adding new validation patterns

**CRITICAL**: Changes affect ALL build scripts - test thoroughly!

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
- system-files overlay copy
- Sequential script execution (01-06)
- Color-coded build progress output
- OSTree container commit

**When to Edit**:
- Changing base image
- Modifying script execution order (rare)
- Enabling/disabling scripts (comment out execution line)
- Adjusting build optimizations

### `system-files/` Directory
Contains custom files added at build time (akin to BlueBuild's 'overlay'):
- **usr/bin/**: Custom executables (firstrun, tpm-monitor, advmv, advcp)
- **usr/lib/systemd/**: SystemD units and timers (distinction-firstrun, tpm-monitor)
- **usr/share/DistinctionOS/just/**: Just recipes (distinction.just, tpm.just)
- **etc/sudoers.d/**: Passwordless sudo configuration (user aware of security implications)

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
- **ZSH as System Default**: Configured for all new users via `/etc/default/useradd`
- **Root Shell**: ZSH configured for root user
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
- **NvChad root installation**: May need verification after first run (`sudo nvim` to complete)
- **TPM re-enrollment**: Requires manual password entry (by design for security)
- **Plymouth hang**: System occasionally hangs briefly at Plymouth screen after shutdown signal (cosmetic, under investigation)
- **Build time**: ZFS compilation adds ~10-15 minutes (acceptable as system matures)

## Maintenance Procedures

### After System Updates
```bash
rpm-ostree upgrade
# TPM monitor will detect and notify about changes
ujust distinction-tpm-reenrol  # If notified
systemctl reboot
```

### TPM Management
```bash
ujust distinction-tpm-check     # Check if re-enrollment needed
ujust distinction-tpm-verify    # Verify current status
ujust distinction-tpm-logs      # View recent activity
```

### Adding Packages

#### Build-Time Packages (in the image)
Edit `01-build.sh`:
```bash
declare -A RPM_PACKAGES=(
  ["fedora"]="existing-packages new-package"
  ["copr:user/repo"]="copr-package"
)
```

#### Runtime Packages (post-install)
- **Flatpaks**: Add to `repo-files/flatpaks` on GitHub
- **Homebrews**: Add to `repo-files/brews` on GitHub
- Run: `ujust distinction-install` or specific recipe

### Modifying Build Scripts
1. Edit appropriate numbered script (01-06)
2. Maintain logging patterns using utility functions
3. Test locally: `just build`
4. Commit to feature branch
5. Create pull request for CI/CD validation
6. Merge after successful build

## Future Roadmap

### Short-Term Goals (1-3 months)
- [ ] Apply utility function patterns to system-files/ shell scripts
- [ ] Create `wine.md` documentation for Wine installation process
- [ ] Enhanced build time optimization strategies
- [ ] Comprehensive testing suite for Just recipes

### Long-Term Goals (6-12 months)
- [ ] **Standalone ISO**: Fully functional installer ISO (in progress via build-disk.yml)
- [ ] **CachyOS-LTO Kernel**: Ship optimized kernel by default
- [ ] **Steam Icon Manager**: Automated service for managing Steam game shortcuts
- [ ] **Extended TPM Recovery**: Fully automated re-enrollment without password prompt
- [ ] **Build Caching**: Implement layer caching for faster iteration

### Completed Goals ✅
- Rechunker support for efficient updates
- ZSH as default shell with automated configuration
- Oh-my-zsh and Powerlevel10k automatic installation
- TPM auto-unlock with proactive monitoring system
- **Build Script Refactoring** (2025-10-27):
  - Complete overhaul of all build scripts
  - Utility functions library implementation
  - Color-coded logging system
  - Comprehensive error handling
  - Professional code quality standards
  - ~300 lines of duplication eliminated

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

source /ctx/utility-functions.sh

script_start "Script Name" "Brief description"

log_section "Major operation"
# ... operations with logging ...
log_success "Operation complete"

script_complete "Script Name" "Next step: ..."
exit 0
```

### Important Distinctions

#### Build-Time vs Runtime:
- **Build-Time**: Scripts in build-files/ execute during image creation
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
- **Filesystem**: Still uses `build_files/` and `system_files/` (underscores)
- **Documentation**: References `build-files/` and `system-files/` (hyphens) for consistency
- **Future**: Will be renamed to match documentation

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

**Version**: 3.0  
**Last Updated**: 2025-10-27  
**Major Changes**: 
- Complete build script refactoring documentation
- Utility functions library implementation
- Script renaming to numerical order (01-06, 95)
- Enhanced code quality standards
- Comprehensive error handling patterns
- ~300 lines of duplication eliminated

**Maintainer**: phantomcortex  
**Purpose**: Provide comprehensive context to AI assistants working with DistinctionOS
