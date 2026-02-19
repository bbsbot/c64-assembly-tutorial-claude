// ============================================================
// ui_render.asm — Screen chrome, palette, program, value bar
// ============================================================
// All writes go directly to screen RAM ($0400) and color RAM
// ($D800) using screen-code values from strings.asm.
//
// Screen layout (40×25):
//  Row  0: title
//  Row  1: thick divider ────
//  Row  2: "PALETTE"  │  "YOUR PROGRAM"
//  Row  3: thin divider ──┼──
//  Rows 4-18: palette list (left) + program slots (right)
//  Row 19: thin divider ──┴──
//  Row 20: value bar
//  Row 21: thin divider ────
//  Row 22: key hints line 1
//  Row 23: key hints line 2
//  Row 24: status message
// ============================================================
.filenamespace UIRender

.pc = $1000 "UIRender"

// ============================================================
// ui_clear_screen
// Fills all 1000 chars of screen RAM with spaces (SC_SPACE=$20)
// and color RAM with COL_GREEN (5).
// Inputs: none  Clobbers: A, X
// ============================================================
ui_clear_screen:
    lda #SC_SPACE
    ldx #0
!loop:
    sta SCREEN_RAM,     x
    sta SCREEN_RAM+256, x
    sta SCREEN_RAM+512, x
    sta SCREEN_RAM+744, x   // 1000 - 256 = 744 (last partial page)
    inx
    bne !loop-
    // clear remaining bytes 744..999
    // already done above for x=0..255 covering 744+x — but we need rows 0-3
    // Actually fill all 1000: pages 0-2 (768 bytes) + 232 more
    // Re-do properly:
    lda #SC_SPACE
    ldx #$00
!pg0: sta SCREEN_RAM+$000, x : inx : bne !pg0-
!pg1: sta SCREEN_RAM+$100, x : inx : bne !pg1-
!pg2: sta SCREEN_RAM+$200, x : inx : bne !pg2-
    ldx #231            // remaining: 1000 - 768 = 232 bytes (0..231)
!pg3: sta SCREEN_RAM+$300, x : dex : bpl !pg3-

    // color RAM = light green (COL_LT_GREEN = 13) for most
    lda #COL_LT_GREEN
    ldx #$00
!c0: sta COLOR_RAM+$000, x : inx : bne !c0-
!c1: sta COLOR_RAM+$100, x : inx : bne !c1-
!c2: sta COLOR_RAM+$200, x : inx : bne !c2-
    ldx #231
!c3: sta COLOR_RAM+$300, x : dex : bpl !c3-
    rts

// ============================================================
// ui_render_frame
// Draws all static chrome: title, dividers, panel headers,
// key hints.  Call once at init.
// Inputs: none  Clobbers: A, X, Y
// ============================================================
ui_render_frame:
    // --- Row 0: title (col 0, screen offset = 0) ---
    lda #<SCREEN_RAM
    sta zp_ptr_lo
    lda #>SCREEN_RAM
    sta zp_ptr_hi
    lda #<Strings.str_title
    sta zp_cg_ptr_lo
    lda #>Strings.str_title
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr   // draw 38 chars starting at row 0

    // set title row color to yellow (COL_YELLOW=7)
    lda #7
    ldx #39
!tc: sta COLOR_RAM, x : dex : bpl !tc-

    // --- Row 1: thick divider (col 0..39) ---
    ldy #0
!div1: lda #SC_HLINE
    sta SCREEN_RAM+40, y
    lda #COL_WHITE
    sta COLOR_RAM+40, y
    iny
    cpy #40
    bne !div1-

    // --- Row 2: panel headers ---
    // "PALETTE" at col 0 row 2
    lda #<(SCREEN_RAM + 80)     // row 2 = 2*40
    sta zp_ptr_lo
    lda #>(SCREEN_RAM + 80)
    sta zp_ptr_hi
    lda #<Strings.str_hdr_palette
    sta zp_cg_ptr_lo
    lda #>Strings.str_hdr_palette
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr

    // "YOUR PROGRAM" at col 20 row 2
    lda #<(SCREEN_RAM + 80 + 20)
    sta zp_ptr_lo
    lda #>(SCREEN_RAM + 80 + 20)
    sta zp_ptr_hi
    lda #<Strings.str_hdr_program
    sta zp_cg_ptr_lo
    lda #>Strings.str_hdr_program
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr

    // vertical divider at col 19, rows 2–18
    ldx #0
