---
name: build-pipeline
description: DistinctionOS image build architecture — execution order, Containerfile mounts, OCI cache artifacts, and build-container gotchas. Use when editing the Containerfile, anything in build_files/, the GitHub Actions workflows, or diagnosing a failed image build.
---

# DistinctionOS Build Pipeline

## Execution order (Containerfile RUN chain — the single source of truth)

| Step | Script | Purpose | Failure mode |
|------|--------|---------|--------------|
| 1 | `00-kernel.sh` | Swap stock kernel → kernel-cachyos-lto | Hard fail (`set -e`) |
| 2 | `01-kernel-modules.sh` | Regenerate initramfs via dracut | Hard fail |
| 3 | `02-build.sh` | Package install from manifests | **Best-effort** — deliberately no `set -e`; tracks FAILED_PACKAGES, only a missing `steam` fails the build |
| 4 | `03-cache-install.sh` | RPMs from `distinctionos-cache` OCI artifact | — |
| 5 | `04-force-install.sh` | `rpm --force --nodeps` RPMs from OCI artifact | — |
| 6 | `05-remote-grabber.sh` | GNOME Shell extensions (commit-pinned) | Hard fail on any extension |
| 7 | `06-fix-opt.sh` | /opt persistence via tmpfiles.d | Hard fail |
| 8 | `07-config.sh` | Services, shell defaults, misc | Hard fail |
| 9 | `08-validate.sh` | Environment sanity checks | Soft by default (`VALIDATION_SOFT=1`) |

If you add/remove/reorder a step: update the Containerfile, this table,
and README.md in the same commit.

## Containerfile mount gotchas

- `/tmp` is a **tmpfs mount** — contents vanish; never stage files there
  that must reach the image. Pre-cached RPMs live in `/var/tmp/` for this
  exact reason.
- `/var/cache` and `/var/log` are **BuildKit cache mounts** — they persist
  across builds. This is why 08-validate.sh wipes the ldconfig aux-cache;
  treat anything read from these paths as potentially stale.
- Build scripts are bind-mounted at `/ctx/`, not copied into the image.
  Manifests are therefore at `/ctx/manifests/`.
- An optional GitHub token is mounted at `/run/secrets/github_token`
  (use the `github_api_get` helper in 02-build.sh, never raw curl to
  api.github.com).

## Package data lives in manifests

`build_files/manifests/*.list` — one package per line, `#` comments.
`coprs.list` format: `owner/project pkg [pkg...]`. To add a package, edit
the manifest; touch 02-build.sh only for new *behaviour*.

## CI facts

- `paths-ignore` must NOT include `system_files/**` — those files are baked
  into the image.
- Image builds with `sudo buildah bud`; the rechunker and cosign signing
  run afterwards. Scheduled rebuild every 5 days.
- Cache and force-install RPMs come from separate workflows
  (`build-cache.yml`, `build-force-install.yml`) pushed to GHCR; `:latest`
  is rolling, `:YYYYMMDD` is pinned.
