// ============================================================
// asm_view.asm — Assembly View rendering and stepping engine
// ============================================================
.filenamespace AsmView

.pc = $6800 "AsmView"

// ============================================================
// asm_view_render
// Main entry point: renders complete assembly view screen
// Inputs:  metadata at ASM_META_BUF, zp_asm_inst_count
// Outputs: full screen rendered
// Clobbers: A, X, Y, zp_ptr_lo/hi
// ============================================================
asm_view_render:
    jsr UIRender.ui_clear_screen
    jsr render_title
    jsr render_header
    jsr render_code_area
    jsr colorize_code_area
    jsr render_registers
    jsr render_block_annotation
    jsr render_help
    rts

// ============================================================
// render_title
// Row 0: "ASSEMBLY VIEW  [F1:RUN T:BLOCKS]"
// ============================================================
render_title:
    lda #<(SCREEN_RAM + 0)
    sta zp_ptr_lo
    lda #>(SCREEN_RAM + 0)
    sta zp_ptr_hi

    ldx #0
!loop:
    lda title_text, x
    beq !done+
    cmp #$20            // space
    beq !space+
    cmp #$3A            // ':'
    beq !colon+
    cmp #$5B            // '['
    beq !bracket_open+
    cmp #$5D            // ']'
    beq !bracket_close+
    // Convert uppercase letters
    cmp #$41
    bcc !write+
    cmp #$5B
    bcs !write+
    sec
    sbc #$40            // A-Z: PETSCII → screen code
    jmp !write+
!space:
    lda #SC_SPACE
    jmp !write+
!colon:
    lda #$3A
    jmp !write+
!bracket_open:
    lda #$5B
    jmp !write+
!bracket_close:
    lda #$5D
!write:
    ldy #0
    sta (zp_ptr_lo), y
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    inx
    jmp !loop-
!done:
    // Set color: white on black
    lda #<(COLOR_RAM + 0)
    sta zp_ptr_lo
    lda #>(COLOR_RAM + 0)
    sta zp_ptr_hi
    ldx #40
    lda #COL_WHITE
!color_loop:
    ldy #0
    sta (zp_ptr_lo), y
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    dex
    bne !color_loop-
    rts

title_text:
    .text "ASSEMBLY VIEW  [F1:RUN T:BLOCKS]"
    .byte 0

// ============================================================
// render_header
// Row 1: "ADDR  OPCODE MNEMONIC    OPERAND"
// ============================================================
render_header:
    lda #<(SCREEN_RAM + 40)
    sta zp_ptr_lo
    lda #>(SCREEN_RAM + 40)
    sta zp_ptr_hi

    ldx #0
!loop:
    lda header_text, x
    beq !done+
    cmp #$20
    beq !space+
    cmp #$41
    bcc !write+
    cmp #$5B
    bcs !write+
    sec
    sbc #$40
!space:
    lda #SC_SPACE
!write:
    ldy #0
    sta (zp_ptr_lo), y
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    inx
    jmp !loop-
!done:
    // Set color: cyan
    lda #<(COLOR_RAM + 40)
    sta zp_ptr_lo
    lda #>(COLOR_RAM + 40)
    sta zp_ptr_hi
    ldx #40
    lda #COL_CYAN
!color_loop:
    ldy #0
    sta (zp_ptr_lo), y
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    dex
    bne !color_loop-
    rts

header_text:
    .text "ADDR  OPCODE MNEMONIC    OPERAND"
    .byte 0

// ============================================================
// render_code_area
// Rows 2-18: disassembly lines (17 lines max)
// Renders from metadata buffer starting at zp_asm_cursor
// ============================================================
render_code_area:
    // Start at row 2
    lda #<(SCREEN_RAM + 80)     // row 2 = 40*2 = 80
    sta zp_ptr_lo
    lda #>(SCREEN_RAM + 80)
    sta zp_ptr_hi

    // Metadata pointer: ASM_META_BUF + (zp_asm_cursor * 6)
    lda zp_asm_cursor
    asl                         // *2
    sta zp_gen_lo
    asl                         // *4
    clc
    adc zp_gen_lo               // *6
    clc
    adc #<ASM_META_BUF
    sta zp_cg_ptr_lo
    lda #>ASM_META_BUF
    adc #0
    sta zp_cg_ptr_hi

    // Render up to 17 lines
    ldx #0                      // line counter
    ldy zp_asm_cursor           // instruction index
