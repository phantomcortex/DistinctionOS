---
name: shell-conventions
description: DistinctionOS shell scripting house style — logging functions, error-handling strategy, shellcheck requirements, and patterns to reuse. Use when writing or modifying any .sh file in build_files/ or system_files/.
---

# DistinctionOS Shell Conventions

## Non-negotiables

1. **Shebang**: `#!/usr/bin/bash`
2. **Must pass**: `shellcheck -S error -e SC1091 <file>` — CI gates on this.
3. **Build scripts** source the shared library first:
   `source /ctx/95-utility-functions.sh`
4. **Error strategy is deliberate and per-script**:
   - `set -euo pipefail` for scripts where any failure should abort.
   - `set -uo pipefail` (no `-e`) ONLY for best-effort installers
     (02-build.sh). Do not "fix" this by adding `-e`.

## Use the library — do not reinvent

Logging: `log_header`, `log_section`, `log_info`, `log_success`,
`log_warning`, `log_error`. Lifecycle: `script_start`, `script_complete`.
Helpers: `create_dir_with_log`, `counter_display`, `run_with_log`.

Never `echo` raw status lines in build scripts; never invent a new logging
scheme. If a helper is missing, add it to 95-utility-functions.sh rather
than defining it locally in two places.

## Established patterns to reuse (don't redesign)

- **Resilient install**: bulk attempt → individual fallback → record in
  SUCCEEDED_PACKAGES / FAILED_PACKAGES. See `install_packages_resilient`.
- **dnf output**: append to `$DNF_LOG`, surface with `dnf_log_tail` on
  failure. Never `&>/dev/null` a dnf call.
- **GitHub API**: always via `github_api_get` (handles token + retries).
- **Downloads**: `curl -fL --retry 3 --retry-delay 2`, then verify the
  artifact before use; failures log a warning, not silence.
- **Package data**: belongs in `build_files/manifests/`, read via
  `read_manifest`.

## Style

- 2-space indent in build_files, 4-space in 05-remote-grabber.sh (match
  the file you're in).
- Section banners: `# ===...===` for major, `# ───...───` for minor.
- Quote all expansions; arrays for command construction
  (`local -a cmd=(...)` then `"${cmd[@]}"`).
- `readonly` for constants; `local` for everything inside functions.
