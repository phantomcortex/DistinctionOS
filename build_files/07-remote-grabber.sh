#!/bin/bash

# =============================================================================
# GNOME Shell Extensions — Intelligent Installer
# =============================================================================

source /ctx/95-utility-functions.sh
set -euo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly EXTENSIONS_DIR="/usr/share/gnome-shell/extensions"
readonly TMP_DIR="/tmp/gnome-shell-extensions"
readonly LOG_FILE="${TMP_DIR}/installation.log"

# =============================================================================
# Extension Registry
#
# Format: "method | uuid | url [| extra_args]"
#
# Methods:
#   git   — clone directly; extension.js must be at the repo root, no build step
#   zip   — download archive and extract
#   make  — clone, run "make install DESTDIR=/ PREFIX=/usr";
#           extra_args replaces the default make variables if supplied
#   pack  — clone, run gnome-extensions pack, extract the result zip;
#           extra_args are passed verbatim to gnome-extensions pack
#           (omit to let the installer auto-detect sources from repo layout)
#   auto  — clone, detect build system, then proceed:
#             Makefile      → make (DESTDIR=/ PREFIX=/usr)
#             meson.build   → meson (--prefix=/usr)
#             extension.js at root → direct copy
#             otherwise     → gnome-extensions pack (auto-detected sources)
# =============================================================================
EXTENSIONS=(
    # ── Git (flat repos — extension.js lives at repo root) ──────────────────
    "git  | pip-on-top@rafostar.github.com                  | https://github.com/Rafostar/gnome-shell-extension-pip-on-top.git"
    "git  | clipboard-indicator@tudmotu.com                  | https://github.com/Tudmotu/gnome-shell-extension-clipboard-indicator.git"
    "git  | date-menu-formatter@marcinjakubowski.github.com  | https://github.com/marcinjakubowski/date-menu-formatter.git"
    "git  | quick-settings-avatar@d-go                      | https://github.com/d-go/quick-settings-avatar.git"


    # ── ZIP (pre-built release archives) ────────────────────────────────────
    "zip  | burn-my-windows@schneegans.github.com           | https://github.com/Schneegans/Burn-My-Windows/releases/download/v47/burn-my-windows@schneegans.github.com.zip"
    "zip  | gnome-ui-tune@itstime.tech                      | https://github.com/axxapy/gnome-ui-tune/releases/download/v1.11.0/gnome-ui-tune@itstime.tech.shell-extension.zip"
    "zip  | tophat@fflewddur.github.io                      | https://github.com/fflewddur/tophat/releases/download/v23/tophat@fflewddur.github.io.v23.shell-extension.zip"
    "zip  | copyous@boerdereinar.dev                        | https://github.com/boerdereinar/copyous/releases/download/v2.0.1/copyous@boerdereinar.dev.zip"

    # ── Makefile (default: DESTDIR=/ PREFIX=/usr) ───────────────────────────
    "make | dash-to-dock@phantomcortex                      | https://github.com/phantomcortex/dash-to-dock.git"

    # ── gnome-extensions pack (sources auto-detected from repo layout) ───────
    # "pack | blur-my-shell@aunetx                          | https://github.com/phantomcortex/blur-my-shell.git"
    
    "auto  | azwallpaper@azwallpaper.gitlab.com             | https://gitlab.com/AndrewZaech/azwallpaper.git"
)

readonly EXTENSIONS_TO_REMOVE=(
    "hotedge@jonathan.jdoda.ca"
)

# =============================================================================
# Shared Helpers
# =============================================================================

trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

clone_to_tmp() {
    local url="$1"
    local dest="$2"
    [[ -d "$dest" ]] && rm -rf "$dest"
    git clone --quiet --depth 1 "$url" "$dest"
}

# Compile schemas if a schemas/ dir with XML files exists
auto_compile_schemas() {
    local uuid="$1"
    local ext_dir="$2"
    local schema_dir="$ext_dir/schemas"

    compgen -G "$schema_dir/*.gschema.xml" > /dev/null 2>&1 || return 0

    log_info "Compiling schemas for: $uuid"
    if glib-compile-schemas "$schema_dir" 2>>"$LOG_FILE"; then
        log_success "Schemas compiled for: $uuid"
    else
        log_warning "Schema compilation failed for: $uuid"
    fi
}