!line_loop:
    cpy zp_asm_inst_count       // past end of instructions?
    bcs !pad_remaining+

    // Render one disassembly line
    jsr render_disasm_line

    // Advance to next line (40 chars)
    lda zp_ptr_lo
    clc
    adc #40
    sta zp_ptr_lo
    bcc !+
    inc zp_ptr_hi
!:
    // Advance metadata pointer by 6 bytes
    lda zp_cg_ptr_lo
    clc
    adc #6
    sta zp_cg_ptr_lo
    bcc !+
    inc zp_cg_ptr_hi
!:
    iny                         // next instruction
    inx                         // next line
    cpx #17                     // 17 lines max
    bne !line_loop-
    rts

!pad_remaining:
    // Clear remaining lines with spaces (40 chars per line)
    lda #SC_SPACE
    ldy #0
!pad_loop:
    sta (zp_ptr_lo), y
    iny
    cpy #40
    bne !pad_loop-
    // Advance screen pointer by 40
    lda zp_ptr_lo
    clc
    adc #40
    sta zp_ptr_lo
    bcc !+
    inc zp_ptr_hi
!:
    inx
    cpx #17
    bne !pad_remaining-
    rts

// ============================================================
// render_disasm_line
// Renders one line of disassembly at current zp_ptr_lo/hi
// Inputs:  zp_cg_ptr_lo/hi = metadata entry pointer
//          zp_ptr_lo/hi = screen RAM position
//          Y = instruction index
// Format:  "ADDR  OPCODE MNEMONIC    OPERAND"
//          "5000  78     SEI"
// ============================================================
render_disasm_line:
    // Save instruction index
    sty zp_gen_hi

    // Read metadata: byte 5 = address_offset, byte 1 = mnemonic_id
    ldy #5
    lda (zp_cg_ptr_lo), y       // address_offset
    tax                         // X = offset from $5000
    ldy #1
    lda (zp_cg_ptr_lo), y       // mnemonic_id
    pha                         // save mnemonic_id

    // Render address: $5000 + offset
    txa
    clc
    adc #<GEN_CODE_BUF
    tax                         // X = low byte
    lda #>GEN_CODE_BUF
    adc #0                      // A = high byte

    // Render 4-digit hex address
    jsr AsmStrings.render_hex_word

    // Advance pointer by 6 (4 hex + 2 spaces)
    lda zp_ptr_lo
    clc
    adc #6
    sta zp_ptr_lo
    bcc !+
    inc zp_ptr_hi
!:

    // TODO: Render opcode bytes (placeholder: "XX")
    lda #$18                    // 'X' screen code
    ldy #0
    sta (zp_ptr_lo), y
    iny
    sta (zp_ptr_lo), y

    // Advance pointer by 9 (opcode + spaces)
    lda zp_ptr_lo
    clc
    adc #9
    sta zp_ptr_lo
    bcc !+
    inc zp_ptr_hi
!:

    // Render mnemonic (3 chars)
    pla                         // restore mnemonic_id
    jsr AsmStrings.render_mnemonic

    // Advance pointer by 12 (mnemonic + spaces)
    lda zp_ptr_lo
    clc
    adc #12
    sta zp_ptr_lo
    bcc !+
    inc zp_ptr_hi
!:

    // TODO: Render operand (placeholder)
    // For now, just leave it blank

    // Restore instruction index
    ldy zp_gen_hi
    rts

// ============================================================
// colorize_code_area
// Applies syntax highlighting colours to COLOR_RAM rows 2-18
// Walks metadata starting at zp_asm_cursor, colours each line
// based on mnemonic category. First visible line gets green bg.
// Inputs:  zp_asm_cursor, zp_asm_inst_count
// Clobbers: A, X, Y, zp_ptr_lo/hi, zp_cg_ptr_lo/hi
// ============================================================
colorize_code_area:
    // Color RAM pointer → row 2
    lda #<(COLOR_RAM + 80)          // row 2 = 40*2 = 80
    sta zp_ptr_lo
    lda #>(COLOR_RAM + 80)
    sta zp_ptr_hi

    // Metadata pointer: ASM_META_BUF + (zp_asm_cursor * 6)
    lda zp_asm_cursor
    asl                             // *2
    sta zp_gen_lo
    asl                             // *4
    clc
    adc zp_gen_lo                   // *6
    clc
    adc #<ASM_META_BUF
    sta zp_cg_ptr_lo
    lda #>ASM_META_BUF
    adc #0
    sta zp_cg_ptr_hi

    // Walk up to 17 lines
    ldx #0                          // line counter
    ldy zp_asm_cursor               // instruction index
