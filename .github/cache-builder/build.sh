#!/bin/bash
# Reads /input/packages.txt and produces:
#   /output/rpms/*.rpm    — the RPMs to ship in the artifact
#   /output/versions.json — manifest of names -> versions baked in
set -euo pipefail

MANIFEST="${MANIFEST:-/input/packages.txt}"

mkdir -p /output/rpms

dnf makecache --refresh

declare -A VERSIONS

while IFS='|' read -r name source arg || [[ -n "$name" ]]; do
    name="${name// /}"
    source="${source// /}"
    arg="${arg// /}"

    [[ -z "$name" || "$name" =~ ^# ]] && continue

    echo "==> $name ($source${arg:+ — $arg})"

    ver=""
    case "$source" in
        dnf)
            enablerepo=()
            [[ -n "$arg" ]] && enablerepo=(--enablerepo="$arg")
            dnf download --destdir=/output/rpms --resolve "${enablerepo[@]}" "$name"
            ver=$(dnf repoquery --quiet --queryformat='%{evr}' "${enablerepo[@]}" "$name" \
                  | sort -V | tail -1)
            ;;
        github-release)
            release=$(curl -sf "https://api.github.com/repos/$arg/releases/latest")
            ver=$(printf '%s' "$release" | jq -r '.tag_name // ""')
            mapfile -t urls < <(printf '%s' "$release" \
                | jq -r '.assets[]? | select(.name|endswith(".rpm")) | .browser_download_url')
            if [[ ${#urls[@]} -eq 0 ]]; then
                echo "    no .rpm assets found in latest release of $arg" >&2
                exit 1
            fi
            for url in "${urls[@]}"; do
                curl -fL "$url" -o "/output/rpms/$(basename "$url")"
            done
            ;;
        github-build)
            echo "    github-build source is not yet implemented" >&2
            exit 1
            ;;
        *)
            echo "    unknown source type: $source" >&2
            exit 1
            ;;
    esac

    VERSIONS["$name"]="$ver"
done < "$MANIFEST"

# ── Validate downloaded/built RPMs ──────────────────────────────────────────
shopt -s nullglob
rpms=(/output/rpms/*.rpm)
shopt -u nullglob

if [[ ${#rpms[@]} -gt 0 ]]; then
    echo ""
    echo "==> Validating ${#rpms[@]} RPM(s)"
    for rpm_file in "${rpms[@]}"; do
        if [[ ! -s "$rpm_file" ]]; then
            echo "    ✗ $(basename "$rpm_file"): empty file" >&2
            exit 1
        fi
        if ! rpm -qp "$rpm_file" >/dev/null 2>&1; then
            echo "    ✗ $(basename "$rpm_file"): malformed RPM header" >&2
            exit 1
        fi
        # rpm -K returns 0 even for unsigned RPMs; only fail on actual digest mismatch.
        if rpm -K "$rpm_file" 2>&1 | grep -qi 'NOT OK'; then
            echo "    ✗ $(basename "$rpm_file"): digest/signature check failed" >&2
            exit 1
        fi
        echo "    ✓ $(basename "$rpm_file")"
    done
fi

# ── Write versions manifest ─────────────────────────────────────────────────
output=$(jq -n '{}')
for k in "${!VERSIONS[@]}"; do
    output=$(printf '%s\n' "$output" | jq --arg k "$k" --arg v "${VERSIONS[$k]}" '. + {($k): $v}')
done
printf '%s\n' "$output" | jq -S -c '.' > /output/versions.json

echo ""
echo "==> Summary"
echo "RPMs:"
ls -la /output/rpms/ 2>/dev/null || echo "    (none)"
echo "Versions:"
cat /output/versions.json
