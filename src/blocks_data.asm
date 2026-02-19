// ============================================================
// blocks_data.asm — Block definition tables
// ============================================================
// Param types, min/max/default for each of the 6 blocks.
// Block names are in strings.asm; we reference them by index.
// ============================================================
.filenamespace BlocksData

.pc = $2800 "BlocksData"

// ------------------------------------------------------------
// Param type codes
// ------------------------------------------------------------
.label PARAM_NONE   = 0   // no parameter (e.g. SHOW SPRITE, LOOP BACK)
.label PARAM_COLOR  = 1   // colour index 0–15
.label PARAM_CHAR   = 2   // PETSCII printable char $41–$5A (A-Z)
.label PARAM_SECS   = 3   // seconds 1–9

// ------------------------------------------------------------
// block_param_type[6]  — one byte per block
// ------------------------------------------------------------
block_param_type:
    .byte PARAM_COLOR   // 0: SET BORDER
    .byte PARAM_COLOR   // 1: SET BG
    .byte PARAM_CHAR    // 2: PRINT
    .byte PARAM_NONE    // 3: SHOW SPRITE
    .byte PARAM_SECS    // 4: WAIT
    .byte PARAM_NONE    // 5: LOOP BACK

// ------------------------------------------------------------
// block_param_min[6]
// ------------------------------------------------------------
block_param_min:
    .byte 0             // SET BORDER  (colour 0)
    .byte 0             // SET BG
    .byte $41           // PRINT  (PETSCII 'A')
    .byte 0             // SHOW SPRITE (unused)
    .byte 1             // WAIT (1 second)
    .byte 0             // LOOP BACK (unused)

// ------------------------------------------------------------
// block_param_max[6]
// ------------------------------------------------------------
block_param_max:
    .byte 15            // SET BORDER  (colour 15)
    .byte 15            // SET BG
    .byte $5A           // PRINT  (PETSCII 'Z')
    .byte 0             // SHOW SPRITE (unused)
    .byte 9             // WAIT (9 seconds)
    .byte 0             // LOOP BACK (unused)

// ------------------------------------------------------------
// block_param_default[6]
// ------------------------------------------------------------
block_param_default:
    .byte 0             // SET BORDER → black
    .byte 5             // SET BG     → green
    .byte $48           // PRINT      → 'H' (PETSCII $48)
    .byte 0             // SHOW SPRITE (param unused)
    .byte 2             // WAIT → 2 seconds
    .byte 0             // LOOP BACK (param unused)

// ------------------------------------------------------------
// block_color_map[6] — highlight colour for each block in the
// palette list (gives each block a distinctive tint)
// ------------------------------------------------------------
block_color_map:
    .byte COL_CYAN      // SET BORDER
    .byte COL_GREEN     // SET BG
    .byte COL_YELLOW    // PRINT
    .byte COL_WHITE     // SHOW SPRITE
    .byte COL_PURPLE    // WAIT
    .byte COL_RED       // LOOP BACK

.assert "BlocksData segment fits", * <= $3000, true