!color_line_loop:
    cpy zp_asm_inst_count           // past end?
    bcc !color_have_inst+
    jmp !color_pad_remaining+
!color_have_inst:

    // Read mnemonic_id (byte 1) and source_block_idx (byte 0)
    sty zp_gen_hi                   // save instruction index
    ldy #1
    lda (zp_cg_ptr_lo), y          // A = mnemonic_id
    tay                             // Y = mnemonic_id (for table lookup)

    // Look up base colour from table
    lda AsmStrings.mnemonic_color_table, y

    // Check for VIC I/O override: if mnemonic is STA_ABS (6),
    // check source block — BORDER(0), BG(1), SPRITE(3) → cyan
    cpy #MN_STA_ABS
    bne !no_vic_override+
    pha                             // save base colour
    ldy #0
    lda (zp_cg_ptr_lo), y          // A = source_block_idx
    cmp #BLOCK_SET_BORDER
    beq !is_vic+
    cmp #BLOCK_SET_BG
    beq !is_vic+
    cmp #BLOCK_SHOW_SPRITE
    beq !is_vic+
    pla                             // not VIC — restore base colour
    jmp !no_vic_override+
!is_vic:
    pla                             // discard base colour
    lda #SYN_VIC_IO                 // use cyan
!no_vic_override:

    // Also check: LDA_IMM before a VIC STA should also be cyan
    // We detect this by checking source_block_idx for VIC blocks
    // when mnemonic is LDA_IMM
    pha                             // save current colour
    tya                             // Y still has mnemonic_id from before
    // Actually Y was clobbered. Re-read mnemonic_id.
    ldy #1
    lda (zp_cg_ptr_lo), y
    cmp #MN_LDA_IMM
    bne !no_lda_vic+
    ldy #0
    lda (zp_cg_ptr_lo), y          // source_block_idx
    cmp #BLOCK_SET_BORDER
    beq !lda_is_vic+
    cmp #BLOCK_SET_BG
    beq !lda_is_vic+
    cmp #BLOCK_SHOW_SPRITE
    beq !lda_is_vic+
    jmp !no_lda_vic+
!lda_is_vic:
    pla                             // discard previous colour
    lda #SYN_VIC_IO                 // use cyan for LDA paired with VIC write
    jmp !apply_colour+
!no_lda_vic:
    pla                             // restore colour

!apply_colour:
    // If this is line 0 (first visible line = cursor), use green
    cpx #0
    bne !not_cursor_line+
    lda #SYN_CURSOR_BG
!not_cursor_line:

    // Fill 40 bytes of COLOR_RAM for this row
    pha                             // save colour
    ldy #0
!fill_color:
    sta (zp_ptr_lo), y
    iny
    cpy #40
    bne !fill_color-
    pla                             // restore colour (for stack balance)

    // Advance COLOR_RAM pointer by 40
    lda zp_ptr_lo
    clc
    adc #40
    sta zp_ptr_lo
    bcc !+
    inc zp_ptr_hi
!:

    // Advance metadata pointer by 6
    lda zp_cg_ptr_lo
    clc
    adc #6
    sta zp_cg_ptr_lo
    bcc !+
    inc zp_cg_ptr_hi
!:

    ldy zp_gen_hi                   // restore instruction index
    iny                             // next instruction
    inx                             // next line
    cpx #17
    beq !color_done+
    jmp !color_line_loop-
!color_done:
    rts

!color_pad_remaining:
    // Remaining empty lines: dark grey
    lda #COL_DK_GREY
!pad_color_loop:
    ldy #0
!pad_fill:
    sta (zp_ptr_lo), y
    iny
    cpy #40
    bne !pad_fill-
    // Advance pointer by 40
    lda zp_ptr_lo
    clc
    adc #40
    sta zp_ptr_lo
    bcc !+
    inc zp_ptr_hi
