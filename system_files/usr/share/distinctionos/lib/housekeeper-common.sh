#!/usr/bin/env bash
# =============================================================================
# DistinctionOS Housekeeper Common Library
# =============================================================================
# Shared utilities for all housekeeper services
# Source this file at the beginning of any housekeeper script:
#   source /usr/share/distinctionos/lib/housekeeper-common.sh
#
# Respects XDG Base Directory Specification and provides:
#   - Standardised logging with rotation
#   - Configuration management with override hierarchy
#   - State persistence utilities
#   - Common helper functions
# =============================================================================

# Prevent double-sourcing
[[ -n "${_HOUSEKEEPER_COMMON_SOURCED:-}" ]] && return 0
readonly _HOUSEKEEPER_COMMON_SOURCED=1

set -euo pipefail

# -----------------------------------------------------------------------------
# Constants & Defaults
# -----------------------------------------------------------------------------
readonly HOUSEKEEPER_VERSION="1.1.0"
readonly HOUSEKEEPER_LOG_DIR="/var/log/distinctionos"
readonly HOUSEKEEPER_LOG_MAX_SIZE_MB=500
readonly HOUSEKEEPER_SYSTEM_SHARE="/usr/share/distinctionos"
readonly HOUSEKEEPER_LOCAL_SHARE="/usr/local/share/distinctionos"
readonly HOUSEKEEPER_USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/distinctionos"
readonly HOUSEKEEPER_USER_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/distinctionos"

# Service-specific variables (set by each housekeeper)
declare HOUSEKEEPER_SERVICE_NAME="${HOUSEKEEPER_SERVICE_NAME:-unknown}"
declare HOUSEKEEPER_LOG_FILE=""

# -----------------------------------------------------------------------------
# Logging Functions
# -----------------------------------------------------------------------------

# Initialise logging for a service
# Usage: hk_init_logging "service-name"
hk_init_logging() {
    local service_name="${1:?Service name required}"
    HOUSEKEEPER_SERVICE_NAME="$service_name"
    HOUSEKEEPER_LOG_FILE="${HOUSEKEEPER_LOG_DIR}/${service_name}.log"
    
    # Ensure log directory exists and is writable
    if [[ ! -d "$HOUSEKEEPER_LOG_DIR" ]]; then
        # Attempt to create (will fail without sudo, which is expected)
        sudo mkdir -p "$HOUSEKEEPER_LOG_DIR" 2>/dev/null || true
        sudo chmod 1777 "$HOUSEKEEPER_LOG_DIR" 2>/dev/null || true
    fi
    
    # Check if we can write to the log directory
    if [[ ! -w "$HOUSEKEEPER_LOG_DIR" ]]; then
        # Fall back to user directory
        local user_log_dir="${HOUSEKEEPER_USER_DATA}/logs"
        HOUSEKEEPER_LOG_FILE="${user_log_dir}/${service_name}.log"
        mkdir -p "$user_log_dir"
    fi
    
    # Perform log rotation if needed
    hk_rotate_logs
    
    hk_log "INFO" "=== ${service_name} started (v${HOUSEKEEPER_VERSION}) ==="
}

# Log a message with timestamp and level
# Usage: hk_log "LEVEL" "message"
hk_log() {
    local level="${1:?Log level required}"
    local message="${2:?Message required}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    local log_line="[${timestamp}] [${level}] ${message}"
    
    # Write to log file
    if [[ -n "$HOUSEKEEPER_LOG_FILE" ]]; then
        echo "$log_line" >> "$HOUSEKEEPER_LOG_FILE" 2>/dev/null || true
    fi
    
    # Also output to stderr for systemd journal capture
    case "$level" in
        ERROR|WARN)
            echo "$log_line" >&2
            ;;
        *)
            if [[ "${HOUSEKEEPER_VERBOSE:-false}" == "true" ]]; then
                echo "$log_line" >&2
            fi
            ;;
    esac
}

# Convenience logging functions
hk_info()  { hk_log "INFO"  "$*"; }
hk_warn()  { hk_log "WARN"  "$*"; }
hk_error() { hk_log "ERROR" "$*"; }
hk_debug() { [[ "${HOUSEKEEPER_DEBUG:-false}" == "true" ]] && hk_log "DEBUG" "$*" || true; }

