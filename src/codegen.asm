// ============================================================
// codegen.asm — Walk slots, emit 6502 code to $5000, JSR $5000
// ============================================================
// Generated code buffer at GEN_CODE_BUF ($5000).
// Write pointer tracked in zp_cg_ptr_lo/zp_cg_ptr_hi.
//
// Emitter routines:
//   emit_byte  — write A to [ptr], advance ptr
//   emit_word  — write lo then hi of 16-bit value
//
// Block emitters (5 bytes each except SHOW_SPRITE/WAIT/LOOP):
//   SET BORDER  → A9 n  8D 20 D0
//   SET BG      → A9 n  8D 21 D0
//   PRINT       → A9 c  20 D2 FF
//   SHOW SPRITE → 15 bytes
//   WAIT        → 15 bytes  (n*768 outer loop @ ZP $FE/$FF)
//   LOOP BACK   → 4C 00 50  (JMP $5000)
// ============================================================
.filenamespace Codegen

.pc = $3000 "Codegen"

// ============================================================
// codegen_run
// Inputs:  slot_array, zp_slots_used
// Outputs: GEN_CODE_BUF contains valid 6502 code ending in RTS
//          (or LOOP BACK overwrites last byte with JMP)
// Clobbers: A, X, Y, zp_cg_ptr_lo/hi, zp_ptr_lo/hi
// ============================================================
codegen_run:
    // initialise write pointer to $5000
    lda #<GEN_CODE_BUF
    sta zp_cg_ptr_lo
    lda #>GEN_CODE_BUF
    sta zp_cg_ptr_hi

    // emit SEI at start so VIC/SID writes don't race
    lda #$78            // SEI opcode
    jsr emit_byte

    // walk slots 0..zp_slots_used-1
    ldx #0
!slot_loop:
    cpx zp_slots_used
    beq !done_slots+

    // load slot[x].type  (offset = stride3_table[x])
    lda ProgramStore.slot_stride3_table, x
    tay                 // Y = byte offset
    lda ProgramStore.slot_array, y  // A = block_type
    pha                 // save block type
    lda ProgramStore.slot_array+1, y // A = param
    tay                 // Y = param value
    pla                 // A = block_type
    stx zp_ptr_lo       // save X (slot counter)

    // dispatch to block emitter
    cmp #BLOCK_SET_BORDER
    beq !emit_set_border+
    cmp #BLOCK_SET_BG
    beq !emit_set_bg+
    cmp #BLOCK_PRINT
    beq !emit_print+
    cmp #BLOCK_SHOW_SPRITE
    beq !emit_show_sprite+
    cmp #BLOCK_WAIT
    beq !emit_wait+
    cmp #BLOCK_LOOP_BACK
    beq !emit_loop_back+
    jmp !next_slot+     // unknown block type — skip

!emit_set_border:
    // LDA #n  STA $D020
    lda #$A9 : jsr emit_byte    // LDA imm
    tya      : jsr emit_byte    // #n (colour)
    lda #$8D : jsr emit_byte    // STA abs
    lda #$20 : jsr emit_byte    // lo $D020
    lda #$D0 : jsr emit_byte    // hi
    jmp !next_slot+

!emit_set_bg:
    // LDA #n  STA $D021
    lda #$A9 : jsr emit_byte
    tya      : jsr emit_byte
    lda #$8D : jsr emit_byte
    lda #$21 : jsr emit_byte    // lo $D021
    lda #$D0 : jsr emit_byte
    jmp !next_slot+

!emit_print:
    // LDA #c  JSR $FFD2
    lda #$A9 : jsr emit_byte
    tya      : jsr emit_byte    // Y = PETSCII char
    lda #$20 : jsr emit_byte    // JSR opcode
    lda #$D2 : jsr emit_byte    // lo $FFD2
    lda #$FF : jsr emit_byte    // hi
    jmp !next_slot+

!emit_show_sprite:
    // Enable sprite 0 at X=150, Y=130, colour=white (1)
    // LDA #1   : STA $D015     (enable sprite 0)
    lda #$A9 : jsr emit_byte : lda #$01 : jsr emit_byte
    lda #$8D : jsr emit_byte : lda #$15 : jsr emit_byte : lda #$D0 : jsr emit_byte
    // LDA #150 : STA $D000     (sprite 0 X)
    lda #$A9 : jsr emit_byte : lda #150 : jsr emit_byte
    lda #$8D : jsr emit_byte : lda #$00 : jsr emit_byte : lda #$D0 : jsr emit_byte
    // LDA #130 : STA $D001     (sprite 0 Y)
    lda #$A9 : jsr emit_byte : lda #130 : jsr emit_byte
    lda #$8D : jsr emit_byte : lda #$01 : jsr emit_byte : lda #$D0 : jsr emit_byte
    jmp !next_slot+