!:
    lda #COL_DK_GREY
    inx
    cpx #17
    bne !pad_color_loop-
    rts

// ============================================================
// render_registers
// Row 19: "A:00 X:00 Y:00 SP:FF [NV-BDIZC]"
// ============================================================
render_registers:
    lda #<(SCREEN_RAM + 40*19)
    sta zp_ptr_lo
    lda #>(SCREEN_RAM + 40*19)
    sta zp_ptr_hi

    // "A:"
    lda #$01                    // 'A'
    ldy #0
    sta (zp_ptr_lo), y
    iny
    lda #$3A                    // ':'
    sta (zp_ptr_lo), y
    iny

    // Hex value of A register
    lda zp_ptr_lo
    clc
    adc #2
    sta zp_ptr_lo
    lda zp_asm_reg_a
    jsr AsmStrings.render_hex_byte

    // " X:"
    lda zp_ptr_lo
    clc
    adc #3
    sta zp_ptr_lo
    lda #$18                    // 'X'
    ldy #0
    sta (zp_ptr_lo), y
    iny
    lda #$3A
    sta (zp_ptr_lo), y

    lda zp_ptr_lo
    clc
    adc #2
    sta zp_ptr_lo
    lda zp_asm_reg_x
    jsr AsmStrings.render_hex_byte

    // " Y:"
    lda zp_ptr_lo
    clc
    adc #3
    sta zp_ptr_lo
    lda #$19                    // 'Y'
    ldy #0
    sta (zp_ptr_lo), y
    iny
    lda #$3A
    sta (zp_ptr_lo), y

    lda zp_ptr_lo
    clc
    adc #2
    sta zp_ptr_lo
    lda zp_asm_reg_y
    jsr AsmStrings.render_hex_byte

    // " SP:"
    lda zp_ptr_lo
    clc
    adc #3
    sta zp_ptr_lo
    lda #$13                    // 'S'
    ldy #0
    sta (zp_ptr_lo), y
    iny
    lda #$10                    // 'P'
    sta (zp_ptr_lo), y
    iny
    lda #$3A
    sta (zp_ptr_lo), y

    lda zp_ptr_lo
    clc
    adc #3
    sta zp_ptr_lo
    lda zp_asm_reg_sp
    jsr AsmStrings.render_hex_byte

    // Render flags " [NV-BDIZC]"
    lda zp_ptr_lo
    clc
    adc #3
    sta zp_ptr_lo
    bcc !+
    inc zp_ptr_hi
!:
    // '['
    lda #$5B
    ldy #0
    sta (zp_ptr_lo), y
    iny
    // N flag (bit 7)
    lda zp_asm_reg_flags
    and #$80
    bne !flag_n_set+
    lda #$2D                    // '-'
    jmp !flag_n_done+
!flag_n_set:
    lda #$0E                    // 'N' screen code
!flag_n_done:
    sta (zp_ptr_lo), y
    iny
    // V flag (bit 6)
    lda zp_asm_reg_flags
    and #$40
    bne !flag_v_set+
    lda #$2D
    jmp !flag_v_done+
!flag_v_set:
    lda #$16                    // 'V' screen code
!flag_v_done:
    sta (zp_ptr_lo), y
    iny
    // - (bit 5, always 1, show '-')
    lda #$2D
    sta (zp_ptr_lo), y
    iny
    // B flag (bit 4)
    lda zp_asm_reg_flags
    and #$10
    bne !flag_b_set+
    lda #$2D
    jmp !flag_b_done+
!flag_b_set:
    lda #$02                    // 'B' screen code
!flag_b_done:
    sta (zp_ptr_lo), y
    iny
    // D flag (bit 3)
    lda zp_asm_reg_flags
    and #$08
    bne !flag_d_set+
    lda #$2D
    jmp !flag_d_done+
!flag_d_set:
    lda #$04                    // 'D' screen code
!flag_d_done:
    sta (zp_ptr_lo), y
    iny
    // I flag (bit 2)
    lda zp_asm_reg_flags
    and #$04
    bne !flag_i_set+
    lda #$2D
    jmp !flag_i_done+
!flag_i_set:
    lda #$09                    // 'I' screen code
