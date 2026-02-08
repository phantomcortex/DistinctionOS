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
            successful_installations=$((successful_installations + 1))
        else
            failed_installations=$((failed_installations + 1))
        fi
    done

    # Install ZIP-based extensions
    log_info "Installing ZIP-based extensions..."
    for extension_id in "${!EXTENSIONS_ZIP[@]}"; do
        if install_zip_extension "$extension_id" "${EXTENSIONS_ZIP[$extension_id]}"; then
            successful_installations=$((successful_installations + 1))
        else
            failed_installations=$((failed_installations + 1))
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
        [[ -e "$git_dir" ]] || continue
        rm -rf "$git_dir"
        git_dirs_removed=$((git_dirs_removed + 1))
    done

    for git_dir in "$EXTENSIONS_DIR"/*/.github; do
        [[ -e "$git_dir" ]] || continue
        rm -rf "$git_dir"
        git_dirs_removed=$((git_dirs_removed + 1))
    done

    for git_dir in "$EXTENSIONS_DIR"/*/.gitignore; do
        [[ -e "$git_dir" ]] || continue
        rm -rf "$git_dir"
        git_dirs_removed=$((git_dirs_removed + 1))
    done
    
    log_success "Removed $git_dirs_removed .git directories"
    return 0
}

custom_blur-my-shell() {
  ###########################################
  # System-level installer for blur-my-shell (upstream Makefile only targets ~/.local)
  local NAME="blur-my-shell"
  local UUID="$NAME@phantomcortex"
  local REPO_DIR="$TMP_DIR/$NAME"
  local BUILD_DIR="$REPO_DIR/build"
  local TARGET_DIR="$EXTENSIONS_DIR/$UUID"
  local ZIP_FILE="$BUILD_DIR/$UUID.shell-extension.zip"

  log_info "Installing custom extension: $UUID"

  # Clone
  if [[ -d "$REPO_DIR" ]]; then
    rm -rf "$REPO_DIR"
  fi
  if ! git clone --quiet --depth 1 "https://github.com/phantomcortex/$NAME.git" "$REPO_DIR"; then
    log_error "Failed to clone $NAME"
    return 1
  fi

  # Build via gnome-extensions pack
  # --extra-source paths resolve relative to cwd, so we use absolute paths
  # to avoid fragile cd-based directory navigation
  mkdir -p "$BUILD_DIR"
  if ! gnome-extensions pack -f \
    --extra-source="$REPO_DIR/metadata.json" \
    --extra-source="$REPO_DIR/LICENSE" \
    --extra-source="$REPO_DIR/resources/icons" \
    --extra-source="$REPO_DIR/resources/ui" \
    --extra-source="$REPO_DIR/src/components" \
    --extra-source="$REPO_DIR/src/conveniences" \
    --extra-source="$REPO_DIR/src/effects" \
    --extra-source="$REPO_DIR/src/preferences" \
    --extra-source="$REPO_DIR/src/dbus" \
    --podir="$REPO_DIR/po" \
    --schema="$REPO_DIR/schemas/org.gnome.shell.extensions.$NAME.gschema.xml" \
    -o "$BUILD_DIR" \
    "$REPO_DIR/src"; then
    log_error "gnome-extensions pack failed for $NAME"
    return 1
  fi

  # Verify zip was produced
  if [[ ! -f "$ZIP_FILE" ]]; then
    log_error "Expected zip not found at $ZIP_FILE"
    log_error "Build directory contents: $(ls -1 "$BUILD_DIR" 2>/dev/null || echo '(empty)')"
    return 1
  fi

  # Extract to system extensions directory
  rm -rf "$TARGET_DIR"
  mkdir -p "$TARGET_DIR"
  if ! unzip -o "$ZIP_FILE" -d "$TARGET_DIR"; then
    log_error "Failed to unzip $ZIP_FILE to $TARGET_DIR"
    return 1
  fi

  # Compile schemas
  if [[ -d "$TARGET_DIR/schemas" ]]; then
    if [[ "$(glib-compile-schemas "$TARGET_DIR/schemas/")" == "No schema files found: doing nothing." ]]; then
      log_warning "GCS failed. \nFind schema and compile"
      find $TARGET_DIR -iname '*.xml' -exec glib-comile-schemas {} /;
    else
      log_success "GCS passed."
    fi
else
    echo "Output does not match."
fi
    glib-compile-schemas "$TARGET_DIR/schemas/"
  fi
  glib-compile-schemas "$TARGET_DIR/" 2>>"$LOG_FILE" || true

  log_success "Successfully installed $UUID"
  ###########################################
}

custom_dash-to-dock() {
  ###########################################
  local NAME="dash-to-dock"
  local UUID="$NAME@phantomcortex"
  local REPO_DIR="$TMP_DIR/$NAME"
  local TARGET_DIR="$EXTENSIONS_DIR/$UUID"

  log_info "Installing custom extension: $UUID"

  if [[ -d "$REPO_DIR" ]]; then
    rm -rf "$REPO_DIR"
  fi
  if ! git clone --quiet --depth 1 "https://github.com/phantomcortex/$NAME.git" "$REPO_DIR"; then
    log_error "Failed to clone $NAME"
    return 1
  fi

  if ! make -C "$REPO_DIR" install DESTDIR="/" PREFIX="/usr"; then
    log_error "make install failed for $NAME"
    return 1
  fi

  if [[ -f "$TARGET_DIR/schemas/*.xml" ]]; then
    log_info "schema found at $TARGET_DIR/schemas/"
    glib-compile-schemas "$TARGET_DIR/schemas" 
  elif [[ -e "/usr/share/glib-2.0/schemas/org.gnome.shell.extensions.dash-to-dock.gschema.xml" ]]; then
    log_info "schema found at /usr/share/glib-2.0/schemas/org.gnome.shell.extensions.dash-to-dock.gschema.xml"
    if [[ "$(glib-compile-schemas "/usr/share/glib-2.0/schemas/")" == "No schema files found: doing nothing." ]]; then
      log_warning "GCS failed. \nFind schema and compile"
      find /usr/share/glib-2.0/schemas/ -iname '$NAME' -exec glib-comile-schemas {} /;
    else
      log_success "GCS passed."
    fi
  else
    log_warning "failed to detect 'dash-to-dock' schema."
    log_warning "blind run: 'glib-compile-schemas /usr/share/glib-2.0/schemas/' "
    glib-compile-schemas "/usr/share/glib-2.0/schemas/" 
  fi
  glib-compile-schemas "$TARGET_DIR/" 2>>"$LOG_FILE" || true

  log_success "Successfully installed $UUID"
  ###########################################
}

main() {
    trap cleanup_temporary_files EXIT

    log_info "Starting $SCRIPT_NAME"
    setup_environment

    local had_errors=0

    # Standard extensions (git + zip)
    install_all_extensions || had_errors=1

    # Custom-built extensions (always attempted regardless of standard extension failures)
    custom_blur-my-shell || had_errors=1
    custom_dash-to-dock  || had_errors=1

    # Cleanup .git metadata from all cloned extensions
    remove_git_directories

    if [[ $had_errors -ne 0 ]]; then
        log_error "One or more extensions failed to install — review log above"
        exit 1
    fi

    log_success "All extensions installed successfully!"
    exit 0
}

# bazzite's dnf wrapper is such a pest
if [[ -f /usr/bin/dnf ]]; then
  rm /usr/bin/dnf
fi
main "$@"
# << nothing executes beyond this point >>
