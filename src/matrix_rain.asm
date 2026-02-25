// ============================================================
// matrix_rain.asm — Matrix Rain transition for ASM View entry
// ============================================================
// Called instead of asm_view_render when pressing T to enter
// ASM View. Pre-renders the view into a shadow buffer, then
// reveals it column-by-column with "digital rain" characters
// and a descending SID sweep on voice 2.
//
// Memory:
//   $6200  SHADOW_SCREEN  — 1000-byte copy of final screen
//   $65E8  RAIN_COL_STATE — 40 cols × 4 bytes:
//          +0 = delay (frames before column starts)
//          +1 = head_row (current rain head position, 0-24)
//          +2 = phase (0=waiting, 1=raining, 2=done)
//          +3 = random seed per-column
// ============================================================

.filenamespace MatrixRain

.pc = $7800 "MatrixRain"

// Column state offsets
.label CS_DELAY  = 0
.label CS_HEAD   = 1
.label CS_PHASE  = 2
.label CS_SEED   = 3
.label CS_STRIDE = 4

// Animation constants
.label RAIN_ROWS   = 25     // full screen height
.label RAIN_COLS   = 40
.label TOTAL_FRAMES = 90    // ~1.8 sec at 50 Hz PAL
.label SETTLE_DIST  = 3     // rows behind head that settle to final char

// SID voice 2 registers
.label SID_V2_FREQ_LO  = $D407
.label SID_V2_FREQ_HI  = $D408
.label SID_V2_PW_LO    = $D409
.label SID_V2_PW_HI    = $D40A
.label SID_V2_CTRL     = $D40B
.label SID_V2_AD        = $D40C
.label SID_V2_SR        = $D40D
.label SID_VOLUME       = $D418

// ============================================================
// matrix_rain_transition
// Main entry point — replaces jsr AsmView.asm_view_render
// Inputs:  program must be compiled (codegen done)
// Outputs: screen shows ASM view with syntax colours
// Clobbers: A, X, Y, all ZP pointers
// ============================================================
matrix_rain_transition:
    // --- Step 1: Blank screen to hide pre-render ---
    lda VIC_D011
    and #$EF                // clear bit 4 (screen off)
    sta VIC_D011

    // --- Step 2: Render ASM view normally into SCREEN_RAM ---
    jsr AsmView.asm_view_render

    // --- Step 3: Copy SCREEN_RAM → SHADOW_SCREEN (1000 bytes) ---
    // Copy 4 pages (1024 bytes, slightly over 1000 — harmless)
    ldx #0
!copy_loop:
    lda SCREEN_RAM, x
    sta SHADOW_SCREEN, x
    lda SCREEN_RAM + $100, x
    sta SHADOW_SCREEN + $100, x
    lda SCREEN_RAM + $200, x
    sta SHADOW_SCREEN + $200, x
    lda SCREEN_RAM + $300, x
    sta SHADOW_SCREEN + $300, x
    inx
    bne !copy_loop-

    // --- Step 4: Clear SCREEN_RAM with spaces ---
    lda #SC_SPACE
    ldx #0
!clear_loop:
    sta SCREEN_RAM, x
    sta SCREEN_RAM + $100, x
    sta SCREEN_RAM + $200, x
    sta SCREEN_RAM + $300, x
    inx
    bne !clear_loop-

    // Set all COLOR_RAM to green (rain colour)
    lda #COL_GREEN
    ldx #0
!clear_color:
    sta COLOR_RAM, x
    sta COLOR_RAM + $100, x
    sta COLOR_RAM + $200, x
    sta COLOR_RAM + $300, x
    inx
    bne !clear_color-

    // Unblank screen
    lda VIC_D011
    ora #$10                // set bit 4 (screen on)
    sta VIC_D011

    // --- Step 5: Init column state table ---
    jsr init_column_states

    // --- Step 6: Init SID voice 2 ---
    jsr init_sid_sweep

    // --- Step 7: Frame loop ---
    lda #TOTAL_FRAMES
    sta rain_frame_counter

!frame_loop:
    // Wait for raster line 250 (frame sync)
