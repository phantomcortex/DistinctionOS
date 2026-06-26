# DistinctionOS — Claude Code Context

Custom Bazzite-based (Fedora Atomic) bootc image. Built via GitHub Actions →
GHCR. Single maintainer (phantomcortex). Deep context lives in skills under
`.claude/skills/` — they load automatically when relevant. Do NOT re-read
`docs/claude.md`; it is legacy and may be stale.

## Working agreement (applies to EVERY task)

- **Minimal diffs.** Change the fewest lines that solve the problem. No new
  abstractions, wrappers, config layers, or "while we're here" refactors
  unless explicitly requested.
- **Plan first on non-trivial work.** If a change would exceed ~30 lines or
  touch more than two files, propose the approach in ≤5 lines and wait for
  approval before writing code.
- **Match house style, don't invent one.** Build scripts source
  `95-utility-functions.sh` and use its `log_*` functions. See the
  `shell-conventions` skill.
- **Keep docs and build telling the same story.** If you change the
  Containerfile or build sequence, update README.md in the same commit.
- **Update `docs/` in the same commit.** After any commit that changes
  behaviour, build sequence, or project direction, update the relevant file
  under `docs/` (and `docs/roadmap.md` for goal changes). Stale docs are the
  default failure mode here — treat the doc update as part of the change, not
  a follow-up.

## Commands

- Lint shell exactly as CI does: `shellcheck -S error -e SC1091 build_files/*.sh`
- Local image build: `just build` (runs `check-syntax` first)
- VM test: `just build-qcow2 && just run-vm`

## Testing before merge

- **Always validate on the `testing` image before pushing to `main`.** Either
  build locally (`just build`) or trigger a GitHub Actions build targeting the
  `testing` branch/tag, then boot the result in a VM (`just build-qcow2 &&
  just run-vm`) or test deploy. Do not push build-system or package changes
  directly to `main` without a test run — CI only checks that the image
  assembles, not that it boots or behaves correctly.

## Hard rules

- Never use `dnf --allowerasing` (guarded against in 02-build.sh).
- Package lists belong in `build_files/manifests/*.list`, not in scripts.
- Build scripts run in a container with `/tmp` as tmpfs — anything that must
  survive into the image goes under `/var/tmp` or a real path.
- Content under `/var` (incl. `/var/opt`, `/var/lib`) is only seeded into an
  empty `/var` at first boot — `bootc upgrade` never re-applies it, so files
  written to `/var` at build time go stale on upgraded systems. Anything that
  must update with the image lives under `/usr` (see `06-fix-opt.sh`: packages
  go to `/usr/lib/opt` with a tmpfiles `L+` symlink back to `/var/opt`).
- `/var/cache` is a BuildKit cache mount — its contents persist across builds
  and can be stale (see the `ldconfig` aux-cache wipe in `08-validate.sh`).
  Don't trust it mid-build.
- Third-party git clones in 05-remote-grabber.sh must be commit-pinned
  (`url#sha`).
- Interactive `dnf`/`dnf5` is the `distinction-dnf` guard
  (`system_files/usr/bin/distinction-dnf`, aliased in
  `/etc/profile.d/distinction-dnf-guard.sh`); `07-config.sh` removes Bazzite's
  own `/usr/bin/dnf` wrapper. The guard always permits read-only verbs
  (search, info, repoquery, …) but blocks mutating verbs unless `/usr` is
  unlocked (`ostree admin unlock`). Build scripts call `dnf5` directly and are
  unaffected. It's a UX layer, not a security boundary.
- `dnf versionlock add` baked into the image is inert at runtime: deployed
  bootc systems update by whole-image swap, and `rpm-ostree` does not load
  dnf's versionlock plugin, so the persisted `versionlock.list` is never
  consulted. Do NOT add locks expecting to pin the running system — to pin a
  version, do it at build time (`dnf install foo-X.Y.Z`, a build-time
  `versionlock add`, or a repo exclude). Inherited locks DO constrain
  build-time dnf, which is why 02-build.sh runs `versionlock clear` first.

## Subprojects

These repos are co-maintained with DistinctionOS and built into the image:

| Repo | Path | Purpose |
|------|------|---------|
| `gstreamer-plugin-xwm` | `../gstreamer-plugin-xwm` | GStreamer typefinder + demuxer for `.xwm` (xWMA) and `.fuz` (Bethesda FUZ) audio |
| `glycin` (fork) | `../glycin` | glycin image-loader fork with BC7 texture support |

Each subproject has its own `CLAUDE.md` with build instructions. When working
across repos, read the target repo's `CLAUDE.md` first.
