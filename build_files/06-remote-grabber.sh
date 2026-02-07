#!/bin/bash

# =============================================================================
# GNOME Shell Extensions Installation Script
# Enhanced version with proper error handling and modular design
# =============================================================================

# Source utility functions
source /ctx/95-utility-functions.sh

set -euo pipefail 



# Constants and Configuration
readonly SCRIPT_NAME="${0##*/}"
readonly EXTENSIONS_DIR="/usr/share/gnome-shell/extensions"
readonly TMP_DIR="/tmp/gnome-shell-extensions"
readonly LOG_FILE="${TMP_DIR}/installation.log"

# Extension definitions - structured data approach
declare -A EXTENSIONS_GIT=(
    ["pip-on-top@rafostar.github.com"]="https://github.com/Rafostar/gnome-shell-extension-pip-on-top.git"
    ["clipboard-indicator@tudmotu.com"]="https://github.com/Tudmotu/gnome-shell-extension-clipboard-indicator.git"
    ["date-menu-formatter@marcinjakubowski.github.com"]="https://github.com/marcinjakubowski/date-menu-formatter.git"
    ["quick-settings-avatar@d-go"]="https://github.com/d-go/quick-settings-avatar.git")

declare -A EXTENSIONS_ZIP=(
    ["burn-my-windows@schneegans.github.com"]="https://github.com/Schneegans/Burn-My-Windows/releases/download/v47/burn-my-windows@schneegans.github.com.zip"
    ["gnome-ui-tune@itstime.tech"]="https://github.com/axxapy/gnome-ui-tune/releases/download/v1.11.0/gnome-ui-tune@itstime.tech.shell-extension.zip"
    ["tophat@fflewddur.github.io"]="https://github.com/fflewddur/tophat/releases/download/v23/tophat@fflewddur.github.io.v23.shell-extension.zip"
)

# Extensions requiring schema compilation
readonly SCHEMA_EXTENSIONS=("pip-on-top@rafostar.github.com" "burn-my-windows@schneegans.github.com")

# Extensions to be removed (if present)
readonly EXTENSIONS_TO_REMOVE=("hotedge@jonathan.jdoda.ca" "blur-my-shell@aunetx")

# =============================================================================
# Installation Functions
# =============================================================================

setup_environment() {
    mkdir -p "$TMP_DIR" "$EXTENSIONS_DIR"
}

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

remove_git_directories() {
    log_info "Removing git metadata from extensions..."
    local git_dirs_removed=0
    
    for git_dir in "$EXTENSIONS_DIR"/*/.git; do
        if [[ -d "$git_dir" ]]; then
            rm -rf "$git_dir"
            ((git_dirs_removed++))
        fi
    done
    
    log_success "Removed $git_dirs_removed .git directories"
}

custom_blur-my-shell() {
  log_info "Custom blur-my-shell installer >>>>"
  # This is a hacky system-level installer for blur-my-shell since \
  # included installer don't install to system 
  local NAME="blur-my-shell"
  local UUID="$NAME@phantomcortex"
  
  # grab
  git clone https://github.com/phantomcortex/$NAME.git $TMP_DIR/$NAME
  cd $TMP_DIR/$NAME
  log_info "cloned $UUID"
  
  # build
  mkdir -p build/ 
  cd src
  gnome-extensions pack -f \
	--extra-source=../metadata.json \
	--extra-source=../LICENSE \
	--extra-source=../resources/icons \
	--extra-source=../resources/ui \
	--extra-source=./components \
	--extra-source=./conveniences \
	--extra-source=./effects \
	--extra-source=./preferences \
	--extra-source=./dbus \
	--podir=../po \
	--schema=../schemas/org.gnome.shell.extensions.$NAME.gschema.xml \
    -o ../build 
  cd ..
  log_info "zipped $UUID"

  log_info "See build: $(ls build)"
  log_info "cd build"
  cd build
  if [ -e $UUID.shell-extension.zip ]; then
  	log_info "$UUID.shell-extension.zip does exist."
	find . -name *.zip -exec unzip -o {} /usr/share/gnome-shell/extensions/$UUID \;
    log_info "unzipped $UUID"
	glib-compile-schemas /usr/share/gnome-shell/extensions/$UUID/
	log_info "DEBUG:"
	
	ls /usr/share/gnome-shell/extensions/$UUID
  else
  	echo "$UUID.shell-extension.zip does NOT exist."
	log_info "find:"
	find . -iname '*.zip' &&
	log_info "fuzzy unzip"
	find . -name '*.zip' -exec unzip -o {} /usr/share/gnome-shell/extensions/$UUID \; && glib-compile-schemas /usr/share/gnome-shell/extensions/$UUID/

  fi
  
  cd $TMP_DIR

  log_success "blur-my-shell should be installed"

}

custom_dash-to-dock() {
  log_info "Custom dash-to-dock installer >>>>"
  # 
  local NAME="dash-to-dock"
  local UUID="$NAME@phantomcortex"
  
  # grab
  cd $TMP_DIR
  git clone https://github.com/phantomcortex/$NAME.git $TMP_DIR/$NAME
  log_info "cloned $UUID"

  cd $TMP_DIR/$NAME

  make install DESTDIR="/" PREFIX="/usr"
  glib-compile-schemas /usr/share/gnome-shell/extensions/$UUID/
  
  log_success "$NAME should be installed"

}

main() {
    trap cleanup_temporary_files EXIT

    log_info "Starting $SCRIPT_NAME"
    setup_environment

    if install_all_extensions; then
        log_success "Extension installation completed successfully!"
        log_info "blur-my-shell section:"
        custom_blur-my-shell
        log_info "dash-to-dock section:"
        custom_dash-to-dock
        log_info ".git removal section:"
        remove_git_directories


        exit 0
    else
        log_error "Extension installation encountered errors"
        exit 1
    fi
}

# bazzite's dnf wrapper is such a pest
if [[ -f /usr/bin/dnf ]]; then
  rm /usr/bin/dnf
fi
main "$@"
# << nothing executes beyond this point >>