# Return the directory that contains extension.js (the pack source dir)
find_ext_source_dir() {
    local repo_dir="$1"
    local ext_js
    ext_js=$(find "$repo_dir" -maxdepth 3 -name "extension.js" | head -1)
    if [[ -n "$ext_js" ]]; then
        dirname "$ext_js"
    else
        echo "$repo_dir"
    fi
}

# Emit gnome-extensions pack flags inferred from the repo layout.
# Each flag is printed on its own line so the caller can use mapfile.
auto_detect_pack_args() {
    local repo_dir="$1"
    local source_dir="$2"

    # Files/dirs at the repo root that live outside the source dir need --extra-source
    if [[ "$source_dir" != "$repo_dir" ]]; then
        [[ -f "$repo_dir/metadata.json" ]] && echo "--extra-source=$repo_dir/metadata.json"
        [[ -f "$repo_dir/LICENSE" ]]        && echo "--extra-source=$repo_dir/LICENSE"
        for dir in resources icons data res; do
            [[ -d "$repo_dir/$dir" ]] && echo "--extra-source=$repo_dir/$dir"
        done
    fi

    [[ -d "$repo_dir/po" ]] && echo "--podir=$repo_dir/po"

    local schema_xml
    schema_xml=$(find "$repo_dir" -name "*.gschema.xml" | head -1)
    [[ -n "$schema_xml" ]] && echo "--schema=$schema_xml"
}

# =============================================================================
# Internal Build Steps (shared between explicit methods and auto-detection)
# =============================================================================

_do_make_install() {
    local uuid="$1"
    local repo_dir="$2"
    local make_args="${3:-DESTDIR=/ PREFIX=/usr}"

    # shellcheck disable=SC2086
    if ! make -C "$repo_dir" install $make_args; then
        log_error "make install failed for $uuid"
        return 1
    fi

    auto_compile_schemas "$uuid" "$EXTENSIONS_DIR/$uuid"
    # Schemas installed to the system dir also need a recompile
    glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>>"$LOG_FILE" || true
}

_do_pack_install() {
    local uuid="$1"
    local repo_dir="$2"
    local extra_args="${3:-}"
    local build_dir="$TMP_DIR/${uuid}-build"
    local target_dir="$EXTENSIONS_DIR/$uuid"

    mkdir -p "$build_dir"

    local source_dir
    source_dir=$(find_ext_source_dir "$repo_dir")

    local -a pack_args
    if [[ -n "$extra_args" ]]; then
        read -ra pack_args <<< "$extra_args"
    else
        mapfile -t pack_args < <(auto_detect_pack_args "$repo_dir" "$source_dir")
    fi

    if ! gnome-extensions pack -f "${pack_args[@]}" -o "$build_dir" "$source_dir"; then
        log_error "gnome-extensions pack failed for $uuid"
        return 1
    fi

    local zip_file
    zip_file=$(find "$build_dir" -name "*.zip" | head -1)
    if [[ -z "$zip_file" ]]; then
        log_error "No zip produced by gnome-extensions pack for $uuid"
        return 1
    fi

    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    if ! unzip -o "$zip_file" -d "$target_dir"; then
        log_error "Failed to extract pack zip for $uuid"
        return 1
    fi

    auto_compile_schemas "$uuid" "$target_dir"
}

# =============================================================================
# Install Methods
# =============================================================================

install_git_extension() {
    local uuid="$1"
    local url="$2"
    local target_dir="$EXTENSIONS_DIR/$uuid"

    log_info "Installing [git] $uuid"

    [[ -d "$target_dir" ]] && rm -rf "$target_dir"
    if git clone --quiet --depth 1 "$url" "$target_dir"; then
        auto_compile_schemas "$uuid" "$target_dir"
        log_success "Installed: $uuid"
    else
        log_error "Failed to clone: $uuid"
        return 1
    fi
}

