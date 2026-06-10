#!/usr/bin/bash

# ============================================================================
# DistinctionOS Build Utility Functions Library
# ============================================================================
# Purpose: Shared functions and constants for all build scripts
# Usage: source /ctx/utility-functions.sh
# Version: 1.0
# Created: 2025-10-27
# ============================================================================

# Prevent multiple sourcing
[[ -n "${DISTINCTION_UTILS_LOADED:-}" ]] && return 0
readonly DISTINCTION_UTILS_LOADED=1

# ============================================================================
# ANSI Color Codes
# ============================================================================

readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[31m'
readonly COLOR_GREEN='\033[32m'
readonly COLOR_YELLOW='\033[33m'
readonly COLOR_BLUE='\033[34m'
readonly COLOR_MAGENTA='\033[35m'
readonly COLOR_CYAN='\033[36m'
readonly COLOR_ORANGE='\033[38;5;208m'

# ============================================================================
# Logging Functions
# ============================================================================

# Major section headers with box-drawing characters
log_header() {
  echo -e "${COLOR_BLUE}╔════════════════════════════════════════════════════════════════════╗${COLOR_RESET}"
  echo -e "${COLOR_BLUE}║${COLOR_RESET} $* "
  echo -e "${COLOR_BLUE}╚════════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
}

# Subsection headers with arrow indicator
log_section() {
  echo -e "\n${COLOR_CYAN}▶ $*${COLOR_RESET}"
}

# Success messages with checkmark
log_success() {
  echo -e "${COLOR_GREEN}✓ $*${COLOR_RESET}"
}

# Warning messages for non-critical issues
log_warning() {
  echo -e "${COLOR_YELLOW}⚠ $*${COLOR_RESET}"
}

# Error messages sent to stderr
log_error() {
  echo -e "${COLOR_RED}✗ $*${COLOR_RESET}" >&2
}

# Informational messages
log_info() {
  echo -e "${COLOR_MAGENTA}ℹ $*${COLOR_RESET}"
}

# ============================================================================
# Debug & Tracing Functions
# ============================================================================

# Enable command tracing for debugging (excludes echo and log commands)
enable_debug_trace() {
  trap '[[ $BASH_COMMAND != echo* ]] && [[ $BASH_COMMAND != log* ]] && echo "+ $BASH_COMMAND"' DEBUG
}

# Disable command tracing
disable_debug_trace() {
  trap - DEBUG
}

# ============================================================================
# Package Validation Functions
# ============================================================================

# Validate that a single package is installed
# Usage: validate_package_installed "package-name"
# Returns: 0 if installed, 1 if not
validate_package_installed() {
  local package="$1"
  
  if rpm -q "$package" &>/dev/null; then
    log_success "$package installed successfully"
    return 0
  else
    log_warning "$package installation could not be verified"
    return 1
  fi
}

# Validate that all critical packages are installed
# Usage: validate_critical_packages "pkg1" "pkg2" "pkg3"
# Returns: 0 if all installed, 1 if any missing
validate_critical_packages() {
  local -a critical_packages=("$@")
  local failed=0
  
  log_info "Validating ${#critical_packages[@]} critical package(s)"
  
  for pkg in "${critical_packages[@]}"; do
    if ! rpm -q "$pkg" &>/dev/null; then
      log_error "Critical package missing: $pkg"
      ((failed++))
    fi
  done
  
  if [[ $failed -gt 0 ]]; then
    log_error "$failed critical package(s) failed to install"
    return 1
  fi
  
  log_success "All critical packages validated"
  return 0
}

# ============================================================================
# File & Directory Management Functions
# ============================================================================

# Check if file exists and log appropriately
# Usage: check_file_exists "/path/to/file" "descriptive name"
# Returns: 0 if exists, 1 if not
check_file_exists() {
  local file_path="$1"
  local description="${2:-file}"
  
  if [[ -f "$file_path" ]]; then
    log_success "$description found: $file_path"
    return 0
  else
    log_warning "$description not found: $file_path"
    return 1
  fi
}

# Check if directory exists and log appropriately
# Usage: check_dir_exists "/path/to/dir" "descriptive name"
# Returns: 0 if exists, 1 if not
check_dir_exists() {
  local dir_path="$1"
  local description="${2:-directory}"
  
  if [[ -d "$dir_path" ]]; then
    log_success "$description found: $dir_path"
    return 0
  else
    log_warning "$description not found: $dir_path"
    return 1
  fi
}

# Create directory with logging
# Usage: create_dir_with_log "/path/to/dir" "descriptive name"
# Returns: 0 on success, 1 on failure
create_dir_with_log() {
  local dir_path="$1"
  local description="${2:-directory}"
  
  if [[ -d "$dir_path" ]]; then
    log_info "$description already exists: $dir_path"
    return 0
  fi
  
  if mkdir -p "$dir_path"; then
    log_success "$description created: $dir_path"
    return 0
  else
    log_error "Failed to create $description: $dir_path"
    return 1
  fi
}

# Remove file with logging and counting
# Usage: remove_file_with_log "/path/to/file" "descriptive name"
# Returns: 0 if removed or didn't exist, 1 on failure
remove_file_with_log() {
  local file_path="$1"
  local description="${2:-file}"
  
  if [[ ! -e "$file_path" ]]; then
    log_info "$description not present: $file_path"
    return 0
  fi
  
  if rm -f "$file_path"; then
    log_success "$description removed: $file_path"
    return 0
  else
    log_error "Failed to remove $description: $file_path"
    return 1
  fi
}

# ============================================================================
# Command Execution Wrappers
# ============================================================================

# Execute command with success/failure logging
# Usage: run_with_log "descriptive message" command arg1 arg2...
# Returns: command exit code
run_with_log() {
  local description="$1"
  shift
  
  log_info "$description"
  
  if "$@"; then
    log_success "$description - completed"
    return 0
  else
    local exit_code=$?
    log_error "$description - failed (exit code: $exit_code)"
    return $exit_code
  fi
}

# Execute command silently with only success/failure logging
# Usage: run_silent_with_log "descriptive message" command arg1 arg2...
# Returns: command exit code
run_silent_with_log() {
  local description="$1"
  shift
  
  if "$@" &>/dev/null; then
    log_success "$description"
    return 0
  else
    local exit_code=$?
    log_warning "$description - failed (exit code: $exit_code)"
    return $exit_code
  fi
}

# ============================================================================
# Counter Functions
# ============================================================================

# Display counter result with appropriate singular/plural
# Usage: counter_display "$count" "item" "items" "action"
# Example: counter_display "$removed" "file" "files" "removed"
counter_display() {
  local count="$1"
  local singular="$2"
  local plural="$3"
  local action="${4:-processed}"
  
  if [[ $count -eq 0 ]]; then
    log_info "No ${plural} ${action}"
  elif [[ $count -eq 1 ]]; then
    log_success "${count} ${singular} ${action}"
  else
    log_success "${count} ${plural} ${action}"
  fi
}

# ============================================================================
# System Information Functions
# ============================================================================

# Get the current Bazzite kernel version
# Usage: kernel_version=$(get_bazzite_kernel)
# Returns: kernel version string or empty if not found
get_bazzite_kernel() {
  local kernel
  kernel=$(ls /lib/modules/ | grep bazzite | sort -V | tail -1)
  
  if [[ -n "$kernel" ]]; then
    echo "$kernel"
    return 0
  else
    return 1
  fi
}

# Get precise kernel version for DNF queries
# Usage: kernel_ver=$(get_kernel_version)
# Returns: kernel version in format suitable for dracut
get_kernel_version() {
  dnf5 repoquery --installed --queryformat='%{evr}.%{arch}' kernel 2>/dev/null | head -1
}

# ============================================================================
# Guard: disallow `--allowerasing`
# ============================================================================
# --allowerasing lets dnf silently remove packages to satisfy an install, which
# can clobber required packages. Wrap dnf/dnf5 so any future use is rejected.
dnf() {
  local arg
  for arg in "$@"; do
    if [[ "$arg" == "--allowerasing" ]]; then
      log_error "Refusing to run dnf with --allowerasing (disallowed in this build)"
      return 1
    fi
  done
  command dnf "$@"
}

dnf5() {
  local arg
  for arg in "$@"; do
    if [[ "$arg" == "--allowerasing" ]]; then
      log_error "Refusing to run dnf5 with --allowerasing (disallowed in this build)"
      return 1
    fi
  done
  command dnf5 "$@"
}
# ============================================================================
# Script Lifecycle Functions
# ============================================================================

# Print script start header
# Usage: script_start "Script Name" "Brief description"
script_start() {
  local script_name="$1"
  local description="${2:-}"
  
  log_header "$script_name"
  [[ -n "$description" ]] && echo "  $description"
}

# Print script completion header with next steps
# Usage: script_complete "Script Name" "next step description"
script_complete() {
  local script_name="$1"
  local next_step="${2:-}"
  
  log_header "$script_name - Complete"
  
  if [[ -n "$next_step" ]]; then
    log_info "Next step:"
    echo "  $next_step"
  fi
}

# ============================================================================
# Utility Functions
# ============================================================================

# Check if running as root
# Usage: require_root
# Exits if not root
require_root() {
  if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
  fi
}

# Print a simple divider line
divider() {
  echo "────────────────────────────────────────────────────────────────────"
}

# Print library load confirmation (for debugging)
confirm_library_loaded() {
  log_success "DistinctionOS utility functions library loaded"
}

# ============================================================================
# Library Initialization Complete
# ============================================================================

# Uncomment for debugging library load:
# confirm_library_loaded
