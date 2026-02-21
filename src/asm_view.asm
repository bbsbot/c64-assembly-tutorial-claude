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
    // Clear remaining lines with spaces
    lda #SC_SPACE
!pad_loop:
    sta (zp_ptr_lo), y
    inc zp_ptr_lo
    bne !+
    inc zp_ptr_hi
!:
    dey
    bne !pad_loop-
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

    // TODO: Render flags [NV-BDIZC]

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

.assert "AsmView segment fits", * <= $7000, true
