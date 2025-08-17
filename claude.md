# Claude Context: Distinction-UBlue-Internal

## Project Overview

**Distinction-UBlue-Internal** is a custom immutable Linux image built upon the Bazzite foundation, leveraging Universal Blue's infrastructure and tooling. This repository represents a personalised gaming and development environment optimised for a Fully featured expierence.


### Key Characteristics
- **Base System**: Bazzite (gaming-focused Fedora Atomic variant)
- **Build System**: Built from Universal Blue's github Image template and uses github-actions to build & push to ghcr
- **Target Audience**: Mainly Personal use, with gaming and development focus
- **Deployment**: OCI container images via GitHub Container Registry

## Repository Structure

```
distinction-ublue-internal/
├── system_files/               # Static files to be copied into the image
├── build_files/                # Build-time scripts
├── repo_files/                 # contains resources for just recipes
├── disk_config/                # contains configuration for build-disk.yml
├── Containerfile               # Custom container build instructions
├── README.md                   # User-facing documentation
├── claude.md                   # This AI context file
└── .github/
    └── workflows/            # contains build.yml & build-disk.yml for github actions
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
- **System Packages**: Declared in recipe.yml for base image inclusion
- **User Packages**: Installed via RPM packages, flatpak, or distrobox containers
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

### Local Development
```bash
# Clone the repository
git clone https://github.com/phantomcortex/distinction-ublue-internal.git

# Test build locally
podman build -t distinction-test .

# Run build validation
./scripts/validate-build.sh
```

### CI/CD Pipeline
- **Trigger**: Push to main branch or pull requests
- **Build**: Multi-architecture container builds
- **Test**: Validation of image integrity and functionality
- **Deploy**: Automatic publishing to GitHub Container Registry

## Key Files and Their Purposes

### `build_files/build_new.sh`
The main package installer of the configuration, defining:
- Package installations and removals

### `build_files/fix_opt.sh`
For packages installed to /opt:
- Fixes packages installed to opt vanishing at run-time

### `build_files/kernel_modules.sh`
For one kernel compilied from source:
- Compiles and adds xpadneo kernel module

### `build_files/layered_appimages.sh`
As the name implies adds directly to the OS image:
- user states that he is aware that you probably shouldn't layer appimages onto OCI images but is currently adament that these appimages stay in place

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
- Edit `build_new.sh` where it declares packages and corresponding repositories

### Configuration Files
1. Add files to `config/` directory
2. Map destination paths in `recipe.yml`
3. Validate file permissions and ownership

### Theme and Appearance
1. Add theme files to `system_files/usr/share/themes/`
2. Configure default selections in system settings
3. Test across different applications

### User Data Management
- **Persistent Storage**: User data remains intact across image updates
- **Configuration Persistence**: Personal settings preserved in `/var/home/`
- **Application Data**: Flatpak and container app data maintained


### Common Issues
- **Build Failures**: Often related to package availability or dependency conflicts
- **Runtime Problems**: Usually configuration-related or service conflicts
- **Update Issues**: May require manual intervention for major changes

### Debug Approaches
- **Build Logs**: Examine GitHub Actions output for build-time issues
- **System Logs**: Use `journalctl` for runtime problem diagnosis
- **Layer Inspection**: Analyze image layers with `podman history`

## Future Roadmap
- standalone ISO image file (that actually works)
- rechunker support 
 

### Planned Enhancements
- Ship Cachyos-lto kernel by default
- user use zsh by default
- on fresh installation, automatic install of oh-my-zsh, powerlevel10k, & user's preexisting p10k configureation from https://github.com/phantomcortex/dotfiles/

### Experimental Features
- Custom kernel optimizations
- Advanced security hardening
- Cloud development workflow integration

---

## Notes for AI Assistants
This repo does not use BlueBuild. Some scripts currently do not follow Google Shell Style Guide conventions. The user places priority on a Fully featured expierence with plenty of 'bells and whisles' more akin to a swiss army knife. The user wants a versatile powerhose rather than minimalism.

### Code Style Preferences
- **Shell Scripts**: Follow Google Shell Style Guide conventions
- **YAML Files**: 2-space indentation, explicit string quoting where beneficial
- **Documentation**: Clear, concise explanations with practical examples

### Project Context
This is a personal project focused on creating an optimal Linux environment for both gaming and development work. The user values clean, maintainable configurations and appreciates detailed explanations of technical concepts. They prefer elegant solutions that balance functionality with simplicity. The user strongly perfers native RPM packages over their flatpak counterparts depending on the app.

### Technical Expertise Level
The user has intermediate system admin skills and appreciates detailed technical discussions. They're comfortable with container technologies, package management, and system-level configurations. Explanations can include advanced concepts but should remain practical and actionable.
