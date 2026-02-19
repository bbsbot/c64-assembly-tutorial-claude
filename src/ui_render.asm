// ============================================================
// ui_render.asm — Screen chrome, palette, program, value bar
// ============================================================
.filenamespace UIRender

.pc = $1000 "UIRender"

// ============================================================
// ui_clear_screen
// Fills screen RAM with spaces, color RAM with light-green.
// Inputs: none  Clobbers: A, X
// ============================================================
ui_clear_screen:
    lda #SC_SPACE
    ldx #0
!pg0:
    sta SCREEN_RAM+$000, x
    inx
    bne !pg0-
    ldx #0
!pg1:
    sta SCREEN_RAM+$100, x
    inx
    bne !pg1-
    ldx #0
!pg2:
    sta SCREEN_RAM+$200, x
    inx
    bne !pg2-
    ldx #231            // 1000 - 768 = 232 bytes (indices 0..231)
!pg3:
    sta SCREEN_RAM+$300, x
    dex
    bpl !pg3-

    lda #COL_LT_GREEN
    ldx #0
!c0:
    sta COLOR_RAM+$000, x
    inx
    bne !c0-
    ldx #0
!c1:
    sta COLOR_RAM+$100, x
    inx
    bne !c1-
    ldx #0
!c2:
    sta COLOR_RAM+$200, x
    inx
    bne !c2-
    ldx #231
!c3:
    sta COLOR_RAM+$300, x
    dex
    bpl !c3-
    rts

// ============================================================
// ui_render_frame
// Draws all static chrome once at init.
// Inputs: none  Clobbers: A, X, Y
// ============================================================
ui_render_frame:
    // --- Row 0: title ---
    lda #<SCREEN_RAM
    sta zp_ptr_lo
    lda #>SCREEN_RAM
    sta zp_ptr_hi
    lda #<Strings.str_title
    sta zp_cg_ptr_lo
    lda #>Strings.str_title
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr

    // Title row color = yellow
    ldx #39
!tc:
    lda #COL_YELLOW
    sta COLOR_RAM, x
    dex
    bpl !tc-

    // --- Row 1: thick horizontal divider ---
    ldy #0
!div1:
    lda #SC_HLINE
    sta SCREEN_RAM + 1*40, y
    lda #COL_WHITE
    sta COLOR_RAM + 1*40, y
    iny
    cpy #40
    bne !div1-

    // --- Row 2: panel headers ---
    lda #<(SCREEN_RAM + 2*40)
    sta zp_ptr_lo
    lda #>(SCREEN_RAM + 2*40)
    sta zp_ptr_hi
    lda #<Strings.str_hdr_palette
    sta zp_cg_ptr_lo
    lda #>Strings.str_hdr_palette
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr

    lda #<(SCREEN_RAM + 2*40 + 20)
    sta zp_ptr_lo
    lda #>(SCREEN_RAM + 2*40 + 20)
    sta zp_ptr_hi
    lda #<Strings.str_hdr_program
    sta zp_cg_ptr_lo
    lda #>Strings.str_hdr_program
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr

    // --- Row 3: thin divider with cross at col 19 ---
    ldy #0
!div3:
    cpy #19
    bne !div3_line+
    lda #$DB            // + cross character (screen code)
    jmp !div3_write+
!div3_line:
    lda #SC_HLINE
!div3_write:
    sta SCREEN_RAM + 3*40, y
    lda #COL_WHITE
    sta COLOR_RAM + 3*40, y
    iny
    cpy #40
    bne !div3-

    // --- Vertical divider: col 19, rows 2–18 (17 rows) ---
    ldx #0
!vdiv:
    txa
    clc
    adc #2              // row = 2+x
    jsr row_to_screen_offset    // zp_ptr = SCREEN_RAM + row*40
    // add col 19
    lda zp_ptr_lo
    clc
    adc #19
    sta zp_ptr_lo
    bcc !+
    inc zp_ptr_hi
!:
    // write vertical bar to screen
    ldy #0
    lda #$DD            // vertical bar screen code
    sta (zp_ptr_lo), y
    // write color: color_ptr = screen_ptr + $D400
    lda zp_ptr_lo
    sta zp_cg_ptr_lo
    lda zp_ptr_hi
    clc
    adc #$D4
    sta zp_cg_ptr_hi
    lda #COL_WHITE
    sta (zp_cg_ptr_lo), y
    inx
    cpx #17
    bne !vdiv-

    // --- Row 19: bottom divider with T-join at col 19 ---
    ldy #0
!div19:
    cpy #19
    bne !div19_line+
    lda #$C1            // bottom T-join
    jmp !div19_write+
!div19_line:
    lda #SC_HLINE
