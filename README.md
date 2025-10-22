# DistinctionOS

### DistinctionOS is built upon [Bazzite](https://github.com/ublue-os/bazzite). DistinctionOS is intended as a full experience and the opposite of minimalism. 
##### Please note: I'm not a Developer, Just someone who keeps tinkering until something finally works and sometimes I learn from it. 

#### If you want to try out DistinctionOS you do so with:
```bash
sudo bootc switch ghcr.io/phantomcortex/distinctionos
```
or 
```bash
rpm-ostree rebase ostree-unverified-registry:docker://ghcr.io/phantomcortex/distinctionos:latest
```

---
## Miscellaneous packages that aren't included with bazzite
- `docker` & `docker-compose`
- `libheif-tools` (for .heic images thumbnails)
- `flatpak-builder` 
- `freerdp` (useful for [winboat](https://github.com/TibixDev/winboat) or [winapps](https://github.com/winapps-org/winapps))
- `pandoc`
- `totem-video-thumbnailer`  (Video thumbnails)
- `Cider` is Music Client for Apple Music. **NOTE:** ***This is Cider version 3. You need to purchase an license from itch.io to use it, But it should be a one-time payment. See: https://cidercollective.itch.io/cider You will still need an active Apple Music subscription to use it.***
-  `Audacity-Freeworld` is better than fedora's default audacity because it ships patent encumbered codecs that fedora can't/won't ship in their official repositories.
- [BlackBox-Terminal](https://github.com/yonasBSD/blackbox-terminal) is currently unmaintained But I still love it, Which is why it's here.
- [xpadneo](https://github.com/atar-axis/xpadneo) is here for controller input over bluetooth and support for xbox series elite controllers (which I have and use)
- [zoxide](https://github.com/ajeetdsouza/zoxide) (smart cd)
- [dysk](https://github.com/Canop/dysk) 
- Custom Image-raw thumbnailer via `dcraw` (tested with Sony's .ARW format from my own camera. Other formats untested.)
- Custom dds texture thumbnailer via `ImageMagick` (This won't work for every last texture, but should work for most.)

 ### Miscellaneous /bin
- `advcp` ( `cp` command with progress bar `advcp -g` )
- `advmv` ( `mv` command with progress bar `advmv -g` )
- `rpm-ostree-search-hl` (rpm-ostree search highlighting) (also aliased to `rosh`, use with `rosh search gcc`) 
- `xiso` renamed from: [extract-xiso](https://github.com/XboxDev/extract-xiso) 

---
## Special thanks for making this unholy creation possible
- [fedora linux](https://fedoraproject.org) and it's developers, maintainers, and it's community for being an incredible OS by default.
- [UniveralBlue](https://github.com/ublue-os) and it's developers, maintainers, and contributers for making [Bazzite](https://github.com/ublue-os/bazzite), [Bluefin](https://github.com/ublue-os/bluefin), and the [image-template](https://github.com/ublue-os/image-template).
- [Amy OS](https://github.com/astrovm/amyos) for being an example on a cleaner build system.
- [vst-name's ublue-aurora-dx](https://github.com/vst-name/ublue-aurora-dx) for being an example of working rechunker
  
## Community Examples

- [m2Giles' OS](https://github.com/m2giles/m2os)
- [bOS](https://github.com/bsherman/bos)
- [Homer](https://github.com/bketelsen/homer/)
- [Amy OS](https://github.com/astrovm/amyos)
- [VeneOS](https://github.com/Venefilyn/veneos)
