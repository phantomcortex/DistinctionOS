#!/bin/bash


# Author Note: This entire script is from Claude Sonnet 4 
# Yes I know, 'Vibe code bad!'
# But I don't think I would've made it this far without it...
# For better or worse I've managed to create an entire build system \
# and Modify bazzite into an unholy creation of my design, without much expierence in shell scripts.
# Make of that what you will.

# =============================================================================
# GNOME Shell Extensions Installation Script
# Enhanced version with proper error handling and modular design
# =============================================================================



set -euo pipefail  # Exit on any error, undefined variable, or pipe failure

# Constants and Configuration
readonly SCRIPT_NAME="${0##*/}"
readonly EXTENSIONS_DIR="/usr/share/gnome-shell/extensions"
readonly TMP_DIR="/tmp/gnome-shell-extensions"
readonly LOG_FILE="${TMP_DIR}/installation.log"

# Colour constants for elegant output
readonly RED='\033[31m'
readonly GREEN='\033[32m'
readonly YELLOW='\033[33m'
readonly BLUE='\033[34m'
readonly NC='\033[0m'

# Extension definitions - structured data approach
declare -A EXTENSIONS_GIT=(
    ["pip-on-top@rafostar.github.com"]="https://github.com/Rafostar/gnome-shell-extension-pip-on-top.git"
    ["clipboard-indicator@tudmotu.com"]="https://github.com/Tudmotu/gnome-shell-extension-clipboard-indicator.git"
    ["date-menu-formatter@marcinjakubowski.github.com"]="https://github.com/marcinjakubowski/date-menu-formatter.git"
    ["dash-to-dock@micxgx.gmail.com"]="https://github.com/micheleg/dash-to-dock.git"
    ["quick-settings-avatar@d-go"]="https://github.com/d-go/quick-settings-avatar.git"
)

declare -A EXTENSIONS_ZIP=(
    ["burn-my-windows@schneegans.github.com"]="https://github.com/Schneegans/Burn-My-Windows/releases/download/v46/burn-my-windows@schneegans.github.com.zip"
    ["gnome-ui-tune@itstime.tech"]="https://github.com/axxapy/gnome-ui-tune/releases/download/v1.10.2/gnome-ui-tune@itstime.tech.shell-extension.zip"
    ["tophat@fflewddur.github.io"]="https://github.com/fflewddur/tophat/releases/download/v22/tophat@fflewddur.github.io.v22.shell-extension.zip"
)

# Extensions requiring schema compilation
readonly SCHEMA_EXTENSIONS=("pip-on-top@rafostar.github.com")

# Extensions to be removed (if present)
readonly EXTENSIONS_TO_REMOVE=("hotedge@jonathan.jdoda.ca")

# =============================================================================
# Installation Functions
# =============================================================================

setup_environment() {
    mkdir -p "$TMP_DIR" "$EXTENSIONS_DIR"
}

log() {
    local level="$1"
    shift
    echo -e "[$(date '+%H:%M:%S')] [$level] $*"
}

log_info() { log "INFO" "$@"; }
log_success() { log "SUCCESS" "${GREEN}$*${NC}"; }
log_warning() { log "WARNING" "${YELLOW}$*${NC}"; }
log_error() { log "ERROR" "${RED}$*${NC}"; }

install_git_extension() {
    local extension_id="$1"
    local repository_url="$2"
    local target_dir="$EXTENSIONS_DIR/$extension_id"
    
    log_info "Installing Git-based extension: $extension_id"
    
    if [[ -d "$target_dir" ]]; then
        log_warning "Extension directory exists, removing: $target_dir"
        rm -rf "$target_dir"
    fi
    
    if git clone --quiet --depth 1 "$repository_url" "$target_dir"; then
        log_success "Successfully cloned: $extension_id"
        return 0
    else
        log_error "Failed to clone: $extension_id from $repository_url"
        return 1
    fi
}

