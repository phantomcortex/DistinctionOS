#!/usr/bin/bash

set -euo pipefail

# ============================================================================
# DistinctionOS System Configuration
# ============================================================================
# Purpose: System service configuration, application customization, cleanup
# Execution: Fifth script in build sequence
# Note: Miscellaneous tasks that don't fit elsewhere in the build process
# ============================================================================

# Source utility functions
source /ctx/95-utility-functions.sh

# ============================================================================
# Main Configuration Process
# ============================================================================

log_header "DistinctionOS System Configuration"

# ============================================================================
# Shell Configuration
# ============================================================================
# Set ZSH as default shell for new users and root
# Reason: Provides better interactive experience with enhanced features

log_section "Configuring default shell (ZSH)"

# Configure default shell for new users via useradd defaults
if [[ -e /etc/default/useradd ]]; then
  log_info "Setting ZSH as default shell for new users"
  sed -i 's|SHELL=/bin/bash|SHELL=/usr/bin/zsh|' /etc/default/useradd
  log_success "Default shell configured in /etc/default/useradd"
else
  log_warning "/etc/default/useradd not found, skipping new user default"
fi

# Set root shell to ZSH
log_info "Setting root shell to ZSH"
if usermod -s /usr/bin/zsh root; then
  log_success "Root shell changed to ZSH"
else
  log_error "Failed to change root shell"
fi

# ============================================================================
# SystemD Service Configuration
# ============================================================================
# Enable/disable system services for DistinctionOS functionality

log_section "Configuring SystemD services"

# Note: Services currently disabled during testing phase
# Uncomment when ready for production:
#
# log_info "Enabling distinction-firstrun.service"
# systemctl enable distinction-firstrun.service
# log_success "First-run service enabled"
#
# log_info "Enabling TPM monitor services"
# systemctl enable distinction-tpm-monitor.timer
# systemctl enable distinction-tpm-monitor.service
# log_success "TPM monitoring enabled"

log_info "SystemD service configuration complete (services currently disabled)"

# ============================================================================
# Just Recipe Integration
# ============================================================================
# Add DistinctionOS custom recipes and hide incompatible Bazzite recipes

log_section "Integrating DistinctionOS Just recipes"

# Import DistinctionOS recipes into the main justfile
readonly UBLUE_JUSTFILE="/usr/share/ublue-os/justfile"
readonly DISTINCTION_JUST="/usr/share/DistinctionOS/just/distinction.just"

if [[ -f "$UBLUE_JUSTFILE" ]]; then
  log_info "Adding DistinctionOS recipes to Universal Blue justfile"
  echo "import \"$DISTINCTION_JUST\"" >> "$UBLUE_JUSTFILE"
  log_success "DistinctionOS recipes imported"
else
  log_error "Universal Blue justfile not found at $UBLUE_JUSTFILE"
fi

# Hide incompatible Bazzite just recipes by prefixing with underscore
# Reason: Certain Bazzite recipes conflict with DistinctionOS configuration
log_section "Hiding incompatible Bazzite recipes"

readonly -a INCOMPATIBLE_RECIPES=(
  "install-coolercontrol"  # Conflicts with our thermal management
  "install-openrgb"        # Conflicts with our RGB control setup
)