!div19_write:
    sta SCREEN_RAM + 19*40, y
    lda #COL_WHITE
    sta COLOR_RAM + 19*40, y
    iny
    cpy #40
    bne !div19-

    // --- Row 21: divider below value bar ---
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
// Redraws block list in left panel (rows 4-18, cols 1-17).
// Inputs: zp_pal_cursor, zp_state  Clobbers: A, X, Y
// ============================================================
ui_render_palette:
    ldx #0
!row:
    cpx #NUM_BLOCKS
    beq !done+

    stx zp_edit_slot        // temp: save row index

    // screen addr = SCREEN_RAM + (UI_LIST_ROW + x)*40 + UI_PAL_COL
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
    // draw cursor glyph or space in col 0
    ldy #0
    ldx zp_edit_slot
    lda zp_state
    cmp #STATE_PALETTE
    bne !no_cur+
    txa
    cmp zp_pal_cursor
    bne !no_cur+
    lda #Strings.SC_CURSOR
    jmp !write_cur+
!no_cur:
    lda #SC_SPACE
!write_cur:
    sta (zp_ptr_lo), y

    // advance ptr past cursor column
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    // draw block name (12 chars)
    ldx zp_edit_slot
    lda Strings.block_name_ptrs_lo, x
    sta zp_cg_ptr_lo
    lda Strings.block_name_ptrs_hi, x
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr

    // set row highlight color
    ldx zp_edit_slot
    lda BlocksData.block_color_map, x
    jsr set_row_color_pal

    ldx zp_edit_slot
    inx
    jmp !row-
!done:
    rts

// ============================================================
// set_row_color_pal
// Inputs: A = color, X = block row (0..5)
// Colors cols 0..17 of row UI_LIST_ROW+X in color RAM.
// Clobbers: A, Y
// ============================================================
set_row_color_pal:
    pha
    txa
    clc
    adc #UI_LIST_ROW
    jsr row_to_screen_offset    // zp_ptr = screen addr of row
    // color_ptr = screen_ptr + $D400
    lda zp_ptr_lo
    sta zp_cg_ptr_lo
    lda zp_ptr_hi
    clc
    adc #$D4
    sta zp_cg_ptr_hi
    pla                         // restore color
    ldy #0
!lp:
    sta (zp_cg_ptr_lo), y
    iny
    cpy #18
    bne !lp-
    rts

// ============================================================
// ui_render_program
// Redraws right panel (rows 4-18, cols 21-38).
// Inputs: zp_pgm_cursor, zp_slots_used, zp_state
// Clobbers: A, X, Y
// ============================================================
ui_render_program:
    ldx #0
!row:
    cpx #UI_LIST_ROWS
    beq !done+

    stx zp_edit_slot

    // screen addr = SCREEN_RAM + (UI_LIST_ROW + x)*40 + UI_PGM_COL
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
    // cursor glyph: show if (STATE_PROGRAM or STATE_EDIT_PARAM) and row==pgm_cursor
    ldy #0
    ldx zp_edit_slot
    lda zp_state
    cmp #STATE_PROGRAM
    beq !chk_cur+
    cmp #STATE_EDIT_PARAM
    beq !chk_cur+
    jmp !no_pgm_cur+
!chk_cur:
    txa
    cmp zp_pgm_cursor
    bne !no_pgm_cur+
    lda #Strings.SC_CURSOR
    jmp !write_pgm_cur+
!no_pgm_cur:
    lda #SC_SPACE
!write_pgm_cur:
    sta (zp_ptr_lo), y

    // advance ptr past cursor col
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    // is this slot filled?
    ldx zp_edit_slot
    cpx zp_slots_used
    bcs !empty_slot+

    // draw block name from slot
    lda ProgramStore.slot_stride3_table, x
    tay
    lda ProgramStore.slot_array, y  // block_type
    tax
    lda Strings.block_name_ptrs_lo, x
    sta zp_cg_ptr_lo
    lda Strings.block_name_ptrs_hi, x
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr
    jmp !next_row+

!empty_slot:
    // fill 18 chars with dash
    ldy #0
!dash:
    lda #Strings.SC_EMPTY_SLOT
    sta (zp_ptr_lo), y
    iny
    cpy #18
    bne !dash-

!next_row:
    ldx zp_edit_slot
    inx
    jmp !row-
!done:
    rts

// ============================================================
// ui_render_value_bar
// Draws row 20 showing current editable parameter.
// Inputs: zp_edit_slot, zp_edit_val  Clobbers: A, X, Y
// ============================================================
ui_render_value_bar:
    // clear row 20 first
    lda #SC_SPACE
    ldy #0
