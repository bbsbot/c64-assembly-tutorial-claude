// ============================================================
// codegen.asm — Walk slots, emit 6502 code to $5000, JSR $5000
// ============================================================
.filenamespace Codegen

.pc = $3000 "Codegen"

// Jump table for emitters (6 entries, lo/hi pairs)
emit_table_lo:
    .byte <emit_border, <emit_bg, <emit_print, <emit_sprite, <emit_wait, <emit_loop_back
emit_table_hi:
    .byte >emit_border, >emit_bg, >emit_print, >emit_sprite, >emit_wait, >emit_loop_back

// ============================================================
// codegen_run
// Inputs:  slot_array, zp_slots_used
// Outputs: GEN_CODE_BUF contains executable 6502 code; runs it
// Clobbers: A, X, Y, zp_cg_ptr, zp_ptr, zp_gen_lo/hi
// ============================================================
codegen_run:
    // Initialize code buffer pointer
    lda #<GEN_CODE_BUF
    sta zp_cg_ptr_lo
    lda #>GEN_CODE_BUF
    sta zp_cg_ptr_hi

    // Initialize metadata tracking
    lda #0
    sta zp_asm_inst_count           // reset instruction counter
    lda #<ASM_META_BUF
    sta zp_ptr_lo                   // metadata write pointer (lo)
    lda #>ASM_META_BUF
    sta zp_ptr_hi                   // metadata write pointer (hi)

    // Emit SEI at start of generated program
    lda #$78
    jsr emit_byte
    // Track SEI instruction in metadata
    lda #MN_SEI
    ldx #$FF                        // no source block for SEI (system opcode)
    jsr emit_instruction_meta

    // Walk slots 0 .. zp_slots_used-1
    ldx #0
slot_loop:
    cpx zp_slots_used
    bne slot_continue
    jmp slots_done
slot_continue:

    // Read slot[x].type and .param
    lda ProgramStore.slot_stride3_table, x
    tay
    lda ProgramStore.slot_array, y      // A = block_type
    pha
    lda ProgramStore.slot_array+1, y    // A = param_value
    tay                                 // Y = param
    pla                                 // A = block_type
    stx zp_ptr_lo                       // save slot index X

    // Dispatch via jump table: jmp (emit_table, A)
    tax                                 // X = block_type (0..5)
    lda emit_table_lo, x
    sta zp_gen_lo
    lda emit_table_hi, x
    sta zp_gen_hi
    jmp (zp_gen_lo)                     // indirect jump to emitter
    // NOTE: each emitter ends with jmp next_slot

next_slot:
    ldx zp_ptr_lo           // restore slot index
    inx
    jmp slot_loop

slots_done:
    // Emit CLI + RTS
    lda #$58
    jsr emit_byte           // CLI
    lda #MN_CLI
    ldx #$FF                // no source block
    jsr emit_instruction_meta
    lda #$60
    jsr emit_byte           // RTS
    lda #MN_RTS
    ldx #$FF                // no source block
    jsr emit_instruction_meta
    // Execute generated program
    jsr GEN_CODE_BUF
    rts

// ============================================================
// Emitters — each ends with jmp next_slot
// On entry: Y = param_value, zp_ptr_lo = saved slot index
// ============================================================

// SET BORDER: LDA #n / STA $D020
emit_border:
    sty zp_gen_lo           // save param — emit_byte clobbers Y via ldy #0
    // LDA #n
    lda #$A9
    jsr emit_byte
    lda zp_gen_lo
    jsr emit_byte
    lda #MN_LDA_IMM
    ldx zp_ptr_lo           // source block index
    jsr emit_instruction_meta
    // STA $D020
    lda #$8D
    jsr emit_byte
    lda #$20
    jsr emit_byte
    lda #$D0
    jsr emit_byte
    lda #MN_STA_ABS
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    jmp next_slot

