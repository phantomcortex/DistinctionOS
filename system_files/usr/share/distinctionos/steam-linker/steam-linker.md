# Steam Linker

**Part of the DistinctionOS Housekeeper Architecture**

A service that automatically creates symlinks to `~/Games/Steamlibrary/` from all Steam library locations, providing unified access to installed games regardless of where they're physically stored.

---

## Current Status

| Component | Status |
|-----------|--------|
| Core Script | ✅ Complete |
| VDF Parser | ✅ Complete |
| State Management | ✅ Complete |
| SystemD Service | ✅ Complete |
| ujust Recipes | ✅ Complete |
| Log Rotation | ✅ Complete |
| Documentation | ✅ Complete |

**Version:** 1.0.0

---

## Features

- **Auto-Discovery**: Parses Steam's `libraryfolders.vdf` to find all library locations
- **State Tracking**: Remembers managed symlinks for automatic restoration
- **Broken Link Cleanup**: Automatically removes symlinks to uninstalled games
- **Duplicate Detection**: Warns when the same game exists in multiple libraries
- **Dry-Run Mode**: Preview changes before applying them
- **Comprehensive Logging**: All operations logged with rotation

---

## Usage

### Quick Commands (ujust)

```bash
# Update all symlinks
ujust steam-link

# Preview what would change
ujust steam-link-preview

# Check current status
ujust steam-link-status

# Clean up broken symlinks only
ujust steam-link-cleanup

# Restore accidentally deleted symlinks
ujust steam-link-restore

# Enable automatic execution at login
ujust steam-link-enable

# View logs
ujust steam-link-logs
```

### Direct Script Usage

```bash
# Full operation
/usr/share/distinctionos/steam-linker/steam-linker.sh

# With options
steam-linker.sh --verbose    # Detailed output
steam-linker.sh --dry-run    # Preview mode
steam-linker.sh --cleanup    # Only remove broken links
steam-linker.sh --restore    # Restore from state
steam-linker.sh --status     # Show status
steam-linker.sh --help       # Help text
```

---

## Configuration

### User Configuration File

Location: `~/.config/distinctionos/steam-linker.conf`

```bash
# Target directory for symlinks
STEAM_LINKER_TARGET_DIR="${HOME}/Games/Steamlibrary"

# Path to Steam's library configuration
STEAM_LINKER_VDF_PATH="${HOME}/.local/share/Steam/steamapps/libraryfolders.vdf"
```

### Configuration Hierarchy

1. **System defaults**: `/usr/share/distinctionos/steam-linker/steam-linker.conf`
2. **Local overrides**: `/usr/local/share/distinctionos/steam-linker/steam-linker.conf`
3. **User overrides**: `~/.config/distinctionos/steam-linker.conf`

Each level overrides the previous.

---

## File Locations

| Purpose | Location |
|---------|----------|
| Main script | `/usr/share/distinctionos/steam-linker/steam-linker.sh` |
| Shared library | `/usr/share/distinctionos/lib/housekeeper-common.sh` |
| SystemD service | `/usr/lib/systemd/user/distinctionos-steam-linker.service` |
| ujust recipes | `/usr/share/distinctionos/just/steam-linker.just` |
| State data | `~/.local/share/distinctionos/steam-linker/state.json` |
| Log file | `/var/log/distinctionos/steam-linker.log` |
| User config | `~/.config/distinctionos/steam-linker.conf` |

---

## Roadmap

### Short Term
- [ ] Add timer-based periodic refresh option
- [ ] Support for non-Steam game launchers (Lutris, Heroic)
- [ ] Desktop notifications for new games linked

### Long Term
- [ ] Integration with game metadata (playtime, last played)
- [ ] Custom categorisation via subdirectories
- [ ] Web UI for managing linked games

---

## Known Issues

1. **First Run**: The service won't run until Steam has been launched at least once (creates `libraryfolders.vdf`)

2. **Removable Media**: If a Steam library is on a removable drive that isn't mounted, its symlinks will be cleaned up as "broken" and recreated when the drive is mounted again

3. **jq Dependency**: Full state tracking requires `jq`. Without it, a simpler file-based tracking is used

---

## Technical Details

### VDF Parsing

Steam's `libraryfolders.vdf` uses Valve's custom key-value format:

```
"libraryfolders"
{
    "0"
    {
        "path"        "/home/user/.local/share/Steam"
        "label"       ""
        ...
    }
    "1"
    {
        "path"        "/mnt/games/SteamLibrary"
        ...
    }
}
```

The parser extracts all `"path"` values using awk.

### State File Format

```json
{
    "version": "1.0",
    "symlinks": {
        "Cyberpunk 2077": {
            "target": "/mnt/games/SteamLibrary/steamapps/common/Cyberpunk 2077",
            "created": "2024-01-15T10:30:00+00:00"
        }
    }
}
```

### Logging

Logs are written to `/var/log/distinctionos/steam-linker.log` with automatic rotation when:
- Individual log exceeds 50MB (rotates to `.log.1`, `.log.2`)
- Total directory exceeds 500MB (oldest logs deleted)

---

## Troubleshooting

### Symlinks not being created

1. Check Steam is installed: `ls ~/.local/share/Steam/steamapps/libraryfolders.vdf`
2. Run with verbose: `ujust steam-link` or `steam-linker.sh --verbose`
3. Check logs: `ujust steam-link-logs`

### Service not running at login

1. Ensure it's enabled: `systemctl --user status distinctionos-steam-linker.service`
2. Enable if needed: `ujust steam-link-enable`

### Duplicate symlinks appearing

This shouldn't happen under normal operation. If it does:
1. Run cleanup: `ujust steam-link-cleanup`
2. Check for duplicate game installations: `ujust steam-link-status`

---

## Integration with Housekeeper Architecture

Steam Linker is part of the broader Housekeeper Architecture, sharing:

- **Common library**: `/usr/share/distinctionos/lib/housekeeper-common.sh`
- **Logging infrastructure**: `/var/log/distinctionos/`
- **Configuration hierarchy**: System → Local → User
- **State management**: `~/.local/share/distinctionos/<service>/`

This ensures consistent behaviour across all DistinctionOS automation services.