install_zip_extension() {
    local uuid="$1"
    local url="$2"
    local zip_path="$TMP_DIR/${uuid}.zip"
    local target_dir="$EXTENSIONS_DIR/$uuid"

    log_info "Installing [zip] $uuid"

    if ! curl -L --silent --fail "$url" -o "$zip_path"; then
        log_error "Failed to download: $uuid"
        return 1
    fi

    [[ -d "$target_dir" ]] && rm -rf "$target_dir"
    mkdir -p "$target_dir"

    if unzip -qq -o "$zip_path" -d "$target_dir"; then
        rm -f "$zip_path"
        auto_compile_schemas "$uuid" "$target_dir"
        log_success "Installed: $uuid"
    else
        log_error "Failed to extract: $uuid"
        return 1
    fi
}

install_make_extension() {
    local uuid="$1"
    local url="$2"
    local extra_args="${3:-}"
    local name="${url##*/}"; name="${name%.git}"
    local repo_dir="$TMP_DIR/$name"

    log_info "Installing [make] $uuid"

    clone_to_tmp "$url" "$repo_dir" || { log_error "Failed to clone: $uuid"; return 1; }
    _do_make_install "$uuid" "$repo_dir" "$extra_args" || return 1
    log_success "Installed: $uuid"
}

install_pack_extension() {
    local uuid="$1"
    local url="$2"
    local extra_args="${3:-}"
    local name="${url##*/}"; name="${name%.git}"
    local repo_dir="$TMP_DIR/$name"

    log_info "Installing [pack] $uuid"

    clone_to_tmp "$url" "$repo_dir" || { log_error "Failed to clone: $uuid"; return 1; }
    _do_pack_install "$uuid" "$repo_dir" "$extra_args" || return 1
    log_success "Installed: $uuid"
}

install_auto_extension() {
    local uuid="$1"
    local url="$2"
    local extra_args="${3:-}"
    local name="${url##*/}"; name="${name%.git}"
    local repo_dir="$TMP_DIR/$name"

    log_info "Installing [auto] $uuid"

    clone_to_tmp "$url" "$repo_dir" || { log_error "Failed to clone: $uuid"; return 1; }

    local method
    if   [[ -f "$repo_dir/Makefile"    ]]; then method="make"
    elif [[ -f "$repo_dir/meson.build" ]]; then method="meson"
    elif [[ -f "$repo_dir/extension.js" ]]; then method="direct"
    else                                         method="pack"
    fi

    log_info "Auto-detected build method for $uuid: $method"

    case "$method" in
        make)
            _do_make_install "$uuid" "$repo_dir" "$extra_args" || return 1
            ;;
        meson)
            local build_dir="$TMP_DIR/${uuid}-meson-build"
            meson setup --prefix=/usr "$build_dir" "$repo_dir" \
                && meson install -C "$build_dir" \
                || { log_error "meson install failed for $uuid"; return 1; }
            auto_compile_schemas "$uuid" "$EXTENSIONS_DIR/$uuid"
            ;;
        direct)
            local target_dir="$EXTENSIONS_DIR/$uuid"
            rm -rf "$target_dir"
            cp -r "$repo_dir" "$target_dir"
            auto_compile_schemas "$uuid" "$target_dir"
            ;;
        pack)
            _do_pack_install "$uuid" "$repo_dir" "$extra_args" || return 1
            ;;
    esac

    log_success "Installed: $uuid"
}

# =============================================================================
# Dispatcher
# =============================================================================

install_extension() {
    local entry="$1"
    local method uuid url extra_args

    IFS='|' read -r method uuid url extra_args <<< "$entry"
    method=$(trim "$method")
    uuid=$(trim "$uuid")
    url=$(trim "$url")
    extra_args=$(trim "${extra_args:-}")

    case "$method" in
        git)  install_git_extension  "$uuid" "$url" ;;
        zip)  install_zip_extension  "$uuid" "$url" ;;
        make) install_make_extension "$uuid" "$url" "$extra_args" ;;
        pack) install_pack_extension "$uuid" "$url" "$extra_args" ;;
        auto) install_auto_extension "$uuid" "$url" "$extra_args" ;;
        *)    log_error "Unknown method '$method' for $uuid"; return 1 ;;
    esac
}