!wait_raster:
    lda $D012
    cmp #250
    bne !wait_raster-

    // Keep SID music playing if splash was shown
    // (SID_PLAY is only available when splash is included;
    //  the .if guard uses the same cmdLineVars check as main.asm)
    .var MR_SKIP_SPLASH = cmdLineVars.containsKey("SKIP_SPLASH") ? cmdLineVars.get("SKIP_SPLASH").asNumber() : 0
    .if (MR_SKIP_SPLASH == 0) {
        jsr SID_PLAY
    }

    // Update all 40 columns
    jsr update_columns

    // Sweep SID frequency down
    jsr update_sid_sweep

    // Decrement frame counter
    dec rain_frame_counter
    bne !frame_loop-

    // --- Step 8: Finalize ---
    // Force all remaining chars to final state
    jsr finalize_screen

    // Apply syntax highlighting colours
    jsr AsmView.colorize_code_area

    // Colour non-code rows (title=white, header=cyan, etc.)
    jsr colour_title_rows

    // Silence SID voice 2
    jsr silence_sid

    rts

// ============================================================
// init_column_states
// Sets up 40-column state table with staggered delays.
// Delay = (col / 4) + (PRNG & $03) → wave + jitter
// Clobbers: A, X, Y
// ============================================================
init_column_states:
    lda #40
    sta zp_rain_active      // 40 columns still animating

    ldx #0                  // column index
    ldy #0                  // state table offset
!init_loop:
    // Calculate delay: col/4
    txa
    lsr
    lsr                     // A = col / 4

    // Add random jitter (PRNG & $03)
    pha
    lda zp_frame
    eor rain_lfsr_state
    asl
    eor #$1D
    sta rain_lfsr_state     // update LFSR
    and #$03                // 0-3 jitter
    sta zp_gen_lo           // temp
    pla
    clc
    adc zp_gen_lo           // delay = col/4 + jitter

    sta RAIN_COL_STATE, y   // CS_DELAY
    iny
    lda #0
    sta RAIN_COL_STATE, y   // CS_HEAD = 0
    iny
    sta RAIN_COL_STATE, y   // CS_PHASE = 0 (waiting)
    iny
    // Per-column seed: mix column index with frame
    txa
    eor zp_frame
    eor #$A5
    sta RAIN_COL_STATE, y   // CS_SEED
    iny

    inx
    cpx #RAIN_COLS
    bne !init_loop-
    rts

// ============================================================
// init_sid_sweep
// Configure SID voice 2 for sawtooth descending sweep.
// Clobbers: A
// ============================================================
init_sid_sweep:
    lda #$0F
    sta SID_VOLUME          // max volume
    // ADSR: instant attack, medium sustain
    lda #$00
    sta SID_V2_AD           // attack=0, decay=0
    lda #$A0
    sta SID_V2_SR           // sustain=10, release=0
    // Starting frequency
    lda #$00
    sta SID_V2_FREQ_LO
    lda #$30
    sta SID_V2_FREQ_HI
    sta zp_rain_freq_hi     // track freq hi
    // Sawtooth waveform + gate on
    lda #$21                // sawtooth + gate
    sta SID_V2_CTRL
    rts

// ============================================================
// update_sid_sweep
// Decrement frequency each frame for descending tone.
// Clobbers: A
// ============================================================
update_sid_sweep:
    lda zp_rain_freq_hi
    cmp #$02                // don't go below $02
    bcc !skip+
    sec
    sbc #1                  // could also do dec but need to write to SID
    sta zp_rain_freq_hi
    sta SID_V2_FREQ_HI
!skip:
    rts

// ============================================================
// silence_sid
// Turn off SID voice 2 gate.
// Clobbers: A
// ============================================================
silence_sid:
    lda #$20                // sawtooth, gate OFF
    sta SID_V2_CTRL
    rts

// ============================================================
// update_columns
// Process all 40 columns for one frame.
// For each column:
//   - If phase=0 (waiting): decrement delay, switch to phase=1 when 0
//   - If phase=1 (raining): advance head, write random chars at head,
//     settle chars SETTLE_DIST behind head to shadow buffer values
//   - If phase=2 (done): skip
// Clobbers: A, X, Y, zp_ptr, zp_cg_ptr, zp_gen_lo/hi
// ============================================================
update_columns:
    ldx #0                  // column index (0-39)
    stx col_index

