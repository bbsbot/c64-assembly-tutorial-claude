// ============================================================
// splash_data.asm — Multicolor bitmap splash screen data
// ============================================================
// Placed in VIC Bank 2 ($8000-$BFFF):
//   $8000-$83E7  Color RAM source (copied to $D800 at runtime)
//   $8C00-$8FE7  Screen RAM (VIC reads directly)
//   $A000-$BF3F  Bitmap data (VIC reads directly)
// ============================================================

.filenamespace SplashData

// Color RAM source data (1000 bytes at $8000)
.pc = $8000 "Splash Color RAM"
color_data:
    .import binary "../assets/splash_color.bin"
.assert "splash color fits", * <= $83E8, true

// Screen RAM (1000 bytes at $8C00)
.pc = $8C00 "Splash Screen RAM"
screen_data:
    .import binary "../assets/splash_screen.bin"
.assert "splash screen fits", * <= $8FE8, true

// Bitmap data (8000 bytes at $A000)
.pc = $A000 "Splash Bitmap"
bitmap_data:
    .import binary "../assets/splash_bitmap.bin"
.assert "splash bitmap fits", * <= $BF40, true
