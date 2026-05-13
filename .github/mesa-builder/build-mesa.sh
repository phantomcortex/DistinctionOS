#!/bin/bash
# Builds the full mesa stack from Fedora's SRPM with freeworld codec support enabled.
# Output RPMs land in /output/rpms/ inside the container.
set -euo pipefail

OUTPUT_DIR="/output/rpms"
mkdir -p "$OUTPUT_DIR" ~/build

dnf install -y rpm-build dnf-plugins-core sed findutils python3

# ── Download Fedora 44 mesa SRPM ──────────────────────────────────────────────
# Fedora 44 ships mesa 26.1.x. If a newer stable is available it will be pulled.
cd ~/build
dnf download --source mesa

# Extract into ~/rpmbuild
rpm -ivh mesa-*.src.rpm

# ── Install all build dependencies ───────────────────────────────────────────
# Handles rust, llvm, clang, wayland-devel, vulkan-headers, libva-devel, etc.
dnf builddep -y ~/rpmbuild/SPECS/mesa.spec

# ── Inspect and patch spec for freeworld (video codec) support ────────────────
SPEC=~/rpmbuild/SPECS/mesa.spec

echo "--- Current video-codecs line in spec ---"
grep -n "video-codecs\|video_codecs" "$SPEC" || echo "(no match — check spec manually)"
echo "-----------------------------------------"

# Fedora ships mesa with -Dvideo-codecs= set to empty or a restricted subset.
# We replace whatever is there with the full freeworld codec list.
FREEWORLD_CODECS="h264dec,h264enc,h265dec,h265enc,vc1dec"

if grep -q "video-codecs" "$SPEC"; then
    # Replace whatever codec list is there (including empty) with the full freeworld set.
    # Three patterns cover: trailing space, end-of-line, and backslash continuation.
    sed -i "s/-Dvideo-codecs=[^[:space:]]* /-Dvideo-codecs=${FREEWORLD_CODECS} /g" "$SPEC"
    sed -i "s/-Dvideo-codecs=[^[:space:]]*\$/-Dvideo-codecs=${FREEWORLD_CODECS}/g" "$SPEC"
    sed -i "s|-Dvideo-codecs=[^[:space:]]* *\\\\|-Dvideo-codecs=${FREEWORLD_CODECS} \\\\|g" "$SPEC"
else
    # Flag not present at all — append it as the first meson option.
    echo "WARNING: -Dvideo-codecs not found in spec; injecting manually"
    python3 - "$SPEC" "$FREEWORLD_CODECS" << 'PYEOF'
import sys, re
spec_path, codecs = sys.argv[1], sys.argv[2]
with open(spec_path) as f:
    content = f.read()
# Insert after the first %meson line
content = re.sub(
    r'(%meson\b[^\n]*\n)',
    r'\1  -Dvideo-codecs=' + codecs + r' \\\n',
    content, count=1
)
with open(spec_path, 'w') as f:
    f.write(content)
PYEOF
fi

echo "--- video-codecs line after patch ---"
grep -n "video-codecs\|video_codecs" "$SPEC" || echo "(still no match — manual intervention needed)"
echo "-------------------------------------"

# ── Resolve dynamic (Rust/cargo2rpm) build requirements ───────────────────────
# %generate_buildrequires runs cargo2rpm to discover Rust crate deps at build
# time; dnf builddep can't see these. Bootstrap pass triggers the generator,
# then we install whatever it says is missing before the real build.
set +e
rpmbuild -br ~/rpmbuild/SPECS/mesa.spec
_rc=$?
set -e
if [ "$_rc" -eq 11 ]; then
    _br=$(find ~/rpmbuild/SRPMS -name "*.buildreqs.nosrc.rpm" | tail -1)
    echo "Installing dynamic build requirements from: $_br"
    rpm -qp --requires "$_br" | grep -v '^rpmlib' | xargs -r dnf install -y
elif [ "$_rc" -ne 0 ]; then
    echo "Bootstrap pass failed (exit $_rc)" >&2
    exit "$_rc"
fi

# ── Build all subpackages ─────────────────────────────────────────────────────
# Limit parallelism to avoid OOM on CI runners (7 GB RAM + 10 GB swap).
# LLVM linking can peak at 4-6 GB alone; -j3 keeps two units in flight
# without spiking the way an uncapped build would.
rpmbuild -bb ~/rpmbuild/SPECS/mesa.spec \
    --define "_smp_mflags -j3"

# ── Collect RPMs (skip debuginfo/debugsource) ─────────────────────────────────
find ~/rpmbuild/RPMS -name "*.rpm" \
    ! -name "*debuginfo*" \
    ! -name "*debugsource*" \
    -exec cp {} "$OUTPUT_DIR/" \;

echo ""
echo "Built RPMs:"
ls -la "$OUTPUT_DIR/"
echo ""
echo "Mesa version:"
find "$OUTPUT_DIR" -name "mesa-filesystem-*.rpm" | head -1