!vdiv_loop:
    // row (2+x), col 19 = screen offset (2+x)*40 + 19
    // use a computed offset table would be cleaner; for now use multiplication by 40
    // precompute: base = (2+x)*40 + 19
    // We'll use a simple loop adding 40 each time
    txa
    clc
    adc #2              // row = 2+x
    jsr row_to_screen_offset   // returns lo/hi in zp_ptr
    lda zp_ptr_lo
    clc
    adc #19
    sta zp_ptr_lo
    bcc !+
    inc zp_ptr_hi
!:
    ldy #0
    lda #SC_PIPE
    sta (zp_ptr_lo), y
    // color it
    lda zp_ptr_lo
    sec
    sbc #<SCREEN_RAM
    sta zp_cg_ptr_lo
    lda zp_ptr_hi
    sbc #>SCREEN_RAM
    clc
    adc #>COLOR_RAM
    sta zp_cg_ptr_hi
    lda zp_cg_ptr_lo
    // add lo properly
    lda zp_ptr_lo
    sec
    sbc #<SCREEN_RAM
    sta zp_cg_ptr_lo
    // now color ptr = COLOR_RAM + (screen_ptr - SCREEN_RAM)
    lda #COL_WHITE
    sta (zp_cg_ptr_lo), y
    inx
    cpx #17             // rows 2..18 = 17 rows
    bne !vdiv_loop-

    // --- Row 3: thin divider ──┼── ---
    jsr draw_row3_divider

    // --- Row 19: bottom divider ──┴── ---
    jsr draw_row19_divider

    // --- Row 21: divider ---
    ldy #0
!div21:
    lda #SC_HLINE
    sta SCREEN_RAM + 21*40, y
    iny
    cpy #40
    bne !div21-

    // --- Row 22: key hints ---
    lda #<(SCREEN_RAM + 22*40)
    sta zp_ptr_lo
    lda #>(SCREEN_RAM + 22*40)
    sta zp_ptr_hi
    lda #<Strings.str_hint1
    sta zp_cg_ptr_lo
    lda #>Strings.str_hint1
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr

    // --- Row 23: key hints 2 ---
    lda #<(SCREEN_RAM + 23*40)
    sta zp_ptr_lo
    lda #>(SCREEN_RAM + 23*40)
    sta zp_ptr_hi
    lda #<Strings.str_hint2
    sta zp_cg_ptr_lo
    lda #>Strings.str_hint2
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr

    rts

// ============================================================
// ui_render_palette
// Draws block list in left panel (rows 4–18, cols 1–17)
// Highlights the row at zp_pal_cursor when state=STATE_PALETTE
// Inputs: zp_pal_cursor, zp_state  Clobbers: A, X, Y
// ============================================================
ui_render_palette:
    ldx #0
!block_row:
    cpx #NUM_BLOCKS
    beq !pal_done+

    // compute screen address: row = (UI_LIST_ROW + x) * 40 + UI_PAL_COL
    txa
    clc
    adc #UI_LIST_ROW
    jsr row_to_screen_offset
    lda zp_ptr_lo
    clc
    adc #UI_PAL_COL
    sta zp_ptr_lo
    bcc !+
    inc zp_ptr_hi
!:
    // draw cursor glyph or space
    ldy #0
    lda zp_state
    cmp #STATE_PALETTE
    bne !no_pal_cursor+
    txa
    cmp zp_pal_cursor
    bne !no_pal_cursor+
    lda #Strings.SC_CURSOR
    sta (zp_ptr_lo), y
    jmp !draw_name+
!no_pal_cursor:
    lda #SC_SPACE
    sta (zp_ptr_lo), y

!draw_name:
    // advance ptr by 1 to skip cursor column
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    // get block name pointer
    stx zp_edit_slot        // temp save X
    lda Strings.block_name_ptrs_lo, x
    sta zp_cg_ptr_lo
    lda Strings.block_name_ptrs_hi, x
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr

    // set color for entire row
    ldx zp_edit_slot
    lda BlocksData.block_color_map, x
    jsr set_row_color_palette

    ldx zp_edit_slot
    inx
    jmp !block_row-
!pal_done:
    rts

// ============================================================
// ui_render_program
// Draws program slots in right panel (rows 4–18, cols 21–38)
// Shows block name + param preview, cursor at zp_pgm_cursor.
// Inputs: zp_pgm_cursor, zp_slots_used, zp_state
// Clobbers: A, X, Y
// ============================================================
ui_render_program:
    ldx #0