// SET BG: LDA #n / STA $D021
emit_bg:
    sty zp_gen_lo           // save param — emit_byte clobbers Y via ldy #0
    // LDA #n
    lda #$A9
    jsr emit_byte
    lda zp_gen_lo
    jsr emit_byte
    lda #MN_LDA_IMM
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // STA $D021
    lda #$8D
    jsr emit_byte
    lda #$21
    jsr emit_byte
    lda #$D0
    jsr emit_byte
    lda #MN_STA_ABS
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    jmp next_slot

// PRINT: LDA #c / JSR $FFD2
emit_print:
    sty zp_gen_lo           // save param — emit_byte clobbers Y via ldy #0
    // LDA #c
    lda #$A9
    jsr emit_byte
    lda zp_gen_lo
    jsr emit_byte
    lda #MN_LDA_IMM
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // JSR $FFD2
    lda #$20
    jsr emit_byte
    lda #$D2
    jsr emit_byte
    lda #$FF
    jsr emit_byte
    lda #MN_JSR_ABS
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    jmp next_slot

// SHOW SPRITE: enable spr0 at X=150, Y=130, colour=14 (light blue)
emit_sprite:
    // LDA #1
    lda #$A9
    jsr emit_byte
    lda #$01
    jsr emit_byte
    lda #MN_LDA_IMM
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // STA $D015
    lda #$8D
    jsr emit_byte
    lda #$15
    jsr emit_byte
    lda #$D0
    jsr emit_byte
    lda #MN_STA_ABS
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // LDA #150
    lda #$A9
    jsr emit_byte
    lda #150
    jsr emit_byte
    lda #MN_LDA_IMM
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // STA $D000
    lda #$8D
    jsr emit_byte
    lda #$00
    jsr emit_byte
    lda #$D0
    jsr emit_byte
    lda #MN_STA_ABS
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // LDA #130
    lda #$A9
    jsr emit_byte
    lda #130
    jsr emit_byte
    lda #MN_LDA_IMM
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // STA $D001
    lda #$8D
    jsr emit_byte
    lda #$01
    jsr emit_byte
    lda #$D0
    jsr emit_byte
    lda #MN_STA_ABS
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // LDA #14
    lda #$A9
    jsr emit_byte
    lda #14
    jsr emit_byte
    lda #MN_LDA_IMM
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // STA $D027  (sprite 0 colour = light blue)
    lda #$8D
    jsr emit_byte
    lda #$27
    jsr emit_byte
    lda #$D0
    jsr emit_byte
    lda #MN_STA_ABS
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    jmp next_slot

// WAIT n seconds
// n*768 outer loops, each loop = 256 × DEX (5 cycles) ≈ 985248/5 ≈ 197049 cycles/s ÷ 768
// outer_hi = n*3, outer_lo = 0
// Generated code (20 bytes):
//  LDA #0   STA $FE        outer_lo = 0
//  LDA #hi  STA $FF        outer_hi = n*3
//  LDX #$FF               outer label
//  DEX / BNE -3            inner loop (256 × 5 cycles)
//  DEC $FE / BNE outer(-9) 16-bit decrement lo
//  DEC $FF / BNE outer(-13) 16-bit decrement hi
emit_wait:
    tya                     // A = n (1..9)
    sta zp_gen_lo           // save n
    asl                     // A = n*2
    clc
    adc zp_gen_lo           // A = n*3
    sta zp_gen_hi           // outer_hi

    // LDA #0
    lda #$A9
    jsr emit_byte
    lda #$00
    jsr emit_byte
    lda #MN_LDA_IMM
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // STA $FE
    lda #$85
    jsr emit_byte
    lda #$FE
    jsr emit_byte
    lda #MN_STA_ZP
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // LDA #hi
    lda #$A9
    jsr emit_byte
    lda zp_gen_hi
    jsr emit_byte
    lda #MN_LDA_IMM
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // STA $FF
    lda #$85
    jsr emit_byte
    lda #$FF
    jsr emit_byte
    lda #MN_STA_ZP
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // LDX #$FF
    lda #$A2
    jsr emit_byte
    lda #$FF
    jsr emit_byte
    lda #MN_LDX_IMM
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // DEX
    lda #$CA
    jsr emit_byte
    lda #MN_DEX
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // BNE -3
    lda #$D0
    jsr emit_byte
    lda #$FD
    jsr emit_byte
    lda #MN_BNE_REL
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // DEC $FE
    lda #$C6
    jsr emit_byte
    lda #$FE
    jsr emit_byte
    lda #MN_DEC_ZP
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // BNE -9
    lda #$D0
    jsr emit_byte
    lda #$F7
    jsr emit_byte
    lda #MN_BNE_REL
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // DEC $FF
    lda #$C6
    jsr emit_byte
    lda #$FF
    jsr emit_byte
    lda #MN_DEC_ZP
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // BNE -13
    lda #$D0
    jsr emit_byte
    lda #$F3
    jsr emit_byte
    lda #MN_BNE_REL
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    jmp next_slot

