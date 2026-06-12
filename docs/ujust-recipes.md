# DistinctionOS ujust Recipes

All `ujust` recipes available in DistinctionOS. Recipes are loaded from `/usr/share/distinctionos/just/` and integrated into the Bazzite recipe system at build time.

---

## Recipe Files

| File | Location | Purpose |
|------|----------|---------|
| `distinction.just` | `/usr/share/distinctionos/just/distinction.just` | Post-install setup, shell, apps |
| `steam-linker.just` | `/usr/share/distinctionos/just/steam-linker.just` | Steam library symlink management |

---

## Setup & Installation Recipes

Defined in `distinction.just`. These run post-rebase to configure the user environment.

### `distinction-install`

Runs the full post-rebase setup in one shot: Flatpaks → Homebrews → shell → NvChad.

```bash
ujust distinction-install
```

### `distinction-install-shell`

Installs only the shell-related components (custom ZSH config + NvChad).

```bash
ujust distinction-install-shell
```

### `distinction-install-flatpaks`

Fetches the Flatpak list from the internal repo and installs all apps. Also applies GTK theme overrides so Flatpak apps inherit the system theme.

```bash
ujust distinction-install-flatpaks
```

List source: `https://raw.githubusercontent.com/phantomcortex/distinction-ublue-internal/main/repo_files/flatpaks`

### `distinction-install-brews`

Installs Homebrew packages from the internal package list, then updates the `tldr` cache.

```bash
ujust distinction-install-brews
```

List source: `https://raw.githubusercontent.com/phantomcortex/distinction-ublue-internal/main/repo_files/brews`

**Prerequisite:** Homebrew must be installed first.

### `distinction-install-custom-shell`

- Switches the user and root shells to ZSH
- Clones and installs personal dotfiles (`phantomcortex/dotfiles`)
- Links `~/.zshrc` from dotfiles

```bash
ujust distinction-install-custom-shell
```

### `distinction-install-nvchad`

Installs NvChad (Neovim configuration framework) for both the user and root. Installs Neovim via Homebrew if not already present.

```bash
ujust distinction-install-nvchad
```

**Note:** Run `nvim` once after installation to finish lazy.nvim plugin setup. Run `sudo nvim` separately to complete root setup.

### `distinction-install-nautilus-scripts`

Installs the cfgnunes/nautilus-scripts collection (right-click scripts for Nautilus).

```bash
ujust distinction-install-nautilus-scripts
```

---

## Games — Steam Linker Recipes

Defined in `steam-linker.just`. Manages symlinks between all Steam library locations and `~/Games/Steamlibrary/`.

See also: [docs/steam-linker.md](steam-linker.md)

### `steam-link`

Runs a full symlink update — discovers all Steam libraries, creates missing symlinks, removes broken ones.

```bash
ujust steam-link
```

### `steam-link-preview`

Dry-run: shows what would change without making any modifications.

```bash
ujust steam-link-preview
```

### `steam-link-status`

Displays current symlink state: linked games, source libraries, broken links.

```bash
ujust steam-link-status
```

### `steam-link-cleanup`

Removes broken symlinks only — useful after uninstalling games.

```bash
ujust steam-link-cleanup
```

### `steam-link-restore`

Recreates any symlinks tracked in the state file that have been accidentally deleted.

```bash
ujust steam-link-restore
```

### `steam-link-enable`

Enables the Steam Linker systemd user service so it runs automatically at login.

```bash
ujust steam-link-enable
```

### `steam-link-disable`

Disables automatic execution at login.

```bash
ujust steam-link-disable
```

### `steam-link-logs`

Opens the Steam Linker log in `less`. Checks both the primary log path and the fallback.

```bash
ujust steam-link-logs
```

---

## Planned / Potential Future Recipes

These don't exist yet but are logical additions as features mature.

### TPM Management

When the TPM auto-unlock system is redesigned:

| Recipe | Purpose |
|--------|---------|
| `distinction-tpm-setup` | Interactive TPM enrollment with PCR preset selection |
| `distinction-tpm-reenrol` | Quick re-enroll after system updates |
| `distinction-tpm-verify` | Check current TPM unlock status |
| `distinction-tpm-reset` | Full TPM binding reset |
| `distinction-tpm-logs` | View TPM monitor logs |

### System Maintenance

| Recipe | Purpose |
|--------|---------|
| `distinction-update` | Trigger `rpm-ostree upgrade` with TPM-awareness |
| `distinction-status` | Quick overview of OS, TPM, Steam Linker health |

---

## Adding a New Recipe

1. Create or edit a `.just` file in `system_files/usr/share/distinctionos/just/`
2. Use `[group('Category')]` to group related recipes in `ujust` output
3. If it's a new file, `07-config.sh` imports all `.just` files from that directory automatically — no manual registration needed
4. Test locally with `just -f system_files/usr/share/distinctionos/just/yourfile.just --list`