!flag_i_done:
    sta (zp_ptr_lo), y
    iny
    // Z flag (bit 1)
    lda zp_asm_reg_flags
    and #$02
    bne !flag_z_set+
    lda #$2D
    jmp !flag_z_done+
!flag_z_set:
    lda #$1A                    // 'Z' screen code
!flag_z_done:
    sta (zp_ptr_lo), y
    iny
    // C flag (bit 0)
    lda zp_asm_reg_flags
    and #$01
    bne !flag_c_set+
    lda #$2D
    jmp !flag_c_done+
!flag_c_set:
    lda #$03                    // 'C' screen code
!flag_c_done:
    sta (zp_ptr_lo), y
    iny
    // ']'
    lda #$5D
    sta (zp_ptr_lo), y

    // Color: yellow
    lda #<(COLOR_RAM + 40*19)
    sta zp_ptr_lo
    lda #>(COLOR_RAM + 40*19)
    sta zp_ptr_hi
    ldx #40
    lda #COL_YELLOW
!color_loop:
    ldy #0
    sta (zp_ptr_lo), y
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    dex
    bne !color_loop-
    rts

// ============================================================
// render_block_annotation
// Row 20: "BLOCK #1: SET BORDER (CYAN)"
// ============================================================
render_block_annotation:
    lda #<(SCREEN_RAM + 40*20)
    sta zp_ptr_lo
    lda #>(SCREEN_RAM + 40*20)
    sta zp_ptr_hi

    // TODO: Read current instruction's source_block_idx from metadata
    // For now, placeholder text
    ldx #0
!loop:
    lda block_anno_text, x
    beq !done+
    cmp #$20
    beq !space+
    cmp #$23
    beq !hash+
    cmp #$3A
    beq !colon+
    cmp #$41
    bcc !write+
    cmp #$5B
    bcs !write+
    sec
    sbc #$40
    jmp !write+
!space:
    lda #SC_SPACE
    jmp !write+
!hash:
    lda #$23
    jmp !write+
!colon:
    lda #$3A
!write:
    ldy #0
    sta (zp_ptr_lo), y
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    inx
    jmp !loop-
!done:
    rts

block_anno_text:
    .text "BLOCK #0: (PLACEHOLDER)"
    .byte 0

// ============================================================
// render_help
// Row 21: "UP/DN:SCROLL S:STEP F1:RUN T:EXIT"
// ============================================================
render_help:
    lda #<(SCREEN_RAM + 40*21)
    sta zp_ptr_lo
    lda #>(SCREEN_RAM + 40*21)
    sta zp_ptr_hi

    ldx #0
!loop:
    lda help_text, x
    beq !done+
    cmp #$20
    beq !space+
    cmp #$2F
    beq !slash+
    cmp #$3A
    beq !colon+
    cmp #$41
    bcc !write+
    cmp #$5B
    bcs !write+
    sec
    sbc #$40
    jmp !write+
!space:
    lda #SC_SPACE
    jmp !write+
!slash:
    lda #$2F
    jmp !write+
!colon:
    lda #$3A
!write:
    ldy #0
    sta (zp_ptr_lo), y
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    inx
    jmp !loop-
!done:
    // Color: light grey
    lda #<(COLOR_RAM + 40*21)
    sta zp_ptr_lo
    lda #>(COLOR_RAM + 40*21)
    sta zp_ptr_hi
    ldx #40
    lda #COL_LT_GREY
!color_loop:
    ldy #0
    sta (zp_ptr_lo), y
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    dex
    bne !color_loop-
    rts

help_text:
    .text "UP/DN:SCROLL S:STEP F1:RUN T:EXIT"
    .byte 0

// ============================================================
// asm_step_init
// Initialise stepping mode: reset shadow registers, clear VIC,
// set cursor to instruction 0, re-render.
// Inputs:  none (assumes codegen has been run)
// Clobbers: A, X, Y
// ============================================================
asm_step_init:
    // Reset shadow registers
    lda #0
    sta zp_asm_reg_a
    sta zp_asm_reg_x
    sta zp_asm_reg_y
    sta zp_asm_reg_flags
    sta zp_asm_cursor
    lda #$FF
    sta zp_asm_reg_sp
    // Clear VIC hardware
    lda #COL_BLACK
    sta VIC_BORDER
    sta VIC_BG0
    lda #0
    sta VIC_SPR_ENA
    // Re-render
    jsr asm_view_render
    rts

