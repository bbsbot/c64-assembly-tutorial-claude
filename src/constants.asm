// ============================================================
// constants.asm — Hardware addresses, ZP allocation, IDs
// ============================================================
// Imported by main.asm via:  #import "constants.asm"
// ============================================================

// ------------------------------------------------------------
// Zero Page variables ($02–$10)
// ------------------------------------------------------------
.label zp_state       = $02   // current UI state (STATE_*)
.label zp_pal_cursor  = $03   // palette panel cursor (0–5)
.label zp_pgm_cursor  = $04   // program panel cursor (0–15)
.label zp_slots_used  = $05   // number of filled slots
.label zp_joy_prev    = $06   // joystick reading previous frame (inverted)
.label zp_joy_curr    = $07   // joystick reading this frame (inverted)
.label zp_joy_edge    = $08   // edge-detect: bits set on NEW press only
.label zp_edit_val    = $09   // param value being edited
.label zp_edit_slot   = $0A   // slot index being edited
.label zp_ptr_lo      = $0B   // general 16-bit pointer lo
.label zp_ptr_hi      = $0C   // general 16-bit pointer hi
.label zp_cg_ptr_lo   = $0D   // codegen write pointer lo
.label zp_cg_ptr_hi   = $0E   // codegen write pointer hi
.label zp_frame       = $0F   // frame counter (0–255 wrapping)
.label zp_last_key    = $10   // last key from GETIN

// Scratch ZP for generated code only (never used by tutor)
.label zp_gen_lo      = $FE
.label zp_gen_hi      = $FF

// ------------------------------------------------------------
// VIC-II registers
// ------------------------------------------------------------
.label VIC_SPR0_X     = $D000
.label VIC_SPR0_Y     = $D001
.label VIC_SPR_ENA    = $D015  // sprite enable bits
.label VIC_SPR_MSIGX  = $D010  // sprite X MSB
.label VIC_BORDER     = $D020  // border colour
.label VIC_BG0        = $D021  // background colour 0
.label VIC_SPR0_COLOR = $D027  // sprite 0 colour

// ------------------------------------------------------------
// CIA registers
// ------------------------------------------------------------
.label CIA1_PORTA     = $DC00  // joystick port 2 (bits 0-4)

// ------------------------------------------------------------
// Kernal jump-table entries
// ------------------------------------------------------------
.label KERNAL_CHROUT  = $FFD2  // output char in A (PETSCII)
.label KERNAL_GETIN   = $FFE4  // read keyboard; returns char in A (0=none)

// ------------------------------------------------------------
// Memory layout labels
// ------------------------------------------------------------
.label SCREEN_RAM     = $0400
.label COLOR_RAM      = $D800
.label SPRITE0_PTR    = $07F8  // sprite 0 data pointer byte

.label SLOT_ARRAY     = $4000  // 48 bytes: 16 slots × 3 bytes
.label GEN_CODE_BUF   = $5000  // runtime generated code lands here

// ------------------------------------------------------------
// State IDs
// ------------------------------------------------------------
.label STATE_PALETTE    = 0
.label STATE_PROGRAM    = 1
.label STATE_EDIT_PARAM = 2
.label STATE_RUNNING    = 3

// ------------------------------------------------------------
// Block IDs
// ------------------------------------------------------------
.label BLOCK_SET_BORDER  = 0
.label BLOCK_SET_BG      = 1
.label BLOCK_PRINT       = 2
.label BLOCK_SHOW_SPRITE = 3
.label BLOCK_WAIT        = 4
.label BLOCK_LOOP_BACK   = 5
.label NUM_BLOCKS        = 6

// ------------------------------------------------------------
// Joystick bit masks (CIA1 port 2, active-LOW — we invert)
// After inversion: bit=1 means pressed
// ------------------------------------------------------------
.label JOY_UP    = %00000001
.label JOY_DOWN  = %00000010
.label JOY_LEFT  = %00000100
.label JOY_RIGHT = %00001000
.label JOY_FIRE  = %00010000

// ------------------------------------------------------------
// Slot constants
// ------------------------------------------------------------
.label SLOT_EMPTY     = $FF
.label MAX_SLOTS      = 16
.label SLOT_STRIDE    = 3       // bytes per slot

// ------------------------------------------------------------
// UI layout constants (column/row positions)
// ------------------------------------------------------------
.label UI_PAL_COL     = 1       // palette list start column
.label UI_PGM_COL     = 21      // program list start column
.label UI_LIST_ROW    = 4       // first list row
.label UI_LIST_ROWS   = 15      // number of visible list rows (rows 4–18)
.label UI_DIVIDER_COL = 19      // column of vertical divider │

// ------------------------------------------------------------
// Block param type codes (mirrors BlocksData values)
// ------------------------------------------------------------
.label PARAM_NONE   = 0
.label PARAM_COLOR  = 1
.label PARAM_CHAR   = 2
.label PARAM_SECS   = 3

// ------------------------------------------------------------
// Colour indices
// ------------------------------------------------------------
.label COL_BLACK      = 0
.label COL_WHITE      = 1
.label COL_RED        = 2
.label COL_CYAN       = 3
.label COL_PURPLE     = 4
.label COL_GREEN      = 5
.label COL_BLUE       = 6
.label COL_YELLOW     = 7
.label COL_ORANGE     = 8
.label COL_BROWN      = 9
.label COL_LT_RED     = 10
.label COL_DK_GREY    = 11
.label COL_MED_GREY   = 12
.label COL_LT_GREEN   = 13
.label COL_LT_BLUE    = 14
.label COL_LT_GREY    = 15

// Screen code helpers (screen RAM uses different encoding than PETSCII)
// Screen code for uppercase A = $01  (PETSCII $41 minus $40)
// Screen code for space      = $20
.label SC_SPACE       = $20
.label SC_PIPE        = $5D   // │ vertical bar (screen code for Commodore │)
.label SC_HLINE       = $C0   // ─ horizontal line (screen code)
.label SC_HLINE_THICK = $C0   // same glyph used for thick divider
