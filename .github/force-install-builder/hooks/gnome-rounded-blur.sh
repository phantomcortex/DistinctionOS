#!/bin/bash
# Pre-build hook for gnome-rounded-blur.
#
# Upstream's meson.build hard-codes mutter_req and mutter_api_version to
# whatever mutter version was current when the tag was cut. Rewrite both
# to match the mutter installed in this builder (terra ships the same
# mutter version DistinctionOS runs, so the resulting .so links against
# the same ABI the target system will load).
set -euo pipefail

# System mutter major version (e.g. "50" from "50.1-1.fc44").
mutter_sys=$(rpm -q --queryformat='%{VERSION}\n' mutter | head -1 | grep -oP '^\d+')
if [[ -z "$mutter_sys" ]]; then
    echo "    Could not read system mutter version from rpm" >&2
    exit 1
fi

mutter_repo_req=$(grep -oP "mutter_req\s*=\s*[\"'][^\"']*" meson.build | grep -oP '\d+' | head -1)
mutter_api_repo=$(grep -oP "mutter_api_version\s*=\s*[\"'][^\"']*" meson.build | grep -oP '\d+' | head -1)

if [[ -z "$mutter_repo_req" || -z "$mutter_api_repo" ]]; then
    echo "    Could not parse mutter_req/mutter_api_version from meson.build" >&2
    exit 1
fi

# delta = how many mutter major versions ahead we are of upstream's pin.
# mutter's API version advances in lockstep with its major version.
delta=$(( mutter_sys - mutter_repo_req ))
new_api=$(( mutter_api_repo + delta ))

echo "    System mutter: $mutter_sys"
echo "    Patching mutter_req: $mutter_repo_req -> $mutter_sys"
echo "    Patching mutter_api_version: $mutter_api_repo -> $new_api"

sed -i "s/mutter_req\s*=\s*\"${mutter_repo_req}\"/mutter_req = \"${mutter_sys}\"/" meson.build
sed -i "s/mutter_api_version\s*=\s*\"${mutter_api_repo}\"/mutter_api_version = \"${new_api}\"/" meson.build