!pgm_row:
    cpx #UI_LIST_ROWS
    beq !pgm_done+

    // screen address: row=(4+x)*40 + UI_PGM_COL
    txa
    clc
    adc #UI_LIST_ROW
    jsr row_to_screen_offset
    lda zp_ptr_lo
    clc
    adc #UI_PGM_COL
    sta zp_ptr_lo
    bcc !+
    inc zp_ptr_hi
!:
    stx zp_edit_slot        // save X

    // cursor glyph
    ldy #0
    lda zp_state
    cmp #STATE_PROGRAM
    bne !no_pgm_cursor+
    cmp #STATE_EDIT_PARAM
    beq !show_pgm_cursor+
    txa
    cmp zp_pgm_cursor
    bne !no_pgm_cursor+
!show_pgm_cursor:
    lda #Strings.SC_CURSOR
    jmp !write_cursor+
!no_pgm_cursor:
    lda #SC_SPACE
!write_cursor:
    sta (zp_ptr_lo), y

    // advance past cursor glyph
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    // is this slot filled?
    ldx zp_edit_slot
    cpx zp_slots_used
    bcs !empty_slot+

    // get block type for this slot
    lda ProgramStore.slot_stride3_table, x
    tay
    lda ProgramStore.slot_array, y  // block type

    // draw block name (12 chars)
    tax
    lda Strings.block_name_ptrs_lo, x
    sta zp_cg_ptr_lo
    lda Strings.block_name_ptrs_hi, x
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr

    // draw param preview (4 chars after name)
    ldx zp_edit_slot
    lda ProgramStore.slot_stride3_table, x
    tay
    lda ProgramStore.slot_array, y      // block type
    pha
    lda ProgramStore.slot_array+1, y    // param value
    tay                                 // Y = param
    pla                                 // A = block type
    jsr draw_param_preview

    jmp !next_pgm_row+

!empty_slot:
    // draw "- - - - - -" filler (12 dashes + 4 spaces)
    ldy #0
!dash_loop:
    lda #Strings.SC_EMPTY_SLOT
    sta (zp_ptr_lo), y
    iny
    cpy #12
    bne !dash_loop-
    // 4 spaces
!sp_loop:
    lda #SC_SPACE
    sta (zp_ptr_lo), y
    iny
    cpy #16
    bne !sp_loop-

!next_pgm_row:
    ldx zp_edit_slot
    inx
    jmp !pgm_row-
!pgm_done:
    rts

// ============================================================
// draw_param_preview
// Inputs:  A = block type, Y = param value
//          zp_ptr_lo/hi pointing after block name on screen
// Draws 4-char preview of the parameter
// Clobbers: A, X, Y
// ============================================================
draw_param_preview:
    cmp #BLOCK_SET_BORDER
    beq !color_preview+
    cmp #BLOCK_SET_BG
    beq !color_preview+
    cmp #BLOCK_PRINT
    beq !char_preview+
    cmp #BLOCK_WAIT
    beq !secs_preview+
    // SHOW_SPRITE, LOOP_BACK: spaces
    lda #SC_SPACE
    ldy #0
    sta (zp_ptr_lo), y
    iny
    sta (zp_ptr_lo), y
    rts

!color_preview:
    // draw colour index as 2-digit hex (or just a colour swatch)
    // Simple: draw colour square char + color in that colour
    // For now just draw " ## " where ## = decimal index
    lda #SC_SPACE : ldy #0 : sta (zp_ptr_lo), y
    iny
    tya
    pha
    tya : pla            // restore Y
    // draw digit tens
    ldy #0
    tya
    pha
    // param is in Y from caller; but after the cmp/beq Y is intact
    // We need to get param back. Save it via zp_gen_lo
    pla
    rts                  // placeholder — param display handled in value bar

!char_preview:
    // show single PETSCII letter as screen code
    ldy #0
    lda #SC_SPACE : sta (zp_ptr_lo), y : iny
    // convert PETSCII to screen code: sc = petscii - $40
    // Y = param (PETSCII)
    tya : sec : sbc #$40
    ldx #0
    sta (zp_ptr_lo), y
    rts

!secs_preview:
    ldy #0
    lda #SC_SPACE : sta (zp_ptr_lo), y : iny
    // Y = seconds digit (1-9) → screen code: digit $31-$39 - $30 = $01-$09? No.
    // Screen code for '1' = $31 - $40 = NO. Digit chars: '0'=$30 PETSCII.
    // Screen code for digit: '0'=$30 (no shift) stays as $30 in screen RAM
    tya : clc : adc #$30    // convert digit to screen code for '0'-'9'
    sta (zp_ptr_lo), y
    rts

