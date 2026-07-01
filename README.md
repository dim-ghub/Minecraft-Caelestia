# Caelestia Minecraft Resource Pack Generator

This script generates a customized Minecraft resource pack by recoloring textures using Caelestia.

It automatically downloads the Catppuccin resource pack from Modrinth and recolors it to match your current Caelestia color scheme.

---

## Setup

Install using `pkgit`:

```bash
pkgit -i dim-ghub/Minecraft-Caelestia
```
or clone this repository and run:
```bash
pkgit -i .
```

The installer will:
1. Download your chosen Catppuccin flavor and accent color from Modrinth
2. Set up the posthook scripts
3. Configure `~/.config/caelestia/cli.json` to run automatically on wallpaper changes

---

## Dependencies

- rsync
- python3
- numpy
- Pillow
- ydotool
- jq
- hyprctl
- curl
- unzip

---

## How It Works

1. **Color Scheme**
   - Gets colors directly from `caelestia scheme get`
   - Maps Catppuccin palette colors to your current Caelestia theme colors

2. **Recolored Pack**
   - Generated resource pack is saved to `~/.local/state/caelestia/theme/`
   - Symlinks are created from Minecraft resource pack directories to this location

3. **File Processing**
   - Recursively scans the source resource pack
   - Image files (`.png`, `.jpg`) are recolored using a lookup table
   - Non-image files are copied unchanged
   - The LUT is cached for instant subsequent runs

4. **Verbose Mode**
   - If run with `-v`, logs every action to the terminal

---

## Usage

### Add resource pack directories:

```bash
scripts/add-output-dir.sh ~/.minecraft/resourcepacks
scripts/add-output-dir.sh ~/instances/forge/resourcepacks ~/instances/fabric/resourcepacks
```

### Manual recolor:

```bash
~/.local/bin/posthooks/minecraft.sh
```

### Verbose logging:

```bash
~/.local/bin/posthooks/minecraft.sh -v
```

### Uninstall:

```bash
pkgit -r minecraft-caelestia
```

---

## File Structure

```
~/.local/bin/posthooks/
├── minecraft.sh                    # Main posthook script
└── minecraft/
    ├── recolor.py                  # Python recoloring engine
    ├── lut.npy                     # Cached lookup table (generated at runtime)
    └── RP/                         # Source resource pack (Catppuccin)

~/.local/state/caelestia/theme/    # Recolored resource pack

~/.config/caelestia/cli.json       # Caelestia CLI config (posthook auto-configured)
```
