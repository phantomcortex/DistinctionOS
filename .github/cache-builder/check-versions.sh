#!/bin/bash
# Outputs a JSON object mapping package name -> current upstream version,
# for every package listed in /input/packages.txt. Used by the workflow to
# decide whether the artifact needs rebuilding.
set -euo pipefail

MANIFEST="${MANIFEST:-/input/packages.txt}"

# Refresh metadata once so repoquery sees current versions.
dnf makecache --refresh >&2 2>/dev/null || true

declare -A VERSIONS

while IFS='|' read -r name source arg || [[ -n "$name" ]]; do
    name="${name// /}"
    source="${source// /}"
    arg="${arg// /}"

    [[ -z "$name" || "$name" =~ ^# ]] && continue

    ver=""
    case "$source" in
        dnf)
            enablerepo=()
            [[ -n "$arg" ]] && enablerepo=(--enablerepo="$arg")
            ver=$(dnf repoquery --quiet --queryformat='%{evr}' "${enablerepo[@]}" "$name" 2>/dev/null \
                  | sort -V | tail -1 || echo "")
            ;;
        url)
            # Follow redirects (HEAD) and use the resolved filename as the
            # version — CrossOver's redirect resolves to a versioned RPM name.
            ver=$(curl -sIL -o /dev/null -w '%{url_effective}' "$arg" 2>/dev/null \
                  | sed 's/?.*$//; s#.*/##' || echo "")
            ;;
        github-release)
            ver=$(curl -sf "https://api.github.com/repos/$arg/releases/latest" \
                  | jq -r '.tag_name // ""' 2>/dev/null || echo "")
            ;;
        github-build)
            repo="${arg%%@*}"
            ref="${arg#*@}"; [[ "$ref" == "$arg" ]] && ref="HEAD"
            ver=$(git ls-remote "https://github.com/$repo" "$ref" 2>/dev/null \
                  | head -1 | cut -f1 | cut -c1-12 || echo "")
            ;;
        *)
            echo "Unknown source type for $name: $source" >&2
            ;;
    esac

    VERSIONS["$name"]="$ver"
done < "$MANIFEST"

# Emit canonicalized JSON (sorted keys, compact) so diffs are stable.
output=$(jq -n '{}')
for k in "${!VERSIONS[@]}"; do
    output=$(printf '%s\n' "$output" | jq --arg k "$k" --arg v "${VERSIONS[$k]}" '. + {($k): $v}')
done
printf '%s\n' "$output" | jq -S -c '.'
