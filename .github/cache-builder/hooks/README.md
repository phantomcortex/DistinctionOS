# Pre-build hooks

Drop a shell script in this directory named `<package-name>.sh` to have it
run after the upstream repo is cloned but before the build system is
detected and invoked. The package name must match the entry's first field
in `packages.txt`.

The hook runs with `$PWD` set to the cloned source directory. See
`.github/force-install-builder/hooks/README.md` for the full contract.

Cache packages are typically downloaded RPMs that don't need hooks, but
the infrastructure is mirrored here for consistency with `github-build`
entries that may need pre-build patching.
