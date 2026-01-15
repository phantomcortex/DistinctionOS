# DistinctionOS XWM Player

A seamless solution for playing Bethesda game audio formats (XWM, FUZ) on Linux using your preferred audio player.

## Overview

XWM (xWMA) is Microsoft's Xbox/Windows Media Audio format used extensively in Bethesda games such as:
- The Elder Scrolls V: Skyrim
- Fallout 4
- Fallout 76
- Starfield

FUZ files are Bethesda's voice container format, combining xWMA audio with lip-sync data.

This utility transparently converts these formats to standard audio (OGG by default) and opens them in GNOME's Audio Player (Decibels) or any configured player.

## Features

- **Double-click playback** — Just click an XWM/FUZ file and it plays
- **Flatpak-aware** — Works seamlessly with Flatpak audio players
- **Hierarchical configuration** — System, local, and user overrides
- **Extensible** — Add support for new formats via handler scripts
- **Temporary file management** — Converted files are cleaned up automatically
- **GUI error dialogues** — User-friendly error reporting

## Installation

### File Locations

```
/usr/bin/xwm-player                                    # Main executable
/usr/share/DistinctionOS/xwm-player/config             # Default configuration
/usr/share/DistinctionOS/xwm-player/handlers/          # Format handlers
/usr/share/applications/xwm-player.desktop             # Desktop file
/usr/share/mime/packages/xwm-player.xml                # MIME types
```

### For DistinctionOS

Copy files to your `system_files/` directory:

```bash
# Executable
cp xwm-player system_files/usr/bin/

# Configuration
mkdir -p system_files/usr/share/DistinctionOS/xwm-player/handlers
cp config system_files/usr/share/DistinctionOS/xwm-player/

# Desktop integration
cp applications/xwm-player.desktop system_files/usr/share/applications/
cp mime/xwm-player.xml system_files/usr/share/mime/packages/
```

Then update the MIME database in your build process:

```bash
# In your build script (e.g., config.sh)
update-mime-database /usr/share/mime
update-desktop-database /usr/share/applications
```

### Manual Installation (for testing)

```bash
sudo cp xwm-player /usr/bin/
sudo chmod +x /usr/bin/xwm-player

sudo mkdir -p /usr/share/DistinctionOS/xwm-player/handlers
sudo cp config /usr/share/DistinctionOS/xwm-player/

sudo cp applications/xwm-player.desktop /usr/share/applications/
sudo cp mime/xwm-player.xml /usr/share/mime/packages/

sudo update-mime-database /usr/share/mime
sudo update-desktop-database /usr/share/applications
```

## Usage

### Playing Files

Simply double-click an XWM or FUZ file in your file manager, or:

```bash
xwm-player music.xwm
xwm-player voice.fuz
```

### Converting Files

```bash
# Convert to OGG (default)
xwm-player --convert input.xwm output.ogg

# Convert to MP3
xwm-player --convert input.xwm output.mp3
xwm-player --format mp3 --convert input.fuz voice.mp3
```

### Cleanup

```bash
# Remove all temporary files
xwm-player --cleanup
```

### Command Line Options

```
--desktop           Suppress notifications (used by .desktop file)
--convert <i> <o>   Convert file without playing
--cleanup           Remove temporary files
--format <fmt>      Override output format (ogg, mp3, flac, wav)
--player <app>      Override audio player
--no-gui            Disable GUI error dialogues
--debug             Enable debug logging
--help              Show help message
--version           Show version
```

## Configuration

Configuration is loaded in order (later files override earlier):

1. `/usr/share/DistinctionOS/xwm-player/config` (system default)
2. `/usr/local/share/DistinctionOS/xwm-player/config` (local override)
3. `~/.config/DistinctionOS/xwm-player/config` (user override)

### Key Options

```bash
# Audio player (Flatpak app ID or native command)
PLAYER_COMMAND="org.gnome.Decibels"

# Output format: ogg, mp3, flac, wav
OUTPUT_FORMAT="ogg"

# Quality (0-10 for OGG, bitrate for MP3)
AUDIO_QUALITY="6"

# Cleanup mode: on-exit, immediate, manual, never
CLEANUP_MODE="on-exit"

# GUI error dialogues
GUI_ERRORS="true"
```

### User Override Example

To use VLC instead of Decibels, create `~/.config/DistinctionOS/xwm-player/config`:

```bash
PLAYER_COMMAND="org.videolan.VLC"
```

## Adding Format Support

1. Create a handler file in `/usr/share/DistinctionOS/xwm-player/handlers/`:

```bash
# myformat.sh
handle_myformat() {
    local input_file="$1"
    local output_file="$2"
    
    # Your conversion logic here
    ffmpeg -i "$input_file" "$output_file"
}
```

2. Register the handler in config:

```bash
HANDLER_MYF="handle_myformat"
```

See `handlers/example.sh.sample` for detailed documentation.

## Dependencies

- **Required**: `bash`, `ffmpeg`
- **Optional**: `zenity` or `kdialog` (GUI errors), `notify-send` (notifications)

## Troubleshooting

### "No handler found for .xwm files"

The MIME database hasn't been updated. Run:

```bash
sudo update-mime-database /usr/share/mime
```

### "Player not found"

Ensure your configured player is installed:

```bash
# For Flatpak
flatpak info org.gnome.Decibels

# For native
which totem
```

### Files don't open on double-click

Update the desktop database:

```bash
sudo update-desktop-database /usr/share/applications
```

### Debug mode

For detailed logging:

```bash
xwm-player --debug music.xwm
```

## File Format Notes

### XWM (xWMA)

- RIFF-based container with WMAv2 audio
- Magic bytes: `RIFF....XWMA`
- FFmpeg has native demuxer support since 2011

### FUZ

- Bethesda's voice container format
- Structure: `FUZE` header + lip-sync data + xWMA audio
- The handler extracts the xWMA portion before conversion

## License

Part of DistinctionOS. See repository for license details.

## Roadmap

- [ ] Batch conversion utility
- [ ] Nautilus right-click integration
- [ ] XMA (Xbox Media Audio) support
- [ ] LIP file extraction/viewing
- [ ] Progress bar for large files

---

*Crafted with care for DistinctionOS*
