# DistinctionOS — Roadmap

Tracked goals for the image. Keep this current: per CLAUDE.md, docs are updated
in the same commit as the change they describe.

## Short-Term Goals

- [ ] **Thumbnail validation.** Verify that the thumbnailer stack actually
  produces (or correctly falls back for) thumbnails across the formats we ship,
  so a broken/missing thumbnailer is caught at build time rather than by a user
  staring at a frozen Nautilus. Coverage to validate:
  - **Audio:** opus, mp3, m4a, flac
  - **Video:** mkv, mov, mp4, avi
  - **Image:** jpeg, jxl, webp, gif, heic

## Long-Term Goals

- [ ] **file-roller BSA/BA2 support.** Bethesda's BSA (Oblivion/Skyrim) and BA2
  (Fallout 4/Starfield) archive formats are widely encountered by modders but
  are invisible to GNOME's archive manager. A plugin or fork would let users
  browse and extract mod archives natively without resorting to command-line
  tools or Windows-only utilities.

- [ ] **Nautilus fork.** Nautilus frequently freezes while loading/generating
  thumbnails — a regression that has persisted since at least GNOME 46. A
  downstream fork would let us fix this and other long-standing papercuts
  rather than waiting on upstream.

## Notes

- The canonical engineering roadmap historically lived in
  `docs/developer.md` (§ Roadmap). New goals go here; migrate the developer.md
  list when convenient.
