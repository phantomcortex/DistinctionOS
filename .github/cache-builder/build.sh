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
            dnf download --destdir=/output/rpms "${enablerepo[@]}" "$name"
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
            repo="${arg%%@*}"
            ref="${arg#*@}"; [[ "$ref" == "$arg" ]] && ref=""

            work_dir=$(mktemp -d)
            src_dir="$work_dir/src"
            install_dir="$work_dir/install"

            if [[ -n "$ref" ]]; then
                # Shallow-clone the ref first; fall back to full clone if ref
                # is a commit SHA or annotated tag, not a branch.
                if ! git clone --depth 1 --branch "$ref" \
                        "https://github.com/$repo" "$src_dir" 2>/dev/null; then
                    git clone "https://github.com/$repo" "$src_dir"
                    (cd "$src_dir" && git checkout "$ref")
                fi
            else
                git clone --depth 1 "https://github.com/$repo" "$src_dir"
            fi

            pushd "$src_dir" >/dev/null
            commit_sha=$(git rev-parse HEAD)

            # Pre-build hook: if hooks/<name>.sh ships in this builder, run
            # it with $PWD set to the cloned source. Lets packages apply
            # repo-specific patches without bloating the generic github-build flow.
            hook_script="/input/hooks/${name}.sh"
            if [[ -f "$hook_script" ]]; then
                echo "    Running pre-build hook: hooks/${name}.sh"
                bash "$hook_script"
            fi

            if [[ -f meson.build ]]; then
                echo "    Build system: meson"
                meson setup build --prefix=/usr --buildtype=release
                meson compile -C build -j "$(nproc)"
                DESTDIR="$install_dir" meson install -C build
            elif [[ -f CMakeLists.txt ]]; then
                echo "    Build system: cmake"
                cmake -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
                cmake --build build -j "$(nproc)"
                DESTDIR="$install_dir" cmake --install build
            elif [[ -f Makefile || -f makefile ]]; then
                echo "    Build system: make"
                make -j "$(nproc)"
                make install DESTDIR="$install_dir" PREFIX=/usr
            else
                echo "    No supported build system (meson/cmake/make) found in $repo" >&2
                exit 1
            fi
            popd >/dev/null

            if [[ ! -d "$install_dir" ]] || [[ -z "$(ls -A "$install_dir" 2>/dev/null)" ]]; then
                echo "    Build of $repo produced no install tree" >&2
                exit 1
            fi

            # Date-stamped version for RPM monotonicity; release embeds the
            # commit SHA for traceability back to source.
            rpm_ver=$(date -u +%Y%m%d)
            rpm_rel="1.gh${commit_sha:0:7}"

            fpm -s dir -t rpm \
                -n "$name" \
                -v "$rpm_ver" \
                --iteration "$rpm_rel" \
                --description "Auto-packaged build of $name from $repo@${commit_sha:0:7}" \
                --license "Unspecified" \
                -a x86_64 \
                --no-auto-depends \
                --rpm-auto-add-directories \
                -C "$install_dir" \
                -p "/output/rpms/" \
                . >&2

            rm -rf "$work_dir"

            # Track commit SHA as the upstream version (matches check-versions.sh).
            ver="${commit_sha:0:12}"
            ;;
        *)
            echo "    unknown source type: $source" >&2
            exit 1
            ;;
    esac

    VERSIONS["$name"]="$ver"
done < "$MANIFEST"

# Drop source RPMs — the artifact ships binary RPMs only. Some upstream
# GitHub releases attach both .rpm and .src.rpm assets, and rpm install
# chokes on .src.rpm at OS-build time.
find /output/rpms -name '*.src.rpm' -print -delete

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