install_zip_extension() {
    local extension_id="$1"
    local download_url="$2"
    local zip_filename="${extension_id}.zip"
    local zip_path="$TMP_DIR/$zip_filename"
    local target_dir="$EXTENSIONS_DIR/$extension_id"
    
    log_info "Installing ZIP-based extension: $extension_id"
    
    # Download archive
    if ! curl -L --silent --fail "$download_url" -o "$zip_path"; then
        log_error "Failed to download: $extension_id from $download_url"
        return 1
    fi
    
    # Prepare target directory
    if [[ -d "$target_dir" ]]; then
        log_warning "Extension directory exists, removing: $target_dir"
        rm -rf "$target_dir"
    fi
    mkdir -p "$target_dir"
    
    # Extract archive
    if unzip -qq -o "$zip_path" -d "$target_dir"; then
        log_success "Successfully extracted: $extension_id"
        rm -f "$zip_path"  # Cleanup
        return 0
    else
        log_error "Failed to extract: $extension_id"
        return 1
    fi
}

compile_extension_schemas() {
    local extension_id="$1"
    local schema_dir="$EXTENSIONS_DIR/$extension_id/schemas"
    
    if [[ -d "$schema_dir" ]]; then
        log_info "Compiling schemas for: $extension_id"
        if glib-compile-schemas "$schema_dir" 2>>"$LOG_FILE"; then
            log_success "Schemas compiled successfully for: $extension_id"
        else
            log_warning "Schema compilation failed for: $extension_id"
        fi
    fi
}

remove_extension() {
    local extension_id="$1"
    local target_dir="$EXTENSIONS_DIR/$extension_id"
    
    if [[ -d "$target_dir" ]]; then
        log_info "Removing extension: $extension_id"
        if rm -rf "$target_dir"; then
            log_success "Successfully removed: $extension_id"
        else
            log_error "Failed to remove: $extension_id"
        fi
    else
        log_info "Extension not present (skipping): $extension_id"
    fi
}

install_all_extensions() {
    local total_extensions=$((${#EXTENSIONS_GIT[@]} + ${#EXTENSIONS_ZIP[@]}))
    local successful_installations=0
    local failed_installations=0
    
    log_info "Beginning installation of $total_extensions extensions"
    
    # Remove unwanted extensions first
    log_info "Removing deprecated extensions..."
    for extension_id in "${EXTENSIONS_TO_REMOVE[@]}"; do
        remove_extension "$extension_id"
    done
    
    # Install Git-based extensions
    log_info "Installing Git-based extensions..."
    for extension_id in "${!EXTENSIONS_GIT[@]}"; do
        if install_git_extension "$extension_id" "${EXTENSIONS_GIT[$extension_id]}"; then
            ((successful_installations++))
        else
            ((failed_installations++))
        fi
    done
    
    # Install ZIP-based extensions
    log_info "Installing ZIP-based extensions..."
    for extension_id in "${!EXTENSIONS_ZIP[@]}"; do
        if install_zip_extension "$extension_id" "${EXTENSIONS_ZIP[$extension_id]}"; then
            ((successful_installations++))
        else
            ((failed_installations++))
        fi
    done

# Compile schemas for extensions that require it
    log_info "Processing extension schemas..."
    for extension_id in "${SCHEMA_EXTENSIONS[@]}"; do
        compile_extension_schemas "$extension_id"
    done
    
    # Installation summary
    log_success "Successful installations: $successful_installations"
    if [[ $failed_installations -gt 0 ]]; then
        log_error "Failed installations: $failed_installations"
        log_info "Please review the log file: $LOG_FILE"
        return 1
    else
        log_success "All extensions installed successfully!"
        return 0
    fi
}

cleanup_temporary_files() {
    log_info "Performing cleanup..."
    find "$TMP_DIR" -name "*.zip" -delete 2>/dev/null || true
    log_success "Cleanup completed"
}

main() {
    trap cleanup_temporary_files EXIT

    log_info "Starting $SCRIPT_NAME"
    setup_environment
    
    if install_all_extensions; then
        log_success "Extension installation completed successfully!"
        exit 0
    else
        log_error "Extension installation encountered errors"
        exit 1
    fi
}
main "$@"
