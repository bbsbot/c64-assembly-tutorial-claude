# Skill: Aseprite to C64 Asset Pipeline

## Purpose
To provide Claude with the logic to convert modern graphics files into C64-compatible binary data. This ensures that art created in Aseprite can be seamlessly integrated into Kick Assembler projects.

## C64 Graphics Constraints
Claude must enforce these limits during the conversion process:
- **Sprites:** 24x21 pixels. 
    - *Single Color:* 1 transparency + 1 color.
    - *Multicolor:* 1 transparency + 3 colors (pixels are double-wide).
- **Characters:** 8x8 pixels.
- **Bitmaps:** 320x200 (High-res) or 160x200 (Multicolor).

## Automation Strategies
When the user provides an image or an Aseprite file, Claude should recommend:

### 1. The "KickAss Binary" Import
If the file is already a raw binary:
```kickasm
* = $2000 "Sprites"
.import binary "assets/hero_sprites.bin"

```

### 2. Custom Python/Node Scripts

Claude should offer to write a quick bridge script that:

* Reads an Aseprite `.json` export or `.png`.
* Maps RGB colors to the 16-color C64 palette.
* Packs bits into C64 format (e.g., 63 bytes per sprite + 1 padding byte).

### 3. Palette Mapping

Claude must use the standard Pepto or Vice palette for conversions:

* $0: Black, $1: White, $2: Red, $3: Cyan... (up to $F: Light Grey).

## Workflow for the User

1. **Design:** Create art in Aseprite using a 16-color C64 palette.
2. **Export:** Export as a PNG or use the `Aseprite-to-C64` plugin.
3. **Assemble:** Claude writes the `#import` logic in the main `.asm` file to point to the `assets/` folder.

## Expert Tip: Sprite Sheets

If the user provides a sprite sheet, Claude should calculate the memory offsets:
`Sprite_Address = Base_Address + (Sprite_Index * 64)`