// ============================================================
// asm_step_execute_one
// Execute one simulated instruction at zp_asm_cursor.
// Reads metadata, dispatches to handler, advances cursor,
// re-renders display, plays SID beep.
// Inputs:  zp_asm_cursor = current instruction index
// Clobbers: A, X, Y, zp_ptr, zp_cg_ptr, zp_gen_lo/hi
// ============================================================
asm_step_execute_one:
    // Check bounds: if cursor >= inst_count, do nothing
    lda zp_asm_cursor
    cmp zp_asm_inst_count
    bcc !in_bounds+
    rts
!in_bounds:

    // Calculate metadata pointer: ASM_META_BUF + (cursor * 6)
    lda zp_asm_cursor
    asl                         // *2
    sta zp_gen_lo
    asl                         // *4
    clc
    adc zp_gen_lo               // *6
    clc
    adc #<ASM_META_BUF
    sta zp_cg_ptr_lo
    lda #>ASM_META_BUF
    adc #0
    sta zp_cg_ptr_hi

    // Read mnemonic_id (byte 1)
    ldy #1
    lda (zp_cg_ptr_lo), y
    tax                         // X = mnemonic_id

    // Read source_block_idx (byte 0) for WAIT detection
    ldy #0
    lda (zp_cg_ptr_lo), y
    sta zp_gen_hi               // zp_gen_hi = source_block_idx

    // Read address_offset (byte 5) for operand lookup
    ldy #5
    lda (zp_cg_ptr_lo), y
    sta zp_gen_lo               // zp_gen_lo = address_offset

    // Dispatch via jump table indexed by mnemonic_id (X)
    lda step_handler_lo, x
    sta zp_ptr_lo
    lda step_handler_hi, x
    sta zp_ptr_hi
    jmp (zp_ptr_lo)
    // Handlers return by jumping to step_done

// After handler: advance cursor, re-render, beep
step_done:
    inc zp_asm_cursor
    jsr asm_view_render
    jsr asm_step_beep
    rts

// Jump table for step handlers (15 entries)
step_handler_lo:
    .byte <step_sei, <step_cli, <step_rts
    .byte <step_lda_imm, <step_lda_abs, <step_lda_zp
    .byte <step_sta_abs, <step_sta_zp
    .byte <step_ldx_imm, <step_ldy_imm
    .byte <step_dex, <step_dec_zp
    .byte <step_bne, <step_jsr, <step_jmp
step_handler_hi:
    .byte >step_sei, >step_cli, >step_rts
    .byte >step_lda_imm, >step_lda_abs, >step_lda_zp
    .byte >step_sta_abs, >step_sta_zp
    .byte >step_ldx_imm, >step_ldy_imm
    .byte >step_dex, >step_dec_zp
    .byte >step_bne, >step_jsr, >step_jmp

// ============================================================
// Step Handlers
// On entry: zp_gen_lo = address_offset into GEN_CODE_BUF
//           zp_gen_hi = source_block_idx
//           zp_cg_ptr_lo/hi = metadata pointer
// Each handler jumps to step_done when finished.
// ============================================================

// --- SEI: Set I flag in shadow flags ---
step_sei:
    lda zp_asm_reg_flags
    ora #$04                    // I flag = bit 2
    sta zp_asm_reg_flags
    jmp step_done

// --- CLI: Clear I flag ---
step_cli:
    lda zp_asm_reg_flags
    and #$FB                    // clear bit 2
    sta zp_asm_reg_flags
    jmp step_done

// --- RTS: Stop stepping, return to ASM_VIEW ---
step_rts:
    // Play completion chime (3 ascending notes)
    jsr asm_step_chime
    // Don't advance cursor — signal caller to exit stepping
    lda #STATE_ASM_VIEW
    sta zp_state
    // Re-render in view mode
    jsr asm_view_render
    rts                         // return directly, skip step_done

// --- LDA #imm: load immediate into shadow A ---
step_lda_imm:
    // Operand is at GEN_CODE_BUF + address_offset + 1
    ldx zp_gen_lo
    inx                         // skip opcode byte
    lda GEN_CODE_BUF, x
    sta zp_asm_reg_a
    jsr update_nz_flags
    jmp step_done

