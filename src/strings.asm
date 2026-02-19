// ============================================================
// strings.asm — UI text stored as C64 screen codes
// ============================================================
// Screen codes:  uppercase A-Z = $01-$1A   space = $20
// PETSCII:       uppercase A-Z = $41-$5A   space = $20
// Stored as raw .byte sequences (NOT .text) to write directly
// to screen RAM.  Each string preceded by its length byte.
// ============================================================
.filenamespace Strings

.pc = $3800 "Strings"

// Helper macro: emit length-prefixed screen-code string
// Usage:  str_title: .byte <len>, <sc0>, <sc1>, ...

// -----------------------------------------------------------------------
// Title row (row 0) — 38 chars centred in 40 cols
// "      C64 BLOCK TUTOR  V1.0         "
//  pos 0: 6 spaces, then "C64 BLOCK TUTOR  V1.0", then spaces to col 39
// Screen codes: C=$03 6=$36 4=$34 space=$20
//   B=$02 L=$0C O=$0F C=$03 K=$0B  T=$14 U=$15 T=$14 O=$0F R=$12
//   V=$16 1=$31 . (period=$2E) 0=$30
// -----------------------------------------------------------------------
str_title:
    .byte 38
    //      6 spaces
    .byte $20,$20,$20,$20,$20,$20
    //  C    6    4   sp   B    L    O    C    K   sp   T    U    T    O    R
    .byte $03,$36,$34,$20,$02,$0C,$0F,$03,$0B,$20,$14,$15,$14,$0F,$12
    //  sp  sp   V    1    .    0
    .byte $20,$20,$16,$31,$2E,$30
    //  17 trailing spaces to fill row
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20

// -----------------------------------------------------------------------
// Panel headers (row 2)
// Left:  " PALETTE  " (cols 0–17)
// Right: " YOUR PROGRAM" (cols 20–38)
// -----------------------------------------------------------------------
str_hdr_palette:
    .byte 18
    .byte $20
    //  P    A    L    E    T    T    E
    .byte $10,$01,$0C,$05,$14,$14,$05
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20

str_hdr_program:
    .byte 19
    .byte $20
    //  Y    O    U    R   sp   P    R    O    G    R    A    M
    .byte $19,$0F,$15,$12,$20,$10,$12,$0F,$07,$12,$01,$0D
    .byte $20,$20,$20,$20,$20,$20,$20

// -----------------------------------------------------------------------
// Block names (used by palette list + program panel)
// Each 12 chars wide (padded with spaces)
// -----------------------------------------------------------------------
str_block_set_border:
    .byte 12
    //  S    E    T   sp   B    O    R    D    E    R   sp  sp
    .byte $13,$05,$14,$20,$02,$0F,$12,$04,$05,$12,$20,$20

str_block_set_bg:
    .byte 12
    //  S    E    T   sp   B    G   sp  sp  sp  sp  sp  sp
    .byte $13,$05,$14,$20,$02,$07,$20,$20,$20,$20,$20,$20

str_block_print:
    .byte 12
    //  P    R    I    N    T   sp  sp  sp  sp  sp  sp  sp
    .byte $10,$12,$09,$0E,$14,$20,$20,$20,$20,$20,$20,$20

str_block_show_spr:
    .byte 12
    //  S    H    O    W   sp   S    P    R    I    T    E   sp
    .byte $13,$08,$0F,$17,$20,$13,$10,$12,$09,$14,$05,$20

str_block_wait:
    .byte 12
    //  W    A    I    T   sp  sp  sp  sp  sp  sp  sp  sp
    .byte $17,$01,$09,$14,$20,$20,$20,$20,$20,$20,$20,$20

str_block_loop:
    .byte 12
    //  L    O    O    P   sp   B    A    C    K   sp  sp  sp
    .byte $0C,$0F,$0F,$10,$20,$02,$01,$03,$0B,$20,$20,$20

// Table of block-name pointers (lo, hi pairs) — 6 entries
block_name_ptrs_lo:
    .byte <str_block_set_border, <str_block_set_bg, <str_block_print
    .byte <str_block_show_spr,   <str_block_wait,   <str_block_loop

block_name_ptrs_hi:
    .byte >str_block_set_border, >str_block_set_bg, >str_block_print
    .byte >str_block_show_spr,   >str_block_wait,   >str_block_loop

// -----------------------------------------------------------------------
// Colour names — each 8 chars wide (padded)
// Used in the value bar for SET BORDER / SET BG
// -----------------------------------------------------------------------
str_col_black:   .byte 8, $02,$0C,$01,$03,$0B,$20,$20,$20   // BLACK
str_col_white:   .byte 8, $17,$08,$09,$14,$05,$20,$20,$20   // WHITE
str_col_red:     .byte 8, $12,$05,$04,$20,$20,$20,$20,$20   // RED
str_col_cyan:    .byte 8, $03,$19,$01,$0E,$20,$20,$20,$20   // CYAN
str_col_purple:  .byte 8, $10,$15,$12,$10,$0C,$05,$20,$20   // PURPLE
str_col_green:   .byte 8, $07,$12,$05,$05,$0E,$20,$20,$20   // GREEN
str_col_blue:    .byte 8, $02,$0C,$15,$05,$20,$20,$20,$20   // BLUE
str_col_yellow:  .byte 8, $19,$05,$0C,$0C,$0F,$17,$20,$20   // YELLOW
str_col_orange:  .byte 8, $0F,$12,$01,$0E,$07,$05,$20,$20   // ORANGE
str_col_brown:   .byte 8, $02,$12,$0F,$17,$0E,$20,$20,$20   // BROWN
str_col_lt_red:  .byte 8, $0C,$14,$12,$05,$04,$20,$20,$20   // LT RED
str_col_dk_grey: .byte 8, $04,$0B,$07,$12,$19,$20,$20,$20   // DK GREY
str_col_md_grey: .byte 8, $0D,$04,$07,$12,$19,$20,$20,$20   // MD GREY
str_col_lt_grn:  .byte 8, $0C,$14,$07,$12,$0E,$20,$20,$20   // LT GRN
str_col_lt_blu:  .byte 8, $0C,$14,$02,$0C,$15,$20,$20,$20   // LT BLU
str_col_lt_gry:  .byte 8, $0C,$14,$07,$12,$19,$20,$20,$20   // LT GRY

