#!/usr/bin/env bash
# =============================================================================
# DistinctionOS Steam Linker
# =============================================================================
# Automatically creates symlinks to ~/Games/Steamlibrary/ from all Steam
# library locations, providing unified access to installed games.
#
# Features:
#   - Auto-discovers libraries via Steam's libraryfolders.vdf
#   - Tracks managed symlinks for restoration if accidentally deleted
#   - Removes broken symlinks automatically
#   - Logs all operations for troubleshooting
#
# Usage:
#   steam-linker.sh [OPTIONS]
#
# Options:
#   -v, --verbose    Enable verbose output
#   -d, --debug      Enable debug output
#   -n, --dry-run    Show what would be done without making changes
#   -c, --cleanup    Only remove broken symlinks, don't create new ones
#   -s, --status     Show current status and exit
#   -h, --help       Show this help message
#
# Part of the DistinctionOS Housekeeper Architecture
# =============================================================================

set -euo pipefail

# Service identity
readonly SERVICE_NAME="steam-linker"
readonly SERVICE_VERSION="1.0.0"

# Source the common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "/usr/share/distinctionos/lib/housekeeper-common.sh" ]]; then
    source "/usr/share/distinctionos/lib/housekeeper-common.sh"
elif [[ -f "${SCRIPT_DIR}/../lib/housekeeper-common.sh" ]]; then
    source "${SCRIPT_DIR}/../lib/housekeeper-common.sh"
else
    echo "ERROR: Cannot find housekeeper-common.sh" >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Configuration Defaults
# -----------------------------------------------------------------------------
STEAM_LINKER_TARGET_DIR="${HOME}/Games/Steamlibrary"
STEAM_LINKER_VDF_PATH="${HOME}/.local/share/Steam/steamapps/libraryfolders.vdf"
STEAM_LINKER_DRY_RUN="false"
STEAM_LINKER_CLEANUP_ONLY="false"

# -----------------------------------------------------------------------------
# VDF Parser
# -----------------------------------------------------------------------------
# Steam's VDF format is a simple key-value format with nested braces.
# We need to extract the "path" values from each library entry.