// --- LDA abs: load from absolute address ---
step_lda_abs:
    // Operand word at GEN_CODE_BUF + offset + 1 (lo) / + 2 (hi)
    ldx zp_gen_lo
    inx
    lda GEN_CODE_BUF, x        // addr lo
    sta zp_ptr_lo
    inx
    lda GEN_CODE_BUF, x        // addr hi
    sta zp_ptr_hi
    // Read from that address
    ldy #0
    lda (zp_ptr_lo), y
    sta zp_asm_reg_a
    jsr update_nz_flags
    jmp step_done

// --- LDA zp: load from zero page ---
step_lda_zp:
    ldx zp_gen_lo
    inx                         // skip opcode
    lda GEN_CODE_BUF, x        // ZP address
    tax
    lda $00, x                  // read from ZP
    sta zp_asm_reg_a
    jsr update_nz_flags
    jmp step_done

// --- STA abs: write shadow A to absolute address (live VIC write!) ---
step_sta_abs:
    ldx zp_gen_lo
    inx
    lda GEN_CODE_BUF, x        // addr lo
    sta zp_ptr_lo
    inx
    lda GEN_CODE_BUF, x        // addr hi
    sta zp_ptr_hi
    ldy #0
    lda zp_asm_reg_a
    sta (zp_ptr_lo), y          // LIVE WRITE — VIC registers change!
    jmp step_done

// --- STA zp: write shadow A to zero page ---
step_sta_zp:
    ldx zp_gen_lo
    inx
    lda GEN_CODE_BUF, x        // ZP address
    tax
    lda zp_asm_reg_a
    sta $00, x
    jmp step_done

// --- LDX #imm ---
step_ldx_imm:
    ldx zp_gen_lo
    inx
    lda GEN_CODE_BUF, x
    sta zp_asm_reg_x
    jsr update_nz_flags
    jmp step_done

// --- LDY #imm ---
step_ldy_imm:
    ldx zp_gen_lo
    inx
    lda GEN_CODE_BUF, x
    sta zp_asm_reg_y
    jsr update_nz_flags
    jmp step_done

// --- DEX: decrement shadow X ---
step_dex:
    // Check if this is part of a WAIT block — auto-skip entire loop
    lda zp_gen_hi               // source_block_idx
    cmp #BLOCK_WAIT
    bne !normal_dex+
    // WAIT block optimisation: skip DEX + BNE + DEC + BNE + DEC + BNE
    // (6 instructions to skip, but we only skip 5 more since cursor
    //  advances by 1 in step_done for DEX itself)
    lda zp_asm_cursor
    clc
    adc #5                      // skip past the remaining WAIT loop instrs
    sta zp_asm_cursor
    // Set shadow X=0, clear Z=0 (loop finished)
    lda #0
    sta zp_asm_reg_x
    lda zp_asm_reg_flags
    ora #$02                    // set Z flag (result is zero)
    sta zp_asm_reg_flags
    jmp step_done
!normal_dex:
    dec zp_asm_reg_x
    lda zp_asm_reg_x
    jsr update_nz_flags
    jmp step_done

// --- DEC zp ---
step_dec_zp:
    // Also check WAIT optimisation
    lda zp_gen_hi
    cmp #BLOCK_WAIT
    bne !normal_dec+
    // Inside WAIT loop — auto-skip remaining (DEC $FE + BNE + DEC $FF + BNE)
    // Skip 3 more instructions
    lda zp_asm_cursor
    clc
    adc #3
    sta zp_asm_cursor
    jmp step_done
!normal_dec:
    ldx zp_gen_lo
    inx
    lda GEN_CODE_BUF, x        // ZP address
    tax
    dec $00, x
    lda $00, x
    jsr update_nz_flags
    jmp step_done

// --- BNE rel: if Z clear in shadow, auto-skip ---
step_bne:
    // For WAIT blocks, we've already auto-skipped, so this shouldn't
    // normally be reached for WAIT. If it is, just skip.
    lda zp_gen_hi
    cmp #BLOCK_WAIT
    beq !skip_bne+
    // Normal BNE: check Z flag
    lda zp_asm_reg_flags
    and #$02                    // Z flag
    bne !skip_bne+              // Z set = not taken, just advance
    // Z clear = branch taken — but in stepping mode, auto-skip
    // (we don't want infinite loops in the UI)