# =============================================================================
# Orchestration
# =============================================================================

setup_environment() {
    mkdir -p "$TMP_DIR" "$EXTENSIONS_DIR"
}

remove_listed_extensions() {
    log_info "Removing deprecated extensions..."
    local ext_dir
    for uuid in "${EXTENSIONS_TO_REMOVE[@]}"; do
        ext_dir="$EXTENSIONS_DIR/$uuid"
        if [[ -d "$ext_dir" ]]; then
            rm -rf "$ext_dir"
            log_success "Removed: $uuid"
        else
            log_info "Not present (skip): $uuid"
        fi
    done
}

install_all_extensions() {
    local total=${#EXTENSIONS[@]}
    local ok=0 fail=0

    log_info "Installing $total extensions..."

    for entry in "${EXTENSIONS[@]}"; do
        if install_extension "$entry"; then
            ok=$((ok + 1))
        else
            fail=$((fail + 1))
        fi
    done

    log_success "Successful: $ok"
    if [[ $fail -gt 0 ]]; then
        log_error "Failed: $fail — review $LOG_FILE"
        return 1
    fi
}

remove_git_directories() {
    log_info "Removing git metadata from extensions..."
    local count=0
    for artifact in .git .github .gitignore; do
        for item in "$EXTENSIONS_DIR"/*/"$artifact"; do
            [[ -e "$item" ]] || continue
            rm -rf "$item"
            count=$((count + 1))
        done
    done
    log_success "Removed $count git metadata entries"
}

patch_extension_compatibility() {
    local shell_version
    shell_version=$(rpm -q --queryformat '%{VERSION}' gnome-shell 2>/dev/null | grep -oP '^\d+')

    if [[ -z "$shell_version" ]]; then
        log_warning "Could not determine GNOME Shell version — skipping compatibility patching"
        return 0
    fi

    log_info "Patching extensions for GNOME Shell $shell_version (and next 2 releases)..."

    local patched=0 already_ok=0
    local versions_to_add=("$shell_version" "$((shell_version + 1))" "$((shell_version + 2))")

    for metadata_file in "$EXTENSIONS_DIR"/*/metadata.json; do
        [[ -f "$metadata_file" ]] || continue
        local ext_id
        ext_id=$(basename "$(dirname "$metadata_file")")

        python3 - "$metadata_file" "${versions_to_add[@]}" <<'PYEOF'
import sys, json

path = sys.argv[1]
to_add = sys.argv[2:]

with open(path) as f:
    meta = json.load(f)

current = set(meta.get('shell-version', []))
missing = [v for v in to_add if v not in current]

if not missing:
    sys.exit(2)

meta['shell-version'] = sorted(
    current | set(to_add),
    key=lambda v: [int(x) for x in v.split('.')]
)

with open(path, 'w') as f:
    json.dump(meta, f, indent=4)
PYEOF
        local rc=$?
        if   [[ $rc -eq 0 ]]; then patched=$((patched + 1))
        elif [[ $rc -eq 2 ]]; then already_ok=$((already_ok + 1))
        else log_warning "Failed to patch metadata for: $ext_id"
        fi
    done

    log_success "Compatibility patching done: $patched patched, $already_ok already supported"
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

    local had_errors=0

    remove_listed_extensions
    install_all_extensions || had_errors=1
    remove_git_directories
    patch_extension_compatibility
<<<<<<< HEAD
    install_gnome_rounded_blur || had_errors=1
    
    
=======

    # gnome-rounded-blur and its build-time mutter-devel dep now ship via
    # the force-install OCI artifact, installed by 06-force-install.sh
    # before this script runs.
>>>>>>> 650a2f0 (migrate gnome-rounded-blur to force-install artifact)

    if [[ $had_errors -ne 0 ]]; then
        log_error "One or more extensions failed to install — review log above"
        exit 1
    fi

    log_success "All extensions installed successfully!"
    exit 0
}

main "$@"
