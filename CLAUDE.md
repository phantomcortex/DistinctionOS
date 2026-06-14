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

## Hard rules

- Never use `dnf --allowerasing` (guarded against in 02-build.sh).
- Package lists belong in `build_files/manifests/*.list`, not in scripts.
- Build scripts run in a container with `/tmp` as tmpfs — anything that must
  survive into the image goes under `/var/tmp` or a real path.
- Third-party git clones in 05-remote-grabber.sh must be commit-pinned
  (`url#sha`).
- `dnf versionlock add` is a no-op on ostree images — do not reintroduce it.
