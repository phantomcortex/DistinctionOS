#!/bin/bash

# Wine Build Downloader and Extractor
# Downloads latest wine-staging-tkg build from Kron4ek/Wine-Builds
# Extracts to /usr whilst excluding unwanted files

set -euo pipefail

# Configuration
readonly GITHUB_API_URL="https://api.github.com/repos/Kron4ek/Wine-Builds/releases/latest"
readonly WINE_PATTERN="wine-10.12-staging-tkg-ntsync-amd64-wow64\.tar\.xz"
readonly EXTRACTION_TARGET="/usr"
readonly TEMP_DIR="/tmp/wine-build-$$"
readonly EXCLUDED_FILE="wine-tkg-config.txt"

# Logging functions
log_info() {
    echo "[INFO] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_warn() {
    echo "[WARN] $*" >&2
}

# Cleanup function
cleanup() {
    if [[ -d "${TEMP_DIR}" ]]; then
        log_info "Cleaning up temporary directory: ${TEMP_DIR}"
        rm -rf "${TEMP_DIR}"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Verify prerequisites
check_prerequisites() {
    local missing_tools=()
    
    for tool in curl jq tar; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -ne 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install with: dnf5 install ${missing_tools[*]}"
        exit 1
    fi
    
    if [[ $EUID -ne 0 ]]; then
        log_error "This script requires root privileges to extract to ${EXTRACTION_TARGET}"
        exit 1
    fi
}

# Fetch latest Wine build information
fetch_wine_build_info() {
    log_info "Fetching latest release information from GitHub API"
    
    local release_data
    if ! release_data=$(curl -sf "$GITHUB_API_URL"); then
        log_error "Failed to fetch release information from GitHub API"
        exit 1
    fi
    
    # Extract wine build asset information (ignore proton builds)
    local wine_asset
    wine_asset=$(echo "$release_data" | jq -r --arg pattern "$WINE_PATTERN" '
        .assets[] | 
        select(.name | test($pattern)) | 
        select(.name | test("proton") | not) |
        {name: .name, download_url: .browser_download_url}
    ' | head -1)
    
    if [[ -z "$wine_asset" || "$wine_asset" == "null" ]]; then
        log_error "No suitable Wine build found matching pattern: $WINE_PATTERN"
        exit 1
    fi
    
    echo "$wine_asset"
}

# Download Wine build
download_wine_build() {
    local asset_info="$1"
    local filename
    local download_url
    
    filename=$(echo "$asset_info" | jq -r '.name')
    download_url=$(echo "$asset_info" | jq -r '.download_url')
    
    log_info "Found Wine build: $filename"
    log_info "Download URL: $download_url"
    
    mkdir -p "$TEMP_DIR"
    local download_path="${TEMP_DIR}/${filename}"
    
    log_info "Downloading to: $download_path"
    if ! curl -L -o "$download_path" "$download_url"; then
        log_error "Failed to download Wine build"
        exit 1
    fi
    
    echo "$download_path"
}

# Extract Wine build
extract_wine_build() {
    local archive_path="$1"
    local filename
    filename=$(basename "$archive_path")
    local archive_root="${filename%.tar.xz}"
    
    log_info "Extracting Wine build to ${EXTRACTION_TARGET}"
    
    # Create extraction directory in temp
    local extract_dir="${TEMP_DIR}/extract"
    mkdir -p "$extract_dir"
    
    # Extract archive
    if ! tar -xf "$archive_path" -C "$extract_dir"; then
        log_error "Failed to extract archive"
        exit 1
    fi
    
    # Verify expected structure
    local wine_root="${extract_dir}/${archive_root}"
    if [[ ! -d "$wine_root" ]]; then
        log_error "Expected root directory not found: $archive_root"
        exit 1
    fi
    
    # Copy contents whilst excluding unwanted files
    log_info "Copying Wine files to ${EXTRACTION_TARGET}"
    for item in "$wine_root"/*; do
        local basename_item
        basename_item=$(basename "$item")
        
        if [[ "$basename_item" == "$EXCLUDED_FILE" ]]; then
            log_warn "Excluding file: $basename_item"
            continue
        fi
        
        log_info "Copying: $basename_item"
        if ! cp -r "$item" "$EXTRACTION_TARGET/"; then
            log_error "Failed to copy $basename_item to $EXTRACTION_TARGET"
            exit 1
        fi
    done
    
    log_info "Wine build installation completed successfully"
}

# Main execution
main() {
    log_info "Starting Wine build installation process"
    
    check_prerequisites
    
    local asset_info
    asset_info=$(fetch_wine_build_info)
    
    local archive_path
    archive_path=$(download_wine_build "$asset_info")
    
    extract_wine_build "$archive_path"
    
    log_info "Wine build installation process completed"
}

# Execute main function
main "$@"