color_name_ptrs_lo:
    .byte <str_col_black,  <str_col_white,  <str_col_red,    <str_col_cyan
    .byte <str_col_purple, <str_col_green,  <str_col_blue,   <str_col_yellow
    .byte <str_col_orange, <str_col_brown,  <str_col_lt_red, <str_col_dk_grey
    .byte <str_col_md_grey,<str_col_lt_grn, <str_col_lt_blu, <str_col_lt_gry

color_name_ptrs_hi:
    .byte >str_col_black,  >str_col_white,  >str_col_red,    >str_col_cyan
    .byte >str_col_purple, >str_col_green,  >str_col_blue,   >str_col_yellow
    .byte >str_col_orange, >str_col_brown,  >str_col_lt_red, >str_col_dk_grey
    .byte >str_col_md_grey,>str_col_lt_grn, >str_col_lt_blu, >str_col_lt_gry

// -----------------------------------------------------------------------
// Char names for PRINT block ("A" .. "Z", 2 chars each)
// Only first letter shown in value bar: A, B, C ... Z
// -----------------------------------------------------------------------
// We store just the screen-code of each letter A-Z = $01..$1A

// -----------------------------------------------------------------------
// Status messages (row 24) — 38 chars, space-padded
// -----------------------------------------------------------------------
str_status_ready:
    .byte 38
    //  R    E    A    D    Y   sp   F    1   sp   T    O   sp   R    U    N
    .byte $12,$05,$01,$04,$19,$20,$06,$31,$20,$14,$0F,$20,$12,$15,$0E
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20

str_status_added:
    .byte 38
    //  B    L    O    C    K   sp   A    D    D    E    D   !
    .byte $02,$0C,$0F,$03,$0B,$20,$01,$04,$04,$05,$04,$21
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20

str_status_full:
    .byte 38
    //  P    R    O    G    R    A    M   sp   F    U    L    L   !
    .byte $10,$12,$0F,$07,$12,$01,$0D,$20,$06,$15,$0C,$0C,$21
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20

str_status_running:
    .byte 38
    //  R    U    N    N    I    N    G   ...  R    E    S    T    O    R    E   sp   T    O   sp   S    T    O    P
    .byte $12,$15,$0E,$0E,$09,$0E,$07,$20,$12,$05,$13,$14,$0F,$12,$05,$20,$14,$0F,$20,$13,$14,$0F,$10
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20

str_status_cleared:
    .byte 38
    //  P    R    O    G    R    A    M   sp   C    L    E    A    R    E    D
    .byte $10,$12,$0F,$07,$12,$01,$0D,$20,$03,$0C,$05,$01,$12,$05,$04
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20

str_status_removed:
    .byte 38
    //  B    L    O    C    K   sp   R    E    M    O    V    E    D
    .byte $02,$0C,$0F,$03,$0B,$20,$12,$05,$0D,$0F,$16,$05,$04
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20

str_status_editing:
    .byte 38
    //  E    D    I    T    I    N    G   sp   V    A    L    U    E
    .byte $05,$04,$09,$14,$09,$0E,$07,$20,$16,$01,$0C,$15,$05
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20

// -----------------------------------------------------------------------
// Key-hint row (rows 22–23) — fixed strings
// -----------------------------------------------------------------------
str_hint1:
    .byte 38
    //  F    1   :   R    U    N   sp  sp   F    3   :   C    L    E    A    R   sp  sp   D    E    L   :   R    E    M    O    V    E
    .byte $06,$31,$3A,$12,$15,$0E,$20,$20,$06,$33,$3A,$03,$0C,$05,$01,$12,$20,$20,$04,$05,$0C,$3A,$12,$05,$0D,$0F,$16,$05
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20

str_hint2:
    .byte 38
    //  J    O    Y   :   M    O    V    E   sp  sp   F    I    R    E   :   S    E    L    /    E    D    I    T
    .byte $0A,$0F,$19,$3A,$0D,$0F,$16,$05,$20,$20,$06,$09,$12,$05,$3A,$13,$05,$0C,$2F,$05,$04,$09,$14
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20

// -----------------------------------------------------------------------
// Value-bar label prefix (row 20): " VALUE: "
// -----------------------------------------------------------------------
str_value_label:
    .byte 8
    //  sp   V    A    L    U    E   :   sp
    .byte $20,$16,$01,$0C,$15,$05,$3A,$20

// -----------------------------------------------------------------------
// Cursor glyph (screen code $1E = solid right-arrow / cursor block)
// -----------------------------------------------------------------------
.label SC_CURSOR = $1E   // filled right-arrow — used as selection indicator
.label SC_EMPTY_SLOT = $2D   // dash — shown in empty program slots

.assert "Strings segment fits", * <= $4000, true