# Parse libraryfolders.vdf and extract library paths
# Usage: paths=$(parse_library_folders "/path/to/libraryfolders.vdf")
parse_library_folders() {
    local vdf_file="${1:?VDF file required}"
    
    if [[ ! -f "$vdf_file" ]]; then
        hk_error "VDF file not found: ${vdf_file}"
        return 1
    fi
    
    # Extract paths using awk
    # VDF format has "path" entries like: "path"		"/path/to/library"
    awk '
        /"path"/ {
            # Extract the value after "path"
            gsub(/.*"path"[[:space:]]*"/, "")
            gsub(/".*/, "")
            # Handle escaped backslashes (Windows paths, just in case)
            gsub(/\\\\/, "/")
            if (length($0) > 0) {
                print
            }
        }
    ' "$vdf_file"
}

# Get list of installed games from a library path
# Usage: games=$(get_games_in_library "/path/to/library")
get_games_in_library() {
    local library_path="${1:?Library path required}"
    local common_path="${library_path}/steamapps/common"
    
    if [[ ! -d "$common_path" ]]; then
        hk_debug "No common directory in library: ${library_path}"
        return 0
    fi
    
    # List directories in steamapps/common
    find "$common_path" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null | sort
}

# Get the full path to a game directory
# Usage: path=$(get_game_path "/library/path" "Game Name")
get_game_path() {
    local library_path="${1:?Library path required}"
    local game_name="${2:?Game name required}"
    echo "${library_path}/steamapps/common/${game_name}"
}

# -----------------------------------------------------------------------------
# State Management
# -----------------------------------------------------------------------------

# Load the current state (managed symlinks)
load_state() {
    local state_json
    state_json=$(hk_state_read "$SERVICE_NAME" "state.json")
    echo "$state_json"
}

# Save the current state
# Usage: echo '{"symlinks":{...}}' | save_state
save_state() {
    hk_state_write "$SERVICE_NAME" "state.json"
}

# Add a symlink to tracked state
# Usage: state=$(add_to_state "$state" "link_name" "target_path")
add_to_state() {
    local state="${1:?State required}"
    local link_name="${2:?Link name required}"
    local target_path="${3:?Target path required}"
    local timestamp
    timestamp=$(date -Iseconds)
    
    if hk_has_jq; then
        echo "$state" | jq --arg name "$link_name" \
                          --arg target "$target_path" \
                          --arg ts "$timestamp" \
                          '.symlinks[$name] = {"target": $target, "created": $ts}'
    else
        # Fallback: simple file-based tracking
        local state_dir
        state_dir=$(hk_state_dir "$SERVICE_NAME")
        echo "${target_path}" > "${state_dir}/link_${link_name//\//_}.target"
        echo "$state"
    fi
}

# Remove a symlink from tracked state
# Usage: state=$(remove_from_state "$state" "link_name")
remove_from_state() {
    local state="${1:?State required}"
    local link_name="${2:?Link name required}"
    
    if hk_has_jq; then
        echo "$state" | jq --arg name "$link_name" 'del(.symlinks[$name])'
    else
        local state_dir
        state_dir=$(hk_state_dir "$SERVICE_NAME")
        rm -f "${state_dir}/link_${link_name//\//_}.target"
        echo "$state"
    fi
}

# Get all tracked symlinks from state
# Usage: while read -r name target; do ...; done < <(get_tracked_symlinks "$state")
get_tracked_symlinks() {
    local state="${1:?State required}"
    
    if hk_has_jq; then
        echo "$state" | jq -r '.symlinks // {} | to_entries[] | "\(.key)\t\(.value.target)"' 2>/dev/null
    else
        # Fallback: read from individual files
        local state_dir
        state_dir=$(hk_state_dir "$SERVICE_NAME")
        for f in "${state_dir}"/link_*.target 2>/dev/null; do
            [[ -f "$f" ]] || continue
            local name
            name=$(basename "$f" .target)
            name="${name#link_}"
            name="${name//_/\/}"
            local target
            target=$(cat "$f")
            echo -e "${name}\t${target}"
        done
    fi
}

# Initialise empty state if needed
init_state() {
    if hk_has_jq; then
        echo '{"symlinks":{},"version":"1.0"}'
    else
        echo '{}'
    fi
}

# -----------------------------------------------------------------------------
# Core Logic
# -----------------------------------------------------------------------------

# Create symlinks for all games in all libraries
create_symlinks() {
    local target_dir="$STEAM_LINKER_TARGET_DIR"
    local vdf_file="$STEAM_LINKER_VDF_PATH"
    local state
    local created=0
    local skipped=0
    local errors=0
    
    # Load current state
    state=$(load_state)
    [[ "$state" == "{}" ]] && state=$(init_state)
    
    # Ensure target directory exists
    if [[ "$STEAM_LINKER_DRY_RUN" != "true" ]]; then
        mkdir -p "$target_dir"
    fi
    
    # Parse library folders
    hk_info "Reading Steam libraries from: ${vdf_file}"
    local libraries
    libraries=$(parse_library_folders "$vdf_file") || {
        hk_error "Failed to parse library folders"
        return 1
    }
    
    local library_count
    library_count=$(echo "$libraries" | grep -c . || echo 0)
    hk_info "Found ${library_count} Steam library location(s)"
    
    # Track which games we've seen (for duplicate detection)
    declare -A seen_games
    
    # Process each library
    while IFS= read -r library_path; do
        [[ -z "$library_path" ]] && continue
        
        hk_info "Processing library: ${library_path}"
        
        if [[ ! -d "$library_path" ]]; then
            hk_warn "Library path does not exist: ${library_path}"
            continue
        fi
        
        # Get games in this library
        local games
        games=$(get_games_in_library "$library_path")
        
        while IFS= read -r game_name; do
            [[ -z "$game_name" ]] && continue
            
            local game_path
            game_path=$(get_game_path "$library_path" "$game_name")
            local link_path="${target_dir}/${game_name}"
            
            # Check for duplicates
            if [[ -n "${seen_games[$game_name]:-}" ]]; then
                hk_warn "Duplicate game '${game_name}' found in multiple libraries. Keeping link to: ${seen_games[$game_name]}"
                ((skipped++))
                continue
            fi
            seen_games["$game_name"]="$game_path"
            
            # Check if symlink already exists and is correct
            if [[ -L "$link_path" ]]; then
                local current_target
                current_target=$(readlink -f "$link_path" 2>/dev/null || echo "")
                if [[ "$current_target" == "$game_path" ]]; then
                    hk_debug "Symlink already correct: ${game_name}"
                    ((skipped++))
                    continue
                fi
            fi
            
            # Create or update symlink
            if [[ "$STEAM_LINKER_DRY_RUN" == "true" ]]; then
                hk_info "[DRY-RUN] Would create: ${link_path} -> ${game_path}"
                ((created++))
            else
                if hk_create_symlink "$game_path" "$link_path" "$SERVICE_NAME"; then
                    hk_info "Created symlink: ${game_name}"
                    state=$(add_to_state "$state" "$game_name" "$game_path")
                    ((created++))
                else
                    ((errors++))
                fi
            fi
            
        done <<< "$games"
        
    done <<< "$libraries"
    
    # Save state
    if [[ "$STEAM_LINKER_DRY_RUN" != "true" ]]; then
        echo "$state" | save_state
    fi
    
    hk_info "Symlink creation complete: ${created} created, ${skipped} unchanged, ${errors} errors"
    return 0
}

# Remove broken symlinks from target directory
cleanup_broken_symlinks() {
    local target_dir="$STEAM_LINKER_TARGET_DIR"
    local removed=0
    local state
    
    if [[ ! -d "$target_dir" ]]; then
        hk_info "Target directory does not exist: ${target_dir}"
        return 0
    fi
    
    state=$(load_state)
    
    hk_info "Scanning for broken symlinks in: ${target_dir}"
    
    while IFS= read -r -d '' link_path; do
        if hk_is_broken_symlink "$link_path"; then
            local link_name
            link_name=$(basename "$link_path")
            
            if [[ "$STEAM_LINKER_DRY_RUN" == "true" ]]; then
                hk_info "[DRY-RUN] Would remove broken symlink: ${link_name}"
            else
                hk_info "Removing broken symlink: ${link_name}"
                rm -f "$link_path"
                state=$(remove_from_state "$state" "$link_name")
            fi
            ((removed++))
        fi
    done < <(find "$target_dir" -maxdepth 1 -type l -print0 2>/dev/null)
    
    # Save updated state
    if [[ "$STEAM_LINKER_DRY_RUN" != "true" ]] && (( removed > 0 )); then
        echo "$state" | save_state
    fi
    
    hk_info "Cleanup complete: ${removed} broken symlink(s) removed"
    return 0
}

# Restore symlinks from saved state (for recovery)
restore_from_state() {
    local target_dir="$STEAM_LINKER_TARGET_DIR"
    local state
    local restored=0
    
    state=$(load_state)
    
    if [[ "$state" == "{}" ]]; then
        hk_info "No saved state to restore from"
        return 0
    fi
    
    hk_info "Attempting to restore symlinks from saved state..."
    
    while IFS=$'\t' read -r link_name target_path; do
        [[ -z "$link_name" ]] && continue
        
        local link_path="${target_dir}/${link_name}"
        
        # Skip if symlink already exists
        if [[ -L "$link_path" ]]; then
            continue
        fi
        
        # Check if target still exists
        if [[ ! -d "$target_path" ]]; then
            hk_debug "Target no longer exists for '${link_name}': ${target_path}"
            continue
        fi
        
        # Restore symlink
        if [[ "$STEAM_LINKER_DRY_RUN" == "true" ]]; then
            hk_info "[DRY-RUN] Would restore: ${link_path} -> ${target_path}"
        else
            if hk_create_symlink "$target_path" "$link_path" "$SERVICE_NAME"; then
                hk_info "Restored symlink: ${link_name}"
                ((restored++))
            fi
        fi
        
    done < <(get_tracked_symlinks "$state")
    
    hk_info "Restoration complete: ${restored} symlink(s) restored"
    return 0
}

# Show current status
show_status() {
    local target_dir="$STEAM_LINKER_TARGET_DIR"
    local vdf_file="$STEAM_LINKER_VDF_PATH"
    
    echo "=== DistinctionOS Steam Linker Status ==="
    echo ""
    echo "Configuration:"
    echo "  Target directory: ${target_dir}"
    echo "  VDF file: ${vdf_file}"
    echo "  VDF exists: $([[ -f "$vdf_file" ]] && echo "yes" || echo "no")"
    echo ""
    
    # Count libraries
    if [[ -f "$vdf_file" ]]; then
        local library_count
        library_count=$(parse_library_folders "$vdf_file" | grep -c . || echo 0)
        echo "Steam Libraries: ${library_count}"
        parse_library_folders "$vdf_file" | while read -r lib; do
            local game_count
            game_count=$(get_games_in_library "$lib" | grep -c . || echo 0)
            echo "  - ${lib} (${game_count} games)"
        done
        echo ""
    fi
    
    # Count symlinks
    if [[ -d "$target_dir" ]]; then
        local total_links
        local broken_links
        total_links=$(find "$target_dir" -maxdepth 1 -type l | wc -l)
        broken_links=$(find "$target_dir" -maxdepth 1 -xtype l | wc -l)
        
        echo "Symlinks in ${target_dir}:"
        echo "  Total: ${total_links}"
        echo "  Broken: ${broken_links}"
        echo "  Valid: $((total_links - broken_links))"
    else
        echo "Target directory does not exist yet"
    fi
    
    echo ""
    echo "State file: $(hk_state_dir "$SERVICE_NAME")/state.json"
}

# -----------------------------------------------------------------------------
# CLI Interface
# -----------------------------------------------------------------------------

show_help() {
    cat << 'EOF'
DistinctionOS Steam Linker - Unified Game Library Access

USAGE:
    steam-linker.sh [OPTIONS]

OPTIONS:
    -v, --verbose    Enable verbose output
    -d, --debug      Enable debug output (implies --verbose)
    -n, --dry-run    Show what would be done without making changes
    -c, --cleanup    Only remove broken symlinks, don't create new ones
    -r, --restore    Restore accidentally deleted symlinks from saved state
    -s, --status     Show current status and exit
    -h, --help       Show this help message

EXAMPLES:
    # Normal operation (create symlinks, cleanup broken ones)
    steam-linker.sh

    # See what would happen without making changes
    steam-linker.sh --dry-run

    # Just clean up broken symlinks
    steam-linker.sh --cleanup

    # Restore symlinks that were accidentally deleted
    steam-linker.sh --restore

    # Check current status
    steam-linker.sh --status

CONFIGURATION:
    User config: ~/.config/distinctionos/steam-linker.conf

    Available options:
        STEAM_LINKER_TARGET_DIR - Where to create symlinks (default: ~/Games/Steamlibrary)
        STEAM_LINKER_VDF_PATH   - Path to libraryfolders.vdf

PART OF:
    DistinctionOS Housekeeper Architecture v1.0
EOF
}

main() {
    local action="full"  # full, cleanup, restore, status
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                export HOUSEKEEPER_VERBOSE="true"
                shift
                ;;
            -d|--debug)
                export HOUSEKEEPER_DEBUG="true"
                export HOUSEKEEPER_VERBOSE="true"
                shift
                ;;
            -n|--dry-run)
                STEAM_LINKER_DRY_RUN="true"
                export HOUSEKEEPER_VERBOSE="true"
                shift
                ;;
            -c|--cleanup)
                action="cleanup"
                shift
                ;;
            -r|--restore)
                action="restore"
                shift
                ;;
            -s|--status)
                action="status"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
    
    # Status doesn't need logging/locking
    if [[ "$action" == "status" ]]; then
        hk_load_config "$SERVICE_NAME"
        show_status
        exit 0
    fi
    
    # Initialise logging
    hk_init_logging "$SERVICE_NAME"
    
    # Load configuration
    hk_load_config "$SERVICE_NAME"
    
    # Acquire lock to prevent concurrent runs
    hk_lock "$SERVICE_NAME" || hk_exit 1 "Could not acquire lock"
    
    # Validate Steam installation
    if [[ ! -f "$STEAM_LINKER_VDF_PATH" ]]; then
        hk_error "Steam library configuration not found at: ${STEAM_LINKER_VDF_PATH}"
        hk_error "Please ensure Steam is installed and has been run at least once"
        hk_exit 1
    fi
    
    # Execute requested action
    case "$action" in
        full)
            cleanup_broken_symlinks
            create_symlinks
            restore_from_state
            ;;
        cleanup)
            cleanup_broken_symlinks
            ;;
        restore)
            restore_from_state
            ;;
    esac
    
    hk_exit 0 "Operation completed successfully"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