!skip_bne:
    jmp step_done

// --- JSR abs: display annotation, auto-skip ---
step_jsr:
    // Just advance past it — JSR targets (like CHROUT) are
    // opaque to the stepper. The annotation shows the address.
    jmp step_done

// --- JMP abs: check for loop-back ---
step_jmp:
    ldx zp_gen_lo
    inx
    lda GEN_CODE_BUF, x        // target lo
    sta zp_ptr_lo
    inx
    lda GEN_CODE_BUF, x        // target hi
    sta zp_ptr_hi
    // Check if target is $5000 (loop-back)
    lda zp_ptr_hi
    cmp #>GEN_CODE_BUF
    bne !not_loop+
    lda zp_ptr_lo
    cmp #<GEN_CODE_BUF
    bne !not_loop+
    // Loop-back: reset cursor to 0
    lda #0
    sta zp_asm_cursor
    jsr asm_view_render
    jsr asm_step_beep
    rts                         // return directly, skip step_done increment
!not_loop:
    jmp step_done

// ============================================================
// update_nz_flags
// Updates N and Z flags in shadow register based on value in A
// Inputs:  A = value to check (also stored in relevant register)
// Outputs: zp_asm_reg_flags updated
// Clobbers: none (preserves A via stack)
// ============================================================
update_nz_flags:
    pha
    // Clear N and Z bits first
    lda zp_asm_reg_flags
    and #$7D                    // clear bit 7 (N) and bit 1 (Z)
    sta zp_asm_reg_flags
    pla
    pha
    // Check Z: if A == 0, set Z
    bne !not_zero+
    lda zp_asm_reg_flags
    ora #$02
    sta zp_asm_reg_flags
    jmp !check_n+
!not_zero:
!check_n:
    pla
    pha
    // Check N: if bit 7 set
    and #$80
    beq !not_neg+
    lda zp_asm_reg_flags
    ora #$80
    sta zp_asm_reg_flags
!not_neg:
    pla
    rts

// ============================================================
// asm_step_beep
// Quick SID beep on voice 1. Different pitch by instruction type.
// Clobbers: A
// ============================================================
.label SID_BASE = $D400
asm_step_beep:
    // Set volume
    lda #$0F
    sta SID_BASE + $18          // volume max
    // Set ADSR: short attack, no sustain, short release
    lda #$00
    sta SID_BASE + $05          // AD: attack=0, decay=0
    lda #$F0
    sta SID_BASE + $06          // SR: sustain=15, release=0
    // Frequency: mid tone ($1000)
    lda #$00
    sta SID_BASE + $00          // freq lo
    lda #$10
    sta SID_BASE + $01          // freq hi
    // Gate on (pulse waveform)
    lda #$41                    // pulse + gate
    sta SID_BASE + $04          // control
    // Pulse width
    lda #$00
    sta SID_BASE + $02
    lda #$08
    sta SID_BASE + $03          // pulse width = $0800
    // Short delay (wait ~2000 cycles)
    ldx #0
!beep_delay:
    inx
    bne !beep_delay-
    // Gate off
    lda #$40                    // pulse, no gate
    sta SID_BASE + $04
    rts

// ============================================================
// asm_step_chime
// 3-note ascending chime for RTS completion
// Clobbers: A, X
// ============================================================
asm_step_chime:
    // Note 1: low
    lda #$08
    sta SID_BASE + $01
    lda #$41
    sta SID_BASE + $04
    ldx #0
!c1:
    inx
    bne !c1-
    lda #$40
    sta SID_BASE + $04
    // Note 2: mid
    lda #$10
    sta SID_BASE + $01
    lda #$41
    sta SID_BASE + $04
    ldx #0
!c2:
    inx
    bne !c2-
    lda #$40
    sta SID_BASE + $04
    // Note 3: high
    lda #$20
    sta SID_BASE + $01
    lda #$41
    sta SID_BASE + $04
    ldx #0
!c3:
    inx
    bne !c3-
    lda #$40
    sta SID_BASE + $04
    rts

.assert "AsmView segment fits", * <= $7000, true
