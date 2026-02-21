// ============================================================
// asm_strings.asm — Mnemonic strings and hex conversion for Assembly View
// ============================================================
.filenamespace AsmStrings

.pc = $7000 "AsmStrings"

// ============================================================
// Mnemonic string table
// Maps mnemonic_id (from constants.asm MN_* constants) to PETSCII strings
// Each entry is 4 bytes: 3 chars + null terminator
// ============================================================
mnemonic_strings:
    .text "SEI"       // MN_SEI (0)
    .byte 0
    .text "CLI"       // MN_CLI (1)
    .byte 0
    .text "RTS"       // MN_RTS (2)
    .byte 0
    .text "LDA"       // MN_LDA_IMM (3)
    .byte 0
    .text "LDA"       // MN_LDA_ABS (4)
    .byte 0
    .text "LDA"       // MN_LDA_ZP (5)
    .byte 0
    .text "STA"       // MN_STA_ABS (6)
    .byte 0
    .text "STA"       // MN_STA_ZP (7)
    .byte 0
    .text "LDX"       // MN_LDX_IMM (8)
    .byte 0
    .text "LDY"       // MN_LDY_IMM (9)
    .byte 0
    .text "DEX"       // MN_DEX (10)
    .byte 0
    .text "DEC"       // MN_DEC_ZP (11)
    .byte 0
    .text "BNE"       // MN_BNE_REL (12)
    .byte 0
    .text "JSR"       // MN_JSR_ABS (13)
    .byte 0
    .text "JMP"       // MN_JMP_ABS (14)
    .byte 0

// ============================================================
// Operand format strings (for different addressing modes)
// ============================================================
operand_format_imm:     .text "#$"           // #$06
                        .byte 0
operand_format_abs:     .text "$"            // $D020
                        .byte 0
operand_format_zp:      .text "$"            // $FE
                        .byte 0
operand_format_rel:     .byte 0              // (relative - will show offset)
operand_format_none:    .byte 0              // no operand

// ============================================================
// hex_to_screen
// Converts a hex nibble (0-15) to screen code
// Inputs:  A = hex value (0-15)
// Outputs: A = screen code ('0'-'9' or 'A'-'F')
// Clobbers: none
// ============================================================
hex_to_screen:
    cmp #10
    bcs !alpha+
    // 0-9: add '0' screen code
    clc
    adc #$30        // '0' in screen code
    rts
!alpha:
    // A-F: add 'A' screen code minus 10
    sec
    sbc #10
    clc
    adc #$01        // 'A' in screen code (uppercase A = $01)
    rts

// ============================================================
// byte_to_hex_screen
// Converts a byte to two hex screen codes
// Inputs:  A = byte value
// Outputs: X = high nibble screen code, Y = low nibble screen code
// Clobbers: A
// ============================================================
byte_to_hex_screen:
    pha                 // save original byte
    // High nibble
    lsr
    lsr
    lsr
    lsr
    jsr hex_to_screen
    tax                 // X = high nibble screen code
    // Low nibble
    pla
    and #$0F
    jsr hex_to_screen
    tay                 // Y = low nibble screen code
    rts

// ============================================================
// render_mnemonic
// Renders a 3-character mnemonic to screen RAM at current position
// Inputs:  A = mnemonic_id (0-14)
//          zp_ptr_lo/hi = screen RAM destination pointer
// Outputs: Screen RAM updated, pointer NOT advanced
// Clobbers: A, X, Y
// ============================================================
render_mnemonic:
    // Calculate string offset: mnemonic_id * 4
    asl                 // A *= 2
    asl                 // A *= 4
    tax                 // X = offset into mnemonic_strings
    ldy #0
!copy_loop:
    lda mnemonic_strings, x
    beq !done+          // null terminator
    // Convert PETSCII to screen code
    cmp #$41            // 'A'
    bcc !not_alpha+
    cmp #$5B            // 'Z'+1
    bcs !not_alpha+
    sec
    sbc #$40            // uppercase A-Z: PETSCII $41-$5A → screen $01-$1A
!not_alpha:
    sta (zp_ptr_lo), y
    inx
    iny
    cpy #3              // max 3 chars
    bne !copy_loop-
!done:
    rts

// ============================================================
// render_hex_byte
// Renders a byte as 2-digit hex to screen RAM
// Inputs:  A = byte value
//          zp_ptr_lo/hi = screen RAM destination pointer
// Outputs: Screen RAM updated with 2 hex digits, pointer NOT advanced
// Clobbers: A, X, Y
// ============================================================
render_hex_byte:
    jsr byte_to_hex_screen  // X = high, Y = low
    ldy #0
    txa
    sta (zp_ptr_lo), y      // write high nibble
    iny
    tya
    sta (zp_ptr_lo), y      // write low nibble
    rts

// ============================================================
// render_hex_word
// Renders a 16-bit word as 4-digit hex to screen RAM
// Inputs:  A = high byte, X = low byte
//          zp_ptr_lo/hi = screen RAM destination pointer
// Outputs: Screen RAM updated with 4 hex digits, pointer NOT advanced
// Clobbers: A, X, Y, zp_gen_lo
// ============================================================
render_hex_word:
    stx zp_gen_lo           // save low byte
    jsr render_hex_byte     // render high byte
    // Advance pointer by 2
    lda zp_ptr_lo
    clc
    adc #2
    sta zp_ptr_lo
    bcc !+
    inc zp_ptr_hi
!:
    lda zp_gen_lo           // restore low byte
    jsr render_hex_byte     // render low byte
    // Restore pointer
    lda zp_ptr_lo
    sec
    sbc #2
    sta zp_ptr_lo
    bcs !+
    dec zp_ptr_hi
!:
    rts

.assert "AsmStrings segment fits", * <= $7400, true