!clr:
    sta SCREEN_RAM + 20*40, y
    iny
    cpy #40
    bne !clr-

    // draw " VALUE: " at col 0
    lda #<(SCREEN_RAM + 20*40)
    sta zp_ptr_lo
    lda #>(SCREEN_RAM + 20*40)
    sta zp_ptr_hi
    lda #<Strings.str_value_label
    sta zp_cg_ptr_lo
    lda #>Strings.str_value_label
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr  // ptr now at col 8

    // get block type of current slot
    ldx zp_edit_slot
    lda ProgramStore.slot_stride3_table, x
    tay
    lda ProgramStore.slot_array, y  // block_type
    tax
    lda BlocksData.block_param_type, x

    cmp #PARAM_COLOR
    beq !vb_color+
    cmp #PARAM_CHAR
    beq !vb_char+
    cmp #PARAM_SECS
    beq !vb_secs+

    // PARAM_NONE: draw "N/A"
    ldy #0
    lda #$0E
    sta (zp_ptr_lo), y
    iny
    lda #$2F
    sta (zp_ptr_lo), y
    iny
    lda #$01
    sta (zp_ptr_lo), y
    jmp !vb_done+

!vb_color:
    // draw colour name
    ldx zp_edit_val
    lda Strings.color_name_ptrs_lo, x
    sta zp_cg_ptr_lo
    lda Strings.color_name_ptrs_hi, x
    sta zp_cg_ptr_hi
    jsr draw_len_string_at_ptr
    // draw ◄► arrows (screen codes $1F and $1E)
    ldy #0
    lda #$1F
    sta (zp_ptr_lo), y
    iny
    lda #$1E
    sta (zp_ptr_lo), y
    jmp !vb_done+

!vb_char:
    // show PETSCII letter as screen code
    lda zp_edit_val
    sec
    sbc #$40            // PETSCII A=$41 → screen code $01
    ldy #0
    sta (zp_ptr_lo), y
    iny
    lda #$1F
    sta (zp_ptr_lo), y
    iny
    lda #$1E
    sta (zp_ptr_lo), y
    jmp !vb_done+

!vb_secs:
    // show digit 1-9 as screen code
    lda zp_edit_val
    clc
    adc #$30            // digit → screen code ('1'=$31 etc.)
    ldy #0
    sta (zp_ptr_lo), y
    iny
    lda #$1F
    sta (zp_ptr_lo), y
    iny
    lda #$1E
    sta (zp_ptr_lo), y

!vb_done:
    rts

// ============================================================
// ui_render_status
// Inputs:  A = status index (0=ready..6=editing)
// Clobbers: A, X, Y
// ============================================================
.label STATUS_READY   = 0
.label STATUS_ADDED   = 1
.label STATUS_FULL    = 2
.label STATUS_RUNNING = 3
.label STATUS_CLEARED = 4
.label STATUS_REMOVED = 5
.label STATUS_EDITING = 6

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
// Inputs:  zp_ptr_lo/hi    = screen dest
//          zp_cg_ptr_lo/hi = source (length-prefixed screen codes)
// Effect:  draws N chars; advances zp_ptr_lo/hi by N
// Clobbers: A, X, Y
// ============================================================
draw_len_string_at_ptr:
    ldy #0
    lda (zp_cg_ptr_lo), y   // length byte
    beq !done+
    tax                      // X = count
    // advance source past length byte
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
    // advance dest by Y (= chars drawn)
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
// Clobbers: A, X
// ============================================================
row_to_screen_offset:
    tax
    lda row_offsets_lo, x
    sta zp_ptr_lo
    lda row_offsets_hi, x
    sta zp_ptr_hi
    rts

// Pre-computed row start addresses (SCREEN_RAM = $0400, stride = 40)
row_offsets_lo:
    // rows 0-24: lo byte of ($0400 + row*40)
    .byte $00,$28,$50,$78,$A0,$C8,$F0,$18,$40,$68,$90,$B8,$E0,$08,$30,$58,$80,$A8,$D0,$F8,$20,$48,$70,$98,$C0

row_offsets_hi:
    // rows 0-24: hi byte of ($0400 + row*40)
    .byte $04,$04,$04,$04,$04,$04,$04,$05,$05,$05,$05,$05,$05,$06,$06,$06,$06,$06,$06,$06,$07,$07,$07,$07,$07

// Param type codes (mirrored here for param dispatch without namespace prefix)
.label PARAM_NONE  = BlocksData.PARAM_NONE
.label PARAM_COLOR = BlocksData.PARAM_COLOR
.label PARAM_CHAR  = BlocksData.PARAM_CHAR
.label PARAM_SECS  = BlocksData.PARAM_SECS

.assert "UIRender segment fits", * <= $1800, true