# Rotate logs if total size exceeds limit
hk_rotate_logs() {
    local log_dir="${HOUSEKEEPER_LOG_DIR}"
    local max_size_bytes=$((HOUSEKEEPER_LOG_MAX_SIZE_MB * 1024 * 1024))
    
    # Check if using fallback directory
    if [[ ! -d "$log_dir" ]] || [[ ! -w "$log_dir" ]]; then
        log_dir="${HOUSEKEEPER_USER_DATA}/logs"
        [[ -d "$log_dir" ]] || return 0
    fi
    
    # Calculate current total size
    local current_size
    current_size=$(du -sb "$log_dir" 2>/dev/null | cut -f1) || current_size=0
    
    if (( current_size > max_size_bytes )); then
        # Find and remove oldest log files until under limit
        while (( current_size > max_size_bytes )); do
            local oldest
            oldest=$(find "$log_dir" -name "*.log*" -type f -printf '%T+ %p\n' 2>/dev/null | \
                     sort | head -n1 | cut -d' ' -f2-)
            
            [[ -n "$oldest" ]] || break
            
            rm -f "$oldest"
            current_size=$(du -sb "$log_dir" 2>/dev/null | cut -f1) || break
        done
    fi
    
    # Rotate individual log files over 50MB
    local max_individual=$((50 * 1024 * 1024))
    # Use nullglob to handle no matches gracefully
    local old_nullglob
    old_nullglob=$(shopt -p nullglob 2>/dev/null || echo "shopt -u nullglob")
    shopt -s nullglob
    for logfile in "$log_dir"/*.log; do
        [[ -f "$logfile" ]] || continue
        local size
        size=$(stat -c%s "$logfile" 2>/dev/null) || continue
        
        if (( size > max_individual )); then
            # Rotate: .log -> .log.1 -> .log.2 (keep 3 rotations)
            [[ -f "${logfile}.2" ]] && rm -f "${logfile}.2"
            [[ -f "${logfile}.1" ]] && mv "${logfile}.1" "${logfile}.2"
            mv "$logfile" "${logfile}.1"
            touch "$logfile"
        fi
    done
    # Restore previous nullglob setting
    eval "$old_nullglob" 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Configuration Management
# -----------------------------------------------------------------------------

# Load configuration with override hierarchy:
# 1. /usr/share/distinctionos/<service>/<service>.conf (system defaults)
# 2. /usr/local/share/distinctionos/<service>/<service>.conf (local overrides)
# 3. ~/.config/distinctionos/<service>.conf (user overrides)
#
# Usage: hk_load_config "service-name"
# Sets variables from config files (KEY=value format)
hk_load_config() {
    local service_name="${1:?Service name required}"
    local config_file="${service_name}.conf"
    
    # System defaults
    local system_conf="${HOUSEKEEPER_SYSTEM_SHARE}/${service_name}/${config_file}"
    # shellcheck source=/dev/null
    [[ -f "$system_conf" ]] && source "$system_conf" || true
    
    # Local overrides
    local local_conf="${HOUSEKEEPER_LOCAL_SHARE}/${service_name}/${config_file}"
    # shellcheck source=/dev/null
    [[ -f "$local_conf" ]] && source "$local_conf" || true
    
    # User overrides
    local user_conf="${HOUSEKEEPER_USER_CONFIG}/${config_file}"
    # shellcheck source=/dev/null
    [[ -f "$user_conf" ]] && source "$user_conf" || true
}

# Get a configuration value with default
# Usage: value=$(hk_config_get "KEY" "default_value")
hk_config_get() {
    local key="${1:?Key required}"
    local default="${2:-}"
    echo "${!key:-$default}"
}

# -----------------------------------------------------------------------------
# State Management
# -----------------------------------------------------------------------------

# Get the state directory for a service
# Usage: state_dir=$(hk_state_dir "service-name")
hk_state_dir() {
    local service_name="${1:?Service name required}"
    local state_dir="${HOUSEKEEPER_USER_DATA}/${service_name}"
    mkdir -p "$state_dir"
    echo "$state_dir"
}

# Read JSON state file
# Usage: state=$(hk_state_read "service-name" "state-file.json")
hk_state_read() {
    local service_name="${1:?Service name required}"
    local filename="${2:-state.json}"
    local state_file
    state_file="$(hk_state_dir "$service_name")/${filename}"
    
    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    else
        echo "{}"
    fi
}

# Write JSON state file
# Usage: echo '{"key":"value"}' | hk_state_write "service-name" "state-file.json"
hk_state_write() {
    local service_name="${1:?Service name required}"
    local filename="${2:-state.json}"
    local state_file
    state_file="$(hk_state_dir "$service_name")/${filename}"
    
    # Write atomically using temp file
    local temp_file
    temp_file=$(mktemp)
    cat > "$temp_file"
    mv "$temp_file" "$state_file"
}

# -----------------------------------------------------------------------------
# Path Utilities
# -----------------------------------------------------------------------------

# Expand ~ and environment variables in a path
# Usage: expanded=$(hk_expand_path "~/some/path")
hk_expand_path() {
    local path="${1:?Path required}"
    eval echo "$path"
}

# Check if a path is a valid symlink target
# Usage: if hk_is_valid_target "/path/to/target"; then ...
hk_is_valid_target() {
    local target="${1:?Target required}"
    [[ -e "$target" ]] && [[ -d "$target" || -f "$target" ]]
}

# Create parent directories if needed
# Usage: hk_ensure_parent "/path/to/file"
hk_ensure_parent() {
    local path="${1:?Path required}"
    local parent
    parent="$(dirname "$path")"
    [[ -d "$parent" ]] || mkdir -p "$parent"
}

# -----------------------------------------------------------------------------
# Symlink Management
# -----------------------------------------------------------------------------

# Create a managed symlink (tracked in state)
# Usage: hk_create_symlink "target" "link_path" "service-name"
hk_create_symlink() {
    local target="${1:?Target required}"
    local link_path="${2:?Link path required}"
    local service_name="${3:?Service name required}"
    
    # Ensure parent directory exists
    hk_ensure_parent "$link_path"
    
    # Remove existing symlink if present
    if [[ -L "$link_path" ]]; then
        rm -f "$link_path"
    elif [[ -e "$link_path" ]]; then
        hk_warn "Cannot create symlink at '${link_path}': path exists and is not a symlink"
        return 1
    fi
    
    # Create symlink
    if ln -s "$target" "$link_path"; then
        hk_debug "Created symlink: ${link_path} -> ${target}"
        return 0
    else
        hk_error "Failed to create symlink: ${link_path} -> ${target}"
        return 1
    fi
}

# Remove a symlink if it's managed by us
# Usage: hk_remove_symlink "link_path"
hk_remove_symlink() {
    local link_path="${1:?Link path required}"
    
    if [[ -L "$link_path" ]]; then
        rm -f "$link_path"
        hk_debug "Removed symlink: ${link_path}"
        return 0
    else
        hk_warn "Not a symlink: ${link_path}"
        return 1
    fi
}

# Check if a symlink is broken
# Usage: if hk_is_broken_symlink "/path/to/link"; then ...
hk_is_broken_symlink() {
    local link_path="${1:?Link path required}"
    [[ -L "$link_path" ]] && [[ ! -e "$link_path" ]]
}

# -----------------------------------------------------------------------------
# JSON Utilities (basic, no jq dependency)
# -----------------------------------------------------------------------------

# These provide basic JSON manipulation without requiring jq
# For complex JSON operations, services should check for jq availability

# Check if jq is available
hk_has_jq() {
    command -v jq &>/dev/null
}

# Simple JSON array append (requires jq)
# Usage: new_json=$(echo "$json" | hk_json_array_append ".array" '{"key":"value"}')
hk_json_array_append() {
    local path="${1:?JSON path required}"
    local value="${2:?Value required}"
    
    if hk_has_jq; then
        jq "${path} += [${value}]"
    else
        hk_error "jq not available for JSON manipulation"
        cat  # Pass through unchanged
    fi
}

# -----------------------------------------------------------------------------
# Locking
# -----------------------------------------------------------------------------

# File descriptor for lock (use a high number to avoid conflicts)
declare -g _HK_LOCK_FD=""

# Acquire an exclusive lock for a service
# Usage: hk_lock "service-name" || exit 1
hk_lock() {
    local service_name="${1:?Service name required}"
    local lock_file="/tmp/distinctionos-${service_name}.lock"
    
    # Use a unique file descriptor per service
    # This avoids issues with the global exec approach
    exec {_HK_LOCK_FD}>"$lock_file" || {
        hk_warn "Failed to open lock file: ${lock_file}"
        return 1
    }
    
    if ! flock -n "$_HK_LOCK_FD"; then
        hk_warn "Another instance of ${service_name} is already running"
        return 1
    fi
    
    # Write PID to lock file
    echo $$ >&"$_HK_LOCK_FD"
    return 0
}

# Release the lock (called automatically on exit, but can be called manually)
# Usage: hk_unlock
hk_unlock() {
    if [[ -n "${_HK_LOCK_FD:-}" ]]; then
        flock -u "$_HK_LOCK_FD" 2>/dev/null || true
        eval "exec ${_HK_LOCK_FD}>&-" 2>/dev/null || true
        _HK_LOCK_FD=""
    fi
}

# -----------------------------------------------------------------------------
# Cleanup & Exit Handling
# -----------------------------------------------------------------------------

# Register cleanup function
# Usage: hk_on_exit cleanup_function
hk_on_exit() {
    local func="${1:?Function required}"
    trap "$func" EXIT
}

# Standard exit with logging
# Usage: hk_exit 0 "Completed successfully"
hk_exit() {
    local code="${1:-0}"
    local message="${2:-}"
    
    if [[ -n "$message" ]]; then
        if (( code == 0 )); then
            hk_info "$message"
        else
            hk_error "$message"
        fi
    fi
    
    hk_info "=== ${HOUSEKEEPER_SERVICE_NAME} finished (exit code: ${code}) ==="
    
    # Clean up lock
    hk_unlock
    
    exit "$code"
}

# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

# Check if running as root
hk_is_root() {
    [[ $EUID -eq 0 ]]
}

# Get the effective user's home directory (even when running as root via sudo)
hk_get_user_home() {
    if [[ -n "${SUDO_USER:-}" ]]; then
        eval echo "~${SUDO_USER}"
    else
        echo "$HOME"
    fi
}

# -----------------------------------------------------------------------------
# Initialisation Check
# -----------------------------------------------------------------------------

# Verify the library was sourced correctly
hk_verify_sourced() {
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        echo "ERROR: This script should be sourced, not executed directly." >&2
        echo "Usage: source ${BASH_SOURCE[0]}" >&2
        exit 1
    fi
}

hk_verify_sourced
