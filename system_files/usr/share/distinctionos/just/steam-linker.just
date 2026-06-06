# DistinctionOS Steam Linker Recipes
# Part of the Housekeeper Architecture

# Update Steam library symlinks
[group('Games')]
steam-link:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🎮 Updating Steam library symlinks..."
    /usr/share/distinctionos/steam-linker/steam-linker.sh --verbose
    echo ""
    echo "✅ Steam library symlinks updated!"
    echo "   Your games are available at: ~/Games/Steamlibrary/"

# Preview what Steam Linker would do
[group('Games')]
steam-link-preview:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Preview mode - no changes will be made"
    echo ""
    /usr/share/distinctionos/steam-linker/steam-linker.sh --dry-run

# Show Steam Linker status
[group('Games')]
steam-link-status:
    #!/usr/bin/env bash
    /usr/share/distinctionos/steam-linker/steam-linker.sh --status

# Clean up broken symlinks only
[group('Games')]
steam-link-cleanup:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧹 Cleaning up broken symlinks..."
    /usr/share/distinctionos/steam-linker/steam-linker.sh --cleanup --verbose

# Restore accidentally deleted symlinks
[group('Games')]
steam-link-restore:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔄 Restoring symlinks from saved state..."
    /usr/share/distinctionos/steam-linker/steam-linker.sh --restore --verbose

# Enable automatic Steam linking at login
[group('Games')]
steam-link-enable:
    #!/usr/bin/env bash
    set -euo pipefail
    systemctl --user enable distinctionos-steam-linker.service
    echo "✅ Steam Linker will now run automatically at login"

# Disable automatic Steam linking at login
[group('Games')]
steam-link-disable:
    #!/usr/bin/env bash
    set -euo pipefail
    systemctl --user disable distinctionos-steam-linker.service
    echo "✅ Steam Linker automatic execution disabled"

# View Steam Linker logs
[group('Games')]
steam-link-logs:
    #!/usr/bin/env bash
    log_file="/var/log/distinctionos/steam-linker.log"
    fallback_log="${HOME}/.local/share/distinctionos/logs/steam-linker.log"

    if [[ -f "$log_file" ]]; then
        less +G "$log_file"
    elif [[ -f "$fallback_log" ]]; then
        less +G "$fallback_log"
    else
        echo "No log file found. The service may not have run yet."
        echo "Expected locations:"
        echo "  - ${log_file}"
        echo "  - ${fallback_log}"
    fi