// LOOP BACK: check stop flag; if clear, JMP $5000; else fall through to CLI/RTS
// Generated bytes (7):
//   A5 11       LDA zp_stop_flag   ; load stop flag ($11)
//   D0 03       BNE +3             ; if set, skip JMP (fall through to CLI/RTS)
//   4C 00 50    JMP $5000          ; loop back to start of generated code
emit_loop_back:
    // LDA zp_stop_flag
    lda #$A5
    jsr emit_byte
    lda #zp_stop_flag
    jsr emit_byte
    lda #MN_LDA_ZP
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // BNE +3
    lda #$D0
    jsr emit_byte
    lda #$03
    jsr emit_byte
    lda #MN_BNE_REL
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    // JMP $5000
    lda #$4C
    jsr emit_byte
    lda #<GEN_CODE_BUF
    jsr emit_byte
    lda #>GEN_CODE_BUF
    jsr emit_byte
    lda #MN_JMP_ABS
    ldx zp_ptr_lo
    jsr emit_instruction_meta
    jmp next_slot

// ============================================================
// emit_byte
// Inputs:  A = byte to emit
// Outputs: byte at [zp_cg_ptr]; pointer advanced
// Clobbers: preserves A (via stack)
// ============================================================
emit_byte:
    pha
    ldy #0
    sta (zp_cg_ptr_lo), y
    inc zp_cg_ptr_lo
    bne !+
    inc zp_cg_ptr_hi
!:
    pla
    rts

// ============================================================
// emit_instruction_meta
// Inputs:  A = mnemonic_id, X = source_block_idx (or $FF for system)
// Outputs: 6-byte metadata entry written to ASM_META_BUF
// Clobbers: Y, zp_ptr_lo/hi (metadata pointer)
// Note: Operands and length are currently set to 0 (Phase 1 stub)
// ============================================================
emit_instruction_meta:
    pha                         // save mnemonic_id
    txa                         // save source_block_idx
    pha

    // Calculate current code offset from $5000
    lda zp_cg_ptr_lo
    sec
    sbc #<GEN_CODE_BUF
    tax                         // X = address_offset lo (we only need lo byte)

    // Write metadata entry (6 bytes)
    ldy #0
    pla                         // restore source_block_idx
    sta (zp_ptr_lo), y          // byte 0: source_block_idx (temp - will fix order)

    iny
    pla                         // restore mnemonic_id
    sta (zp_ptr_lo), y          // byte 1: mnemonic_id (temp - will fix order)

    iny
    lda #0
    sta (zp_ptr_lo), y          // byte 2: operand_byte_1 (stub)

    iny
    sta (zp_ptr_lo), y          // byte 3: operand_byte_2 (stub)

    iny
    sta (zp_ptr_lo), y          // byte 4: operand_length (stub)

    iny
    txa
    sta (zp_ptr_lo), y          // byte 5: address_offset

    // Advance metadata pointer by 6 bytes
    lda zp_ptr_lo
    clc
    adc #6
    sta zp_ptr_lo
    bcc !+
    inc zp_ptr_hi
!:

    // Increment instruction count
    inc zp_asm_inst_count
    rts

.assert "Codegen segment fits", * <= $3800, true
