# Pre-build hooks

Drop a shell script in this directory named `<package-name>.sh` to have it
run after the upstream repo is cloned but before the build system is
detected and invoked. The package name must match the entry's first field
in `packages.txt`.

The hook runs with `$PWD` set to the cloned source directory. It can:

- Patch files (e.g. `sed` `meson.build` to update version pins)
- Apply project-specific quirks the generic `github-build` flow can't know
- Install additional build deps via `dnf`

Hooks should `set -euo pipefail` so failures abort the artifact build
cleanly rather than producing a silently-broken RPM.

Example: `hooks/gnome-rounded-blur.sh` rewrites the upstream's hard-coded
`mutter_req` and `mutter_api_version` in `meson.build` to match whichever
mutter version the builder has installed from terra.
