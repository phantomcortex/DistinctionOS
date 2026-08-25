#!/usr/bin/bash
# Post-install validation: catches the "install succeeded but env is broken"
# class of bug — the previous icon-as-blank-squares issue would have been
# caught here. Hard-fails by default; set VALIDATION_SOFT=1 to downgrade
# failures to warnings.
set -uo pipefail

source /ctx/95-utility-functions.sh

readonly VALIDATION_SOFT="${VALIDATION_SOFT:-1}"

script_start "Install-Time Validation" "Sanity checks on the final image environment"

declare -i HARD_FAILURES=0
declare -a HARD_FAILURE_NOTES=()

fail() {
    log_error "$1"
    HARD_FAILURE_NOTES+=("$1")
    HARD_FAILURES=$((HARD_FAILURES + 1))
}

# ── ldconfig cache integrity ────────────────────────────────────────────────
# The Containerfile mounts /var/cache as a BuildKit cache, so
# /var/cache/ldconfig/aux-cache persists across container builds. A stale
# aux-cache lets ldconfig skip stat()'ing libraries it thinks haven't changed,
# producing /etc/ld.so.cache entries that don't reflect the current /usr/lib64.
# Wipe both caches and rebuild from scratch so the queries below are accurate.
log_section "ldconfig cache integrity"

rm -f /etc/ld.so.cache /var/cache/ldconfig/aux-cache

# ── Icon theme caches ───────────────────────────────────────────────────────
# Blank-icon bugs almost always come from a missing or malformed icon-theme.cache.
log_section "Icon theme caches"

readonly -a ICON_THEMES=(
    /usr/share/icons/Adwaita
    /usr/share/icons/hicolor
)
for theme_dir in "${ICON_THEMES[@]}"; do
    if [[ ! -d "$theme_dir" ]]; then
        fail "Icon theme directory missing: $theme_dir"
        continue
    fi

    if gtk-update-icon-cache -f "$theme_dir" &>/dev/null; then
        cache_file="$theme_dir/icon-theme.cache"
        if [[ -s "$cache_file" ]]; then
            cache_size=$(numfmt --to=iec "$(stat -c%s "$cache_file")")
            log_success "  ✓ $theme_dir ($cache_size)"
        else
            fail "$theme_dir: icon-theme.cache empty after generation"
        fi
    else
        fail "$theme_dir: gtk-update-icon-cache failed"
    fi
done


# ── Critical binary link integrity ──────────────────────────────────────────
# Catches the case where a package is installed but a runtime dep was removed,
# leaving a binary that can't actually launch.
log_section "Binary link integrity"

readonly -a CRITICAL_BINS=(
    gnome-shell
    mutter
    gnome-session
    gdm
    Xwayland
)
for bin in "${CRITICAL_BINS[@]}"; do
    bin_path=$(command -v "$bin" 2>/dev/null || true)
    if [[ -z "$bin_path" ]]; then
        log_warning "  - $bin not installed (skipping)"
        continue
    fi

    missing=$(ldd "$bin_path" 2>&1 | grep "not found" || true)
    if [[ -n "$missing" ]]; then
        fail "$bin has unresolved libraries:"
        echo "$missing" | head -3 | while read -r line; do
            echo "      $line"
        done
    else
        log_success "  ✓ $bin"
    fi
done

log_section "List important packages"
sleep 2 

PKG_CHECKLIST=( \
  "glycin-libs" \
  "glycin-loaders" \
  "glycin-thumbnailer"\
  "gstreamer-plugin-xwm" \
  "crossover" \
  "ffmpeg" \
  "bsa-ba2-tool" \
  "file-roller" )

rpm -q 
for pkg in "${PKG_CHECKLIST[@]}"; do 
  if rpm -qa "*$pkg*" > /dev/null 2>&1; then 
    log_success "$pkg is installed! VERSION: $(rpm -q "$pkg")"
  else 
    log_warning "$pkg is not installed"
  fi 
done 


# ── Codec stack integrity ───────────────────────────────────────────────────

log_section "Codec stack integrity"

# ─ Layer 1: dynamic linker can resolve every soname ─
codec_link_failed=0
readonly -a CODEC_BINS=(/usr/bin/ffmpeg /usr/bin/ffprobe)
for codec_bin in "${CODEC_BINS[@]}"; do
    if [[ ! -x "$codec_bin" ]]; then
        log_warning "  - $codec_bin not installed (skipping)"
        continue
    fi
    missing=$(ldd "$codec_bin" 2>&1 | grep "not found" || true)
    if [[ -n "$missing" ]]; then
        fail "$codec_bin has unresolved libraries:"
        echo "$missing" | head -5 | while read -r line; do
            echo "      $line"
        done
        codec_link_failed=1
    else
        log_success "  ✓ $(basename "$codec_bin") sonames resolve"
    fi