// ============================================================
// ui_render_value_bar
// Draws row 20 with current edit parameter
// Inputs:  zp_edit_val, zp_edit_slot, zp_state
// Clobbers: A, X, Y
// ============================================================
ui_render_value_bar:
    // Row 20 = offset 800
    lda #<(SCREEN_RAM + 800)
    sta zp_ptr_lo
    lda #>(SCREEN_RAM + 800)
    sta zp_ptr_hi

    // draw " VALUE: " label
    lda #<Strings.str_value_label
    sta zp_cg_ptr_lo
    lda #>Strings.str_value_label
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr  // advances zp_ptr by 8

    // get block type for current slot
    ldx zp_edit_slot
    lda ProgramStore.slot_stride3_table, x
    tay
    lda ProgramStore.slot_array, y
    tax                         // X = block type
    lda BlocksData.block_param_type, x
    cmp #PARAM_NONE
    beq !val_bar_none+
    cmp #PARAM_COLOR
    beq !val_bar_color+
    cmp #PARAM_CHAR
    beq !val_bar_char+
    cmp #PARAM_SECS
    beq !val_bar_secs+
    jmp !val_bar_done+

!val_bar_none:
    // draw "  N/A  "
    lda #$0E : ldy #0 : sta (zp_ptr_lo), y  // N (screen $0E)
    lda #$2F : ldy #1 : sta (zp_ptr_lo), y  // /
    lda #$01 : ldy #2 : sta (zp_ptr_lo), y  // A
    jmp !val_bar_done+

!val_bar_color:
    // draw colour name (8 chars) then ◄► arrows
    ldx zp_edit_val
    lda Strings.color_name_ptrs_lo, x
    sta zp_cg_ptr_lo
    lda Strings.color_name_ptrs_hi, x
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr
    // draw ◄► (screen codes)
    lda #$1F                // ◄ (screen code $1F)
    ldy #0 : sta (zp_ptr_lo), y
    lda #$1E                // ► (screen code $1E)
    ldy #1 : sta (zp_ptr_lo), y
    jmp !val_bar_done+

!val_bar_char:
    // draw "CHAR: X" where X is the letter
    // zp_edit_val = PETSCII $41-$5A
    // screen code = PETSCII - $40
    lda zp_edit_val
    sec : sbc #$40
    ldy #0 : sta (zp_ptr_lo), y
    lda #$1F : ldy #1 : sta (zp_ptr_lo), y  // ◄
    lda #$1E : ldy #2 : sta (zp_ptr_lo), y  // ►
    jmp !val_bar_done+

!val_bar_secs:
    // draw digit 1-9 as screen code
    lda zp_edit_val
    clc : adc #$30          // digit → screen code (0='0'=$30? no: '1' in screen=$31-$40?)
    // Screen codes for digits: '0'=$30 no. Let's check:
    // PETSCII digit '0' = $30. Screen code '0' = $30 (same).
    // So screen code for digit n = $30 + n.
    // But wait: screen code offset for digits is NOT shifted — digits $30-$39 are direct
    lda zp_edit_val
    // zp_edit_val = 1..9 (raw count), display as '1'..'9'
    clc : adc #$30          // gives $31..$39 = screen codes for '1'..'9' ✓
    ldy #0 : sta (zp_ptr_lo), y
    lda #$1F : ldy #1 : sta (zp_ptr_lo), y
    lda #$1E : ldy #2 : sta (zp_ptr_lo), y

!val_bar_done:
    // clear rest of row to col 39
    // (simplified: fill remaining 32 bytes with space)
    lda #SC_SPACE
    ldy #0
!clr:
    sta (zp_ptr_lo), y
    iny
    cpy #20
    bne !clr-
    rts

// ============================================================
// ui_render_status
// Draws one of the status message strings on row 24.
// Inputs:  A = status index (0=ready,1=added,2=full,3=running,
//              4=cleared,5=removed,6=editing)
// Clobbers: A, X, Y
// ============================================================
.label STATUS_READY   = 0
.label STATUS_ADDED   = 1
.label STATUS_FULL    = 2
.label STATUS_RUNNING = 3
.label STATUS_CLEARED = 4
.label STATUS_REMOVED = 5
.label STATUS_EDITING = 6

