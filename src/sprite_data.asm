// ============================================================
// sprite_data.asm — Robot sprite bitmap (64 bytes at $2000)
// ============================================================
// Sprite 0 data pointer: $07F8 = 128  ($2000 / 64 = $80 = 128)
// This MUST be at a 64-byte aligned address.
// Single-colour, 24×21 pixels (3 bytes × 21 rows + 3 padding).
// ============================================================
.filenamespace SpriteData

.pc = $2000 "Sprite0"

// 24×21 single-colour robot sprite
// Each row = 3 bytes (24 bits)
// Pixel layout: 1=sprite colour, 0=transparent
sprite0_data:
    //       byte0    byte1    byte2    description
    .byte %00000000,%00111100,%00000000  // row 0:  head top
    .byte %00000000,%01111110,%00000000  // row 1:  head
    .byte %00000000,%11011011,%00000000  // row 2:  eyes
    .byte %00000000,%01111110,%00000000  // row 3:  head
    .byte %00000000,%00111100,%00000000  // row 4:  head bottom
    .byte %00000001,%11111111,%10000000  // row 5:  shoulders
    .byte %00000011,%11111111,%11000000  // row 6:  body top
    .byte %00000011,%10111101,%11000000  // row 7:  body / buttons
    .byte %00000011,%11111111,%11000000  // row 8:  body
    .byte %00000011,%11111111,%11000000  // row 9:  body
    .byte %00000001,%11111111,%10000000  // row 10: body bottom
    .byte %00000000,%11111111,%00000000  // row 11: waist
    .byte %00000001,%11111111,%10000000  // row 12: hips
    .byte %00000011,%00000000,%11000000  // row 13: legs
    .byte %00000011,%00000000,%11000000  // row 14: legs
    .byte %00000011,%00000000,%11000000  // row 15: legs
    .byte %00000011,%00000000,%11000000  // row 16: legs
    .byte %00000011,%00000000,%11000000  // row 17: lower legs
    .byte %00000011,%00000000,%11000000  // row 18: lower legs
    .byte %00000111,%10000000,%11100000  // row 19: feet
    .byte %00000111,%10000000,%11100000  // row 20: feet
    .byte $00,$00,$00                    // padding byte (64th byte unused)

.assert "Sprite0 is exactly 64 bytes", * - sprite0_data, 64
.assert "Sprite segment fits", * <= $2800, true
