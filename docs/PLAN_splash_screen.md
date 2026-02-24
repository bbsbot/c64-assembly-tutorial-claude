# Plan: Multicolor Bitmap Splash Screen

## Context
Phase 4 (step-through execution) is done and committed. The user wants a splash screen displayed for ~3 seconds at startup using `docs/c64_tutor_splash_main.png.png` (1024x1024 RGBA, not tiled). C64 multicolor bitmap mode, standard 16-color palette. A build flag ensures `bash test.sh` still passes with the splash skipped.

## Memory Layout (VIC Bank 2: $8000-$BFFF)

| Address | Size | Contents |
|---------|------|----------|
| `$7400` | ~200B | `splash.asm` — display routine |
| `$8000-$83E7` | 1000B | Color RAM source (copied to $D800 at runtime) |
| `$8C00-$8FE7` | 1000B | Screen RAM (VIC reads directly) |
| `$A000-$BF3F` | 8000B | Bitmap data (VIC reads directly) |

VIC config: `$DD00` bits 0-1=`%01` (bank 2), `$D018`=`$38` (screen at +$0C00, bitmap at +$2000), `$D011` bit 5 on (BMM), `$D016` bit 4 on (MCM).

## Steps

### Step 1: Python converter — `scripts/convert_splash.py`
- Resize 1024x1024 → 160x200 (multicolor resolution) using Lanczos
- Map each pixel to nearest C64 color (Euclidean RGB distance, VICE default palette)
- Pick global bg color (most frequent overall)
- Per 4×8 cell: pick 3 most frequent non-bg colors → encode bitmap pairs (00/01/10/11), screen RAM (color1<<4|color2), color RAM (color3)
- Output: `assets/splash_bitmap.bin` (8000B), `assets/splash_screen.bin` (1000B), `assets/splash_color.bin` (1000B)
- Print bg color index

### Step 2: Add constants — `src/constants.asm`
- `SPLASH_BG_COLOR` (from converter output)
- `SPLASH_FRAMES = 150` (~3 sec at 50Hz)
- VIC register labels: `VIC_D011=$D011`, `VIC_D016=$D016`, `VIC_D018=$D018`, `CIA2_PORTA=$DD00`

### Step 3: Splash data — new `src/splash_data.asm`
- `.pc=$8000` → `.import binary "../assets/splash_color.bin"`
- `.pc=$8C00` → `.import binary "../assets/splash_screen.bin"`
- `.pc=$A000` → `.import binary "../assets/splash_bitmap.bin"`
- Segment bound asserts

### Step 4: Display routine — new `src/splash.asm` at `$7400`
- `splash_show`:
  1. Wait for vblank
  2. Copy 1000 bytes from $8000 → $D800 (color RAM, unrolled 4×256 + remainder)
  3. Switch VIC bank 2, $D018=$38, enable BMM+MCM, $D021=bg
  4. Wait 150 frames with fire/space early-skip (poll $DC00 bit 4 + GETIN for $20)
  5. Restore: bank 0, text mode, $D018=$14, $D021=black, clear screen

### Step 5: Integration — `src/main.asm`
- `cmdLineVars` check: `:SKIP_SPLASH=1` → `.var` flag
- Wrap `jsr Splash.splash_show` + both imports in `#if` guard
- Update memory map comment

### Step 6: Test skip — `test.sh` line 29
- Change: `$KICKASS src/main.asm -o "$PRG" -symbolfile :SKIP_SPLASH=1`

### Step 7: Build & verify
- Full build (no skip): verify 3-sec splash in VICE
- `bash test.sh` (with skip): golden still passes

## Files

| File | Action |
|------|--------|
| `scripts/convert_splash.py` | NEW |
| `assets/splash_bitmap.bin` | NEW (generated) |
| `assets/splash_screen.bin` | NEW (generated) |
| `assets/splash_color.bin` | NEW (generated) |
| `src/splash.asm` | NEW |
| `src/splash_data.asm` | NEW |
| `src/constants.asm` | MODIFY |
| `src/main.asm` | MODIFY |
| `test.sh` | MODIFY |