!col_loop:
    // Calculate state table offset: col * 4
    lda col_index
    asl
    asl
    tay                     // Y = state table offset

    // Check phase
    lda RAIN_COL_STATE + CS_PHASE, y
    cmp #2
    bne !not_done+
    jmp !next_col+          // done — skip
!not_done:

    cmp #1
    bne !not_raining+
    jmp !raining+
!not_raining:

    // Phase 0: waiting — decrement delay
    lda RAIN_COL_STATE + CS_DELAY, y
    beq !start_rain+
    sec
    sbc #1
    sta RAIN_COL_STATE + CS_DELAY, y
    jmp !next_col+

!start_rain:
    lda #1
    sta RAIN_COL_STATE + CS_PHASE, y    // switch to raining

!raining:
    // Get current head row
    lda RAIN_COL_STATE + CS_HEAD, y
    cmp #RAIN_ROWS
    bcs !mark_done+

    // --- Write random char at head position ---
    pha                     // save head row
    tax                     // X = head row
    lda col_index
    jsr get_screen_offset   // returns 16-bit offset in zp_ptr_lo/hi
    // Pick random char from table
    lda RAIN_COL_STATE + CS_SEED, y
    asl
    eor #$1D               // LFSR tap
    sta RAIN_COL_STATE + CS_SEED, y
    and #$1F                // index into 32-char table
    tax
    lda rain_chars, x
    // Write to SCREEN_RAM
    ldy #0
    sta (zp_ptr_lo), y
    // Color: white for head
    lda zp_ptr_hi
    clc
    adc #$D4                // COLOR_RAM = SCREEN_RAM + $D400
    sta zp_ptr_hi
    lda #COL_WHITE
    sta (zp_ptr_lo), y
    // Restore ptr_hi
    lda zp_ptr_hi
    sec
    sbc #$D4
    sta zp_ptr_hi

    pla                     // restore head row
    pha

    // --- Settle chars SETTLE_DIST behind head ---
    sec
    sbc #SETTLE_DIST
    bmi !no_settle+         // head too close to top
    tax                     // X = settle row
    lda col_index
    pha
    jsr settle_cell         // settle this cell to final char
    pla
    sta col_index

!no_settle:
    // --- Colour trail: light green for row head-1, green for head-2 ---
    pla                     // restore head row
    pha
    sec
    sbc #1
    bmi !no_trail_color+
    tax
    lda col_index
    jsr get_screen_offset
    lda zp_ptr_hi
    clc
    adc #$D4
    sta zp_ptr_hi
    lda #COL_LT_GREEN
    ldy #0
    sta (zp_ptr_lo), y
    lda zp_ptr_hi
    sec
    sbc #$D4
    sta zp_ptr_hi
!no_trail_color:

    pla                     // head row again

    // Recalculate Y = state offset (col * 4)
    pha
    lda col_index
    asl
    asl
    tay
    pla

    // Advance head
    clc
    adc #1
    sta RAIN_COL_STATE + CS_HEAD, y
    jmp !next_col+

!mark_done:
    // Column finished — settle any remaining unsettled rows
    lda #2
    sta RAIN_COL_STATE + CS_PHASE, y
    dec zp_rain_active

!next_col:
    inc col_index
    lda col_index
    cmp #RAIN_COLS
    beq !done+
    jmp !col_loop-
!done:
    rts

// ============================================================
// get_screen_offset
// Calculate SCREEN_RAM address for (col A, row X)
// Returns address in zp_ptr_lo/hi
// Clobbers: A (preserves X and Y via stack)
// ============================================================
get_screen_offset:
    // address = SCREEN_RAM + row_offset_table[row] + col
    sty col_state_save      // save Y (state offset)
    sta col_save             // save col
    lda row_offset_lo, x
    clc
    adc col_save
    sta zp_ptr_lo
    lda row_offset_hi, x
    adc #0
    sta zp_ptr_hi
    ldy col_state_save      // restore Y
    rts