!emit_wait:
    // WAIT n seconds (PAL ~985248 Hz)
    // Strategy: outer loop n*768 passes of a 5-cycle inner loop (256 DEX)
    // Emit:
    //   LDA #<(n*768) : STA $FE
    //   LDA #>(n*768) : STA $FF
    // outer:
    //   LDX #$FF
    // inner:
    //   DEX : BNE inner   (3+2 = 5 cycles per iter, 256 iters = ~1280 cyc)
    //   DEC $FE : BNE outer (but we need 16-bit dec)
    // Simpler: use a 3-level loop emitted inline

    // Y = seconds (1..9); compute n*768
    // 768 = $300; n*768: lo = lo(n*$300) = 0 (always), hi = n*3
    // So outer count hi = Y*3, lo = 0
    tya                     // A = seconds count
    asl a                   // A = n*2
    clc
    adc zp_ptr_lo+1-zp_ptr_lo  // cheat: re-read Y since we moved it
    // Actually just recompute: secs is in Y still? No, Y was set earlier.
    // We'll compute n*3 from Y saved before the jsr
    // At this point A was block_type dispatched, Y = param (seconds)
    // But we used TYA already — Y still intact
    tya                     // A = n (1..9)
    sta zp_gen_lo           // temp save n
    asl a                   // A = n*2
    clc
    adc zp_gen_lo           // A = n*3
    sta zp_gen_hi           // outer_hi = n*3

    // Emit: LDA #0 : STA $FE   (outer lo = 0)
    lda #$A9 : jsr emit_byte : lda #$00 : jsr emit_byte
    lda #$85 : jsr emit_byte : lda #$FE : jsr emit_byte
    // Emit: LDA #hi : STA $FF  (outer hi = n*3)
    lda #$A9 : jsr emit_byte
    lda zp_gen_hi : jsr emit_byte
    lda #$85 : jsr emit_byte : lda #$FF : jsr emit_byte
    // Emit outer label (no label in generated code; just inline)
    // outer: LDX #$FF
    lda #$A2 : jsr emit_byte : lda #$FF : jsr emit_byte
    // inner: DEX : BNE inner  (BNE -2)
    lda #$CA : jsr emit_byte  // DEX
    lda #$D0 : jsr emit_byte  // BNE
    lda #$FD : jsr emit_byte  // -3 (back to DEX)
    // 16-bit decrement $FE/$FF, loop if not zero
    // DEC $FE : BNE outer(back 13) : DEC $FF : BNE outer(back 16)
    lda #$C6 : jsr emit_byte : lda #$FE : jsr emit_byte   // DEC $FE
    lda #$D0 : jsr emit_byte : lda #$F2 : jsr emit_byte   // BNE outer (-14)
    lda #$C6 : jsr emit_byte : lda #$FF : jsr emit_byte   // DEC $FF
    lda #$D0 : jsr emit_byte : lda #$EF : jsr emit_byte   // BNE outer (-17)
    jmp !next_slot+

!emit_loop_back:
    // JMP $5000
    lda #$4C : jsr emit_byte
    lda #$00 : jsr emit_byte   // lo $5000
    lda #$50 : jsr emit_byte   // hi
    jmp !next_slot+

!next_slot:
    ldx zp_ptr_lo       // restore slot counter
    inx
    jmp !slot_loop-

!done_slots:
    // Emit CLI + RTS to end the generated program
    lda #$58 : jsr emit_byte   // CLI
    lda #$60 : jsr emit_byte   // RTS

    // Execute the generated program
    jsr GEN_CODE_BUF
    rts

// ============================================================
// emit_byte
// Inputs:  A = byte to emit
// Outputs: byte written at [zp_cg_ptr], pointer advanced
// Clobbers: (preserves A via stack)
// ============================================================
emit_byte:
    pha
    ldy #0
    sta (zp_cg_ptr_lo), y
    // advance pointer
    inc zp_cg_ptr_lo
    bne !+
    inc zp_cg_ptr_hi
!:
    pla
    rts

.assert "Codegen segment fits", * <= $3800, true