for recipe in "${INCOMPATIBLE_RECIPES[@]}"; do
  log_info "Hiding recipe: $recipe"
  
  # Find which just file contains this recipe
  recipe_file=$(grep -l "^$recipe:" /usr/share/ublue-os/just/*.just 2>/dev/null || true)
  
  if [[ -n "$recipe_file" ]]; then
    # Prefix recipe name with underscore to hide it
    sed -i "s/^$recipe:/_$recipe:/" "$recipe_file"
    log_success "Recipe '$recipe' hidden"
  else
    log_warning "Recipe '$recipe' not found in any just file"
  fi
done

# ============================================================================
# Application Customization
# ============================================================================
# Modify .desktop files and application configurations

log_section "Customizing application configurations"

# ──────────────────────────────────────────────────────────────────────────
# Cider Music Player Icon Fix
# ──────────────────────────────────────────────────────────────────────────
# Issue: Cider doesn't respect icon themes properly
# Solution: Hard-code path to Kora theme icon

readonly CIDER_DESKTOP="/usr/share/applications/Cider.desktop"
if [[ -f "$CIDER_DESKTOP" ]]; then
  log_info "Fixing Cider icon path"
  sed -i 's@Icon=Cider@Icon=/usr/share/icons/kora/apps/scalable/cider.svg@g' "$CIDER_DESKTOP"
  log_success "Cider icon path updated"
else
  log_info "Cider not installed, skipping icon fix"
fi

# ──────────────────────────────────────────────────────────────────────────
# Winetricks Debug Output Suppression
# ──────────────────────────────────────────────────────────────────────────
# Issue: Winetricks GUI produces excessive Wine debug messages
# Solution: Set WINEDEBUG=-all environment variable in .desktop file

readonly WINETRICKS_DESKTOP="/usr/share/applications/winetricks.desktop"

if [[ -f "$WINETRICKS_DESKTOP" ]]; then
  log_info "Suppressing Winetricks debug output"
  sed -i 's@Exec=winetricks --gui@Exec=/usr/bin/env WINEDEBUG=-all winetricks -q --gui@g' "$WINETRICKS_DESKTOP"
  log_success "Winetricks debug output suppressed"
else
  log_warning "Winetricks .desktop file not found"
  
  # Create .desktop file if winetricks is installed but missing desktop file
  if rpm -q winetricks &>/dev/null; then
    log_info "Creating winetricks.desktop file"
    tee "$WINETRICKS_DESKTOP" > /dev/null << 'EOF'
[Desktop Entry]
Name=Winetricks
Comment=Work around problems and install applications under Wine
Exec=/usr/bin/env WINEDEBUG=-all winetricks -q --gui
Terminal=false
Icon=winetricks
Type=Application
Categories=Utility;
EOF
    log_success "Winetricks .desktop file created"
  fi
fi

# ============================================================================
# System Cache Updates
# ============================================================================
# Refresh system caches after modifications

log_section "Updating system caches"

# Icon cache refresh (required after Kora theme installation)
log_info "Updating icon cache"
if gtk-update-icon-cache -f /usr/share/icons/kora; then
  log_success "Icon cache updated"
else
  log_warning "Icon cache update failed (non-critical)"
fi

# Desktop database refresh (required after .desktop file modifications)
log_info "Updating desktop database"
if update-desktop-database /usr/share/applications; then
  log_success "Desktop database updated"
else
  log_warning "Desktop database update failed (non-critical)"
fi

# GLib schemas compilation (required after GNOME extension installation)
log_info "Compiling GLib schemas"
if glib-compile-schemas /usr/share/glib-2.0/schemas; then
  log_success "GLib schemas compiled"
else
  log_warning "GLib schema compilation failed (non-critical)"
fi

# MIME database refresh (required after MIME type changes)
log_info "Updating MIME database"
if update-mime-database /usr/share/mime; then
  log_success "MIME database updated"
else
  log_warning "MIME database update failed (non-critical)"
fi

# ============================================================================
# Cleanup - Unwanted Applications
# ============================================================================
# Remove .desktop files for applications we don't want visible

log_section "Removing unwanted application shortcuts"

# ──────────────────────────────────────────────────────────────────────────
# Waydroid Applications
# ──────────────────────────────────────────────────────────────────────────
# Reason: Waydroid was removed from base image, cleanup leftover shortcuts

log_info "Removing Waydroid application shortcuts"
waydroid_count=$(find /usr/share/applications -iname '*waydroid*' 2>/dev/null | wc -l)
if [[ $waydroid_count -gt 0 ]]; then
  find /usr/share/applications -iname '*waydroid*' -exec rm -rf {} +
  log_success "Removed $waydroid_count Waydroid shortcut(s)"
else
  log_info "No Waydroid shortcuts found"
fi

# ──────────────────────────────────────────────────────────────────────────
# Wine Utility Applications
# ──────────────────────────────────────────────────────────────────────────
# Reason: These Wine utilities clutter the application menu unnecessarily

log_info "Removing unwanted Wine application shortcuts"

readonly -a WINE_DESKTOP_FILES=(
  "wine-notepad.desktop"
  "wine-oleview.desktop"
  "wine-winemine.desktop"
  "wine-wordpad.desktop"
  "wine-winhelp.desktop"
)

wine_removed=0
for desktop_file in "${WINE_DESKTOP_FILES[@]}"; do
  desktop_path="/usr/share/applications/$desktop_file"
  if [[ -e "$desktop_path" ]]; then
    rm -f "$desktop_path"
    ((wine_removed++))
  fi
done

if [[ $wine_removed -gt 0 ]]; then
  log_success "Removed $wine_removed Wine shortcut(s)"
else
  log_info "No Wine shortcuts found"
fi

# ============================================================================
# Cleanup - Bazzite Remnants
# ============================================================================
# Remove Bazzite-specific files that don't apply to DistinctionOS

log_section "Removing Bazzite-specific files"

# Array of files to remove with reasons
declare -A BAZZITE_FILES=(
  ["/etc/profile.d/askpass.sh"]="SSH askpass conflicts with our authentication"
  ["/usr/libexec/openssh/gnome-ssh-askpass"]="GNOME SSH askpass binary"
  ["/usr/share/applications/gnome-ssh-askpass.desktop"]="SSH askpass desktop entry"
  ["/etc/profile.d/bazzite-neofetch.sh"]="Bazzite-branded neofetch configuration"
  ["/etc/yum.repos.d/charm.repo"]="Charm repository (unused)"
)

bazzite_removed=0
for file_path in "${!BAZZITE_FILES[@]}"; do
  reason="${BAZZITE_FILES[$file_path]}"
  
  if [[ -e "$file_path" ]]; then
    log_info "Removing: $file_path"
    log_info "  Reason: $reason"
    rm -f "$file_path"
    ((bazzite_removed++))
  fi
done

if [[ $bazzite_removed -gt 0 ]]; then
  log_success "Removed $bazzite_removed Bazzite file(s)"
else
  log_info "No Bazzite remnants found"
fi

# ============================================================================
# Configuration Complete
# ============================================================================

log_header "System configuration phase complete"

log_info "Configuration summary:"
echo "  • Default shell: ZSH"
echo "  • Just recipes: Integrated"
echo "  • Applications: Customized"
echo "  • System caches: Updated"
echo "  • Unwanted files: Removed"

exit 0