// ============================================================
// settle_cell
// Write final character from shadow buffer to screen at (col A, row X)
// Also set color to green (will be overwritten by finalize)
// Clobbers: A, zp_ptr, zp_cg_ptr
// ============================================================
settle_cell:
    // Save col and row
    sta col_save
    stx row_save

    // Get SCREEN_RAM address
    jsr get_screen_offset

    // Get SHADOW_SCREEN address (same offset but base $6200)
    lda row_offset_lo, x
    clc
    adc col_save
    sta zp_cg_ptr_lo
    lda row_offset_hi, x
    adc #0
    // Adjust from SCREEN_RAM base to SHADOW_SCREEN base
    clc
    adc #>(SHADOW_SCREEN - SCREEN_RAM)
    sta zp_cg_ptr_hi

    // Copy char
    ldy #0
    lda (zp_cg_ptr_lo), y
    sta (zp_ptr_lo), y

    // Set color to green (settled)
    lda zp_ptr_hi
    clc
    adc #$D4
    sta zp_ptr_hi
    lda #COL_GREEN
    sta (zp_ptr_lo), y

    ldx row_save
    rts

// ============================================================
// finalize_screen
// Copy entire shadow buffer back to screen RAM to ensure
// every cell has its final character (catches any stragglers).
// Clobbers: A, X
// ============================================================
finalize_screen:
    ldx #0
!fin_loop:
    lda SHADOW_SCREEN, x
    sta SCREEN_RAM, x
    lda SHADOW_SCREEN + $100, x
    sta SCREEN_RAM + $100, x
    lda SHADOW_SCREEN + $200, x
    sta SCREEN_RAM + $200, x
    lda SHADOW_SCREEN + $300, x
    sta SCREEN_RAM + $300, x
    inx
    bne !fin_loop-
    rts

// ============================================================
// colour_title_rows
// Re-apply colours for non-code rows (title, header, registers,
// help, etc.) that colorize_code_area doesn't cover.
// Clobbers: A, X, Y, zp_ptr
// ============================================================
colour_title_rows:
    // Row 0: title — white
    lda #<COLOR_RAM
    sta zp_ptr_lo
    lda #>COLOR_RAM
    sta zp_ptr_hi
    lda #COL_WHITE
    ldx #40
!title_c:
    ldy #0
    sta (zp_ptr_lo), y
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    dex
    bne !title_c-

    // Row 1: header — cyan
    lda #COL_CYAN
    ldx #40
!header_c:
    ldy #0
    sta (zp_ptr_lo), y
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    dex
    bne !header_c-

    // Row 19: registers — yellow
    lda #<(COLOR_RAM + 40*19)
    sta zp_ptr_lo
    lda #>(COLOR_RAM + 40*19)
    sta zp_ptr_hi
    lda #COL_YELLOW
    ldx #40
!reg_c:
    ldy #0
    sta (zp_ptr_lo), y
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    dex
    bne !reg_c-

    // Row 21: help — light grey
    lda #<(COLOR_RAM + 40*21)
    sta zp_ptr_lo
    lda #>(COLOR_RAM + 40*21)
    sta zp_ptr_hi
    lda #COL_LT_GREY
    ldx #40
!help_c:
    ldy #0
    sta (zp_ptr_lo), y
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    dex
    bne !help_c-

    rts

// ============================================================
// Data tables
// ============================================================

// Temporary variables (in code segment — self-modifying style)
col_index:       .byte 0
col_save:        .byte 0
row_save:        .byte 0
col_state_save:  .byte 0
rain_frame_counter: .byte 0
rain_lfsr_state: .byte $A7   // PRNG state

// 32 "digital rain" screen codes — mix of letters, digits, symbols
rain_chars:
    .byte $01, $02, $03, $04, $05, $06, $07, $08  // A-H
    .byte $09, $0A, $0B, $0C, $0D, $0E, $0F, $10  // I-P
    .byte $30, $31, $32, $33, $34, $35, $36, $37   // 0-7
    .byte $38, $39, $1B, $1C, $1E, $1F, $2A, $2B   // 8-9 + symbols

// Row offset lookup tables (SCREEN_RAM base $0400)
// row_offset[n] = $0400 + n*40
row_offset_lo:
    .fill 25, <(SCREEN_RAM + i*40)
row_offset_hi:
    .fill 25, >(SCREEN_RAM + i*40)

.assert "MatrixRain fits", * <= $9000, true