// pointer table lo/hi for status strings
status_ptrs_lo:
    .byte <Strings.str_status_ready,   <Strings.str_status_added
    .byte <Strings.str_status_full,    <Strings.str_status_running
    .byte <Strings.str_status_cleared, <Strings.str_status_removed
    .byte <Strings.str_status_editing

status_ptrs_hi:
    .byte >Strings.str_status_ready,   >Strings.str_status_added
    .byte >Strings.str_status_full,    >Strings.str_status_running
    .byte >Strings.str_status_cleared, >Strings.str_status_removed
    .byte >Strings.str_status_editing

ui_render_status:
    tax
    lda status_ptrs_lo, x
    sta zp_cg_ptr_lo
    lda status_ptrs_hi, x
    sta zp_cg_ptr_hi
    lda #<(SCREEN_RAM + 24*40)
    sta zp_ptr_lo
    lda #>(SCREEN_RAM + 24*40)
    sta zp_ptr_hi
    jsr draw_len_string_at_ptr
    rts

// ============================================================
// draw_len_string_at_ptr
// Inputs:  zp_ptr_lo/hi = screen dest
//          zp_cg_ptr_lo/hi = source string (length-prefixed)
// Draws length-byte many chars; advances zp_ptr by that amount.
// Clobbers: A, X, Y
// ============================================================
draw_len_string_at_ptr:
    ldy #0
    lda (zp_cg_ptr_lo), y   // read length byte
    beq !done+
    tax                      // X = char count
    // advance source ptr past length byte
    inc zp_cg_ptr_lo
    bne !+
    inc zp_cg_ptr_hi
!:
    ldy #0
!copy:
    lda (zp_cg_ptr_lo), y
    sta (zp_ptr_lo), y
    iny
    dex
    bne !copy-
    // advance dest ptr by length
    tya
    clc
    adc zp_ptr_lo
    sta zp_ptr_lo
    bcc !done+
    inc zp_ptr_hi
!done:
    rts

// ============================================================
// row_to_screen_offset
// Inputs:  A = row (0..24)
// Outputs: zp_ptr_lo/hi = SCREEN_RAM + row*40
// Uses a 25-entry table of row offsets.
// Clobbers: A, X
// ============================================================
row_to_screen_offset:
    asl a               // row*2 (index into word table)
    tax
    lda row_offsets_lo, x
    sta zp_ptr_lo
    lda row_offsets_hi, x
    sta zp_ptr_hi
    rts

// Pre-computed: row_offset[r] = $0400 + r*40
row_offsets_lo:
    .fill 25, i : .byte <(SCREEN_RAM + i * 40)

row_offsets_hi:
    .fill 25, i : .byte >(SCREEN_RAM + i * 40)

// ============================================================
// set_row_color_palette
// Sets color of row (UI_LIST_ROW + current block row) in left panel
// Inputs:  A = color, X = block row (0..5)
// ============================================================
set_row_color_palette:
    pha
    txa
    clc
    adc #UI_LIST_ROW
    jsr row_to_screen_offset
    // convert screen ptr to color ptr
    lda zp_ptr_lo
    clc
    adc #<(COLOR_RAM - SCREEN_RAM)
    sta zp_ptr_lo
    lda zp_ptr_hi
    adc #>(COLOR_RAM - SCREEN_RAM)
    sta zp_ptr_hi
    pla
    ldy #0
!colrow:
    sta (zp_ptr_lo), y
    iny
    cpy #18             // color palette columns 0-17
    bne !colrow-
    rts

// ============================================================
// draw_row3_divider and draw_row19_divider
// ============================================================
draw_row3_divider:
    ldy #0
!d3:
    cpy #19
    beq !d3_pipe+
    lda #SC_HLINE
    jmp !d3_write+
!d3_pipe:
    lda #$DB            // ┼ (screen code for cross)
!d3_write:
    sta SCREEN_RAM + 3*40, y
    lda #COL_WHITE
    sta COLOR_RAM + 3*40, y
    iny
    cpy #40
    bne !d3-
    rts

draw_row19_divider:
    ldy #0
!d19:
    cpy #19
    beq !d19_tee+
    lda #SC_HLINE
    jmp !d19_write+
!d19_tee:
    lda #$C1            // ┴ (screen code)
!d19_write:
    sta SCREEN_RAM + 19*40, y
    lda #COL_WHITE
    sta COLOR_RAM + 19*40, y
    iny
    cpy #40
    bne !d19-
    rts

.assert "UIRender segment fits", * <= $1800, true