done

# libav*.so* may live in /usr/lib64 or /usr/lib64/ffmpeg depending on packaging
mapfile -t libav_so < <(
    find /usr/lib64 -maxdepth 3 -type f \
        -regex '.*/lib\(avcodec\|avformat\|avfilter\|avdevice\|avutil\|postproc\|swresample\|swscale\)\.so\.[0-9]+' \
        2>/dev/null
)
libav_failed=0
for so in "${libav_so[@]}"; do
    missing=$(ldd "$so" 2>&1 | grep "not found" || true)
    if [[ -n "$missing" ]]; then
        fail "$so has unresolved sonames:"
        echo "$missing" | head -3 | while read -r line; do
            echo "      $line"
        done
        codec_link_failed=1
        libav_failed=1
    fi
done
if [[ ${#libav_so[@]} -gt 0 && $libav_failed -eq 0 ]]; then
    log_success "  ✓ ${#libav_so[@]} libav* dylib(s) link cleanly"
fi

# ─ Layer 2: ffmpeg actually runs and resolves versioned symbols ─
# Skip if Layer 1 already failed — the error message will be misleading
# and the real cause is upstream.
if [[ $codec_link_failed -eq 0 && -x /usr/bin/ffmpeg ]]; then
    if ffmpeg_out=$(/usr/bin/ffmpeg -hide_banner -encoders 2>&1) \
       && ! grep -qiE 'symbol lookup error|undefined symbol' <<<"$ffmpeg_out"; then

        # Tier 1 (hard requirement): baseline software encoders.
        readonly -a TIER1_ENCODERS=(libx264 libx265)
        # Tier 2 (soft requirement): newer codecs that may lag in some ffmpeg builds.
        readonly -a TIER2_ENCODERS=(libsvtav1 libvvenc)
        # Tier 3 (hard requirement): AMD/Intel VAAPI HW path — load-bearing for
        # the user's "feature complete with proper GPU encode/decode" goal.
        readonly -a TIER3_ENCODERS=(h264_vaapi hevc_vaapi av1_vaapi)

        for enc in "${TIER1_ENCODERS[@]}"; do
            if grep -qE "^ [VAS][.A-Z]{5} ${enc}( |$)" <<<"$ffmpeg_out"; then
                log_success "  ✓ encoder: $enc"
            else
                fail "encoder missing (Tier 1, hard): $enc"
            fi
        done
        for enc in "${TIER2_ENCODERS[@]}"; do
            if grep -qE "^ [VAS][.A-Z]{5} ${enc}( |$)" <<<"$ffmpeg_out"; then
                log_success "  ✓ encoder: $enc"
            else
                log_warning "  ? encoder missing (Tier 2, soft): $enc"
            fi
        done
        for enc in "${TIER3_ENCODERS[@]}"; do
            if grep -qE "^ [VAS][.A-Z]{5} ${enc}( |$)" <<<"$ffmpeg_out"; then
                log_success "  ✓ encoder: $enc"
            else
                fail "encoder missing (Tier 3, hard — AMD GPU encode): $enc"
            fi
        done
    else
        fail "ffmpeg failed to enumerate encoders (symbol-resolution failure):"
        echo "$ffmpeg_out" | head -5 | while read -r line; do
            echo "      $line"
        done
    fi
fi

# ─ Layer 3: GStreamer sees the freeworld plugins ─
if command -v gst-inspect-1.0 &>/dev/null; then
    if gst-inspect-1.0 va &>/dev/null; then
        log_success "  ✓ GStreamer 'va' plugin present (VAAPI HW codec path)"
    else
        fail "GStreamer 'va' plugin missing — VAAPI HW decode/encode unavailable"
    fi
fi

# ── Final report ────────────────────────────────────────────────────────────
log_section "Validation summary"

if [[ $HARD_FAILURES -eq 0 ]]; then
    script_complete "Install-Time Validation" "All sanity checks passed"
    exit 0
fi

log_error "$HARD_FAILURES validation failure(s):"
for note in "${HARD_FAILURE_NOTES[@]}"; do
    echo "  - $note"
done

if [[ "$VALIDATION_SOFT" == "1" ]]; then
    log_warning "VALIDATION_SOFT=1 set — failing soft, build continues"
    exit 0
fi

log_error "Failing build. Set VALIDATION_SOFT=1 in the build env to bypass."
exit 1
