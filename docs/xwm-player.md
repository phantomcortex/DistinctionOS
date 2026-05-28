# XWM Player

A transparent wrapper that lets you double-click Bethesda game audio files (`.xwm`, `.fuz`) and have them play in any standard audio player on Linux. Ships as part of DistinctionOS.

---

## Overview

XWM (xWMA) is Microsoft's Xbox Windows Media Audio format used throughout Bethesda games:
- The Elder Scrolls V: Skyrim
- Fallout 4 / Fallout 76
- Starfield

FUZ is Bethesda's voice container — it wraps xWMA audio together with lip-sync data.

Neither format is natively playable by most Linux audio players. XWM Player converts them on the fly to WAV (or another configured format) and opens the result in your player of choice.

---

## Features

- **Double-click to play** — MIME type registration makes it transparent via any file manager
- **Flatpak-aware** — Works with Flatpak audio players (Decibels is the default)
- **FUZ extraction** — Strips the lip-sync header and converts the embedded xWMA
- **Conversion mode** — Convert files to keep without playback
- **Configurable** — System, local, and user config hierarchy
- **Extensible handlers** — Add support for new formats via shell scripts
- **Stale temp cleanup** — Residual temp files from previous sessions are purged at startup

---

## File Locations

```
/usr/bin/xwm-player                                  # Main executable
/usr/share/distinctionos/xwm-player/config           # System default config
/usr/share/distinctionos/xwm-player/handlers/        # Format handler directory
/usr/share/applications/xwm-player.desktop           # Desktop file (MIME handler)
/usr/share/mime/packages/xwm-player.xml              # MIME type registrations
/var/log/distinctionos/xwm-player.log                # Log file
```

**Override paths (user-configurable):**

| Precedence | Path |
|------------|------|
| System (lowest) | `/usr/share/distinctionos/xwm-player/config` |
| Local | `/usr/local/share/distinctionos/xwm-player/config` |
| User (highest) | `~/.config/distinctionos/xwm-player/config` |

---

## Usage

### Playing Files

Double-click any `.xwm` or `.fuz` file in Nautilus, or from the terminal:

```bash
xwm-player music.xwm
xwm-player voice.fuz
```

### Converting Files

```bash
# Convert to WAV (default)
xwm-player --convert input.xwm output.wav

# Convert to OGG
xwm-player --convert input.xwm output.ogg

# Convert a FUZ voice file to MP3
xwm-player --convert voice.fuz voice.mp3
```

### Cleanup Temp Files

```bash
xwm-player --cleanup
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `--desktop` | Mark as desktop-invoked — suppresses manual-mode notifications |
| `--convert <in> <out>` | Convert without playing |
| `--cleanup` | Remove all temporary files |
| `--format <fmt>` | Override output format: `ogg`, `mp3`, `flac`, `wav` |
| `--player <app>` | Override the audio player |
| `--no-gui` | Disable GUI error dialogues |
| `--debug` | Enable verbose debug logging to stderr |
| `--help` | Show help |
| `--version` | Show version |

---

## Configuration

Create `~/.config/distinctionos/xwm-player/config` to override any system defaults. The file is key-value format:

```bash
# Use VLC instead of Decibels
PLAYER_COMMAND="org.videolan.VLC"

# Convert to OGG instead of WAV
OUTPUT_FORMAT="ogg"
AUDIO_QUALITY="7"
```

### Key Options

| Option | Default | Description |
|--------|---------|-------------|
| `PLAYER_COMMAND` | `org.gnome.Decibels` | Audio player (Flatpak ID or native command) |
| `PLAYER_TYPE` | `native` | `flatpak`, `native`, or `auto` |
| `FALLBACK_PLAYER` | `org.gnome.Totem` | Used if primary player unavailable |
| `OUTPUT_FORMAT` | `wav` | Conversion format: `wav`, `ogg`, `mp3`, `flac` |
| `AUDIO_QUALITY` | `6` | OGG: 0–10 quality; MP3: bitrate kbps; FLAC: 0–12 level; WAV: ignored |
| `PRESERVE_SAMPLE_RATE` | `true` | Keep original sample rate; `false` resamples to 44100 Hz |
| `CLEANUP_MODE` | `on-exit` | `on-exit`, `immediate`, `manual`, or `never` |
| `CACHE_CONVERSIONS` | `false` | Cache by file checksum in `~/.cache/distinctionos/xwm-player/` |
| `GUI_ERRORS` | `true` | Show zenity/kdialog/notify-send on error |
| `LOG_LEVEL` | `error` | `none`, `error`, `info`, or `debug` |
| `TEMP_DIR` | `$XDG_RUNTIME_DIR/xwm-player` | Where temp files go (cleared on logout) |
| `CONVERSION_TIMEOUT` | `300` | FFmpeg timeout in seconds (`0` = no limit) |

---

## Supported Formats

| Extension | Format | Description |
|-----------|--------|-------------|
| `.xwm` | xWMA | Microsoft's Xbox Windows Media Audio — Skyrim music, ambient, etc. |
| `.fuz` | Bethesda FUZ | Voice container: xWMA audio + lip-sync data |

### Format Notes

**XWM** is a RIFF container using WMAv2 encoding. FFmpeg has had a native xWMA demuxer since 2011.

**FUZ** structure: `FUZE` magic (4 bytes) → version (4 bytes) → lip size (4 bytes) → lip data → xWMA data. The built-in handler skips the lip data and feeds the xWMA portion directly to FFmpeg.

---

## Adding Format Support

Create a handler script under `/usr/share/distinctionos/xwm-player/handlers/` (or the user equivalent):

```bash
# /usr/share/distinctionos/xwm-player/handlers/myformat.sh
handle_myformat() {
    local input_file="$1"
    local output_file="$2"
    ffmpeg -nostdin -y -i "$input_file" "$output_file"
}
```

Register it in your config:

```bash
HANDLER_MYF="handle_myformat"
```

See `handlers/example.sh.sample` for full documentation and best practices.

---

## Dependencies

- **Required:** `bash`, `ffmpeg`
- **Optional:** `zenity` or `kdialog` (GUI error dialogues), `notify-send` (desktop notifications)

---

## Troubleshooting

**Double-click does nothing / opens wrong app**

The MIME database may need refreshing:
```bash
sudo update-mime-database /usr/share/mime
sudo update-desktop-database /usr/share/applications
```

**"No handler found for .xwm files"**

Check that `HANDLER_XWM` is set in the system config:
```bash
grep HANDLER_XWM /usr/share/distinctionos/xwm-player/config
```

**"Player not found"**

Verify your configured player is installed:
```bash
flatpak info org.gnome.Decibels
```

**Debug mode**

```bash
xwm-player --debug music.xwm
```

Logs go to stderr and `/var/log/distinctionos/xwm-player.log`.

---

## Roadmap

- [ ] Batch conversion utility
- [ ] Nautilus right-click context menu integration
- [ ] XMA (Xbox Media Audio) support
- [ ] LIP file extraction/viewing
- [ ] Progress bar for large files

---

**Version:** 1.0.2
