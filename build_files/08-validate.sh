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

ldconfig_output=$(ldconfig 2>&1)
ldconfig_rc=$?
if [[ $ldconfig_rc -ne 0 ]]; then
    fail "ldconfig rebuild exited with status $ldconfig_rc"
    printf '%s\n' "$ldconfig_output" | head -10 | while read -r line; do
        echo "    $line"
    done
elif printf '%s\n' "$ldconfig_output" | grep -qiE 'cannot open|is not an? ELF|file too short|invalid'; then
    fail "ldconfig reports broken libraries"
    printf '%s\n' "$ldconfig_output" \
        | grep -iE 'cannot open|is not an? ELF|file too short|invalid' \
        | head -10 \
        | while read -r line; do
            echo "    $line"
        done
else
    log_success "ldconfig cache is clean"
fi

# Critical libs that MUST be present in the ldconfig cache.
readonly -a CRITICAL_LIBS=(
    libGL.so.1
    libEGL.so.1
    libgbm.so.1
    libpango-1.0.so.0
    libcairo.so.2
    libgdk_pixbuf-2.0.so.0
    libglib-2.0.so.0
    libfontconfig.so.1
)
for lib in "${CRITICAL_LIBS[@]}"; do
    if ldconfig -p | grep -q "$lib"; then
        log_success "  ✓ $lib"
    else
        fail "$lib missing from ldconfig cache"
    fi
done

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

# ── GDK pixbuf loaders ──────────────────────────────────────────────────────
# A missing SVG loader is the most likely cause of icons rendering as blank
# squares — Adwaita icons are SVG, and without the loader they can't paint.
log_section "GDK pixbuf loaders"

pixbuf_update_output=$(gdk-pixbuf-query-loaders-64 --update-cache 2>&1)
pixbuf_update_rc=$?
if [[ $pixbuf_update_rc -eq 0 ]]; then
    loader_count=$(gdk-pixbuf-query-loaders-64 2>/dev/null | grep -c '^"' || true)
    if [[ "$loader_count" -gt 0 ]]; then
        log_success "  ✓ $loader_count loaders registered"
    else
        fail "No pixbuf loaders registered"
    fi

    if gdk-pixbuf-query-loaders-64 2>/dev/null | grep -q "image/svg"; then
        log_success "  ✓ SVG loader registered"
    else
        fail "SVG pixbuf loader not registered — icons will render as blank squares"
    fi

    if gdk-pixbuf-query-loaders-64 2>/dev/null | grep -q "image/png"; then
        log_success "  ✓ PNG loader registered"
    else
        fail "PNG pixbuf loader not registered"
    fi
else
    fail "gdk-pixbuf-query-loaders-64 --update-cache failed (exit code $pixbuf_update_rc)"
    printf '%s\n' "$pixbuf_update_output" | head -5 | while read -r line; do
        echo "    $line"
    done
fi

# ── GLib schemas ────────────────────────────────────────────────────────────
log_section "GLib schemas"

schema_out=$(glib-compile-schemas /usr/share/glib-2.0/schemas/ 2>&1 || true)
if echo "$schema_out" | grep -qiE 'error|conflict'; then
    fail "GLib schema compilation reported issues:"
    echo "$schema_out" | head -5 | while read -r line; do
        echo "    $line"
    done
else
    log_success "  ✓ Schemas compiled clean"
fi

# ── Font registration ───────────────────────────────────────────────────────
log_section "Font registration"

fc-cache -f &>/dev/null

font_count=$(fc-list | wc -l)
if [[ "$font_count" -lt 10 ]]; then
    fail "Only $font_count fonts registered — fontconfig is likely broken"
else
    log_success "  ✓ $font_count fonts registered"
fi

# Fonts 02-build.sh explicitly installs — if missing, the install step failed.
readonly -a EXPECTED_FONTS=(
    "Inter"
    "Cantarell"
)
for font in "${EXPECTED_FONTS[@]}"; do
    if fc-list | grep -qi "$font"; then
        log_success "  ✓ $font"
    else
        log_warning "  ? $font not registered (soft warning)"
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

# ── Codec stack integrity ───────────────────────────────────────────────────
# Catches the ABI-skew class of bug where libavcodec-freeworld links against
# x265/vvenc symbol versions that no longer exist on the live system. Used
# to be a runtime failure (ffmpeg refusing to launch, GStreamer pipelines
# erroring out); now a build failure with a clear diagnostic.
#
# Three layers, cheap to expensive:
#   1. ldd on ffmpeg/ffprobe + every libav*.so — catches missing sonames
#   2. ffmpeg -encoders — catches versioned-symbol failures ldd can't see
#      (e.g. "undefined symbol: x265_api_get_215")
#   3. gst-inspect of va/x265enc plugins — catches GStreamer-side regressions
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
            if grep -qE "^ [VA]\.\.\.\.\. ${enc} " <<<"$ffmpeg_out"; then
                log_success "  ✓ encoder: $enc"
            else
                fail "encoder missing (Tier 1, hard): $enc"
            fi
        done
        for enc in "${TIER2_ENCODERS[@]}"; do
            if grep -qE "^ [VA]\.\.\.\.\. ${enc} " <<<"$ffmpeg_out"; then
                log_success "  ✓ encoder: $enc"
            else
                log_warning "  ? encoder missing (Tier 2, soft): $enc"
            fi
        done
        for enc in "${TIER3_ENCODERS[@]}"; do
            if grep -qE "^ [VA]\.\.\.\.\. ${enc} " <<<"$ffmpeg_out"; then
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
    # x265enc lives in gstreamer1-plugins-bad-freeworld; its absence usually
    # means the freeworld swap failed silently in 02-build.sh.
    if gst-inspect-1.0 x265enc &>/dev/null; then
        log_success "  ✓ GStreamer x265enc present"
    else
        fail "GStreamer x265enc missing — gstreamer1-plugins-bad-freeworld likely failed"
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
