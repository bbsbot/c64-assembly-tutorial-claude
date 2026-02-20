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
    lda #<GEN_CODE_BUF
    sta zp_cg_ptr_lo
    lda #>GEN_CODE_BUF
    sta zp_cg_ptr_hi

    // Emit SEI at start of generated program
    lda #$78
    jsr emit_byte

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
    lda #$60
    jsr emit_byte           // RTS
    // Execute generated program
    jsr GEN_CODE_BUF
    rts

// ============================================================
// Emitters — each ends with jmp next_slot
// On entry: Y = param_value, zp_ptr_lo = saved slot index
// ============================================================

// SET BORDER: LDA #n / STA $D020
emit_border:
    lda #$A9
    jsr emit_byte
    tya
    jsr emit_byte
    lda #$8D
    jsr emit_byte
    lda #$20
    jsr emit_byte
    lda #$D0
    jsr emit_byte
    jmp next_slot

// SET BG: LDA #n / STA $D021
emit_bg:
    lda #$A9
    jsr emit_byte
    tya
    jsr emit_byte
    lda #$8D
    jsr emit_byte
    lda #$21
    jsr emit_byte
    lda #$D0
    jsr emit_byte
    jmp next_slot

// PRINT: LDA #c / JSR $FFD2
emit_print:
    lda #$A9
    jsr emit_byte
    tya
    jsr emit_byte
    lda #$20
    jsr emit_byte
    lda #$D2
    jsr emit_byte
    lda #$FF
    jsr emit_byte
    jmp next_slot

// SHOW SPRITE: enable spr0 at X=150, Y=130
emit_sprite:
    // LDA #1 / STA $D015
    lda #$A9
    jsr emit_byte
    lda #$01
    jsr emit_byte
    lda #$8D
    jsr emit_byte
    lda #$15
    jsr emit_byte
    lda #$D0
    jsr emit_byte
    // LDA #150 / STA $D000
    lda #$A9
    jsr emit_byte
    lda #150
    jsr emit_byte
    lda #$8D
    jsr emit_byte
    lda #$00
    jsr emit_byte
    lda #$D0
    jsr emit_byte
    // LDA #130 / STA $D001
    lda #$A9
    jsr emit_byte
    lda #130
    jsr emit_byte
    lda #$8D
    jsr emit_byte
    lda #$01
    jsr emit_byte
    lda #$D0
    jsr emit_byte
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

    lda #$A9
    jsr emit_byte
    lda #$00
    jsr emit_byte           // LDA #0
    lda #$85
    jsr emit_byte
    lda #$FE
    jsr emit_byte           // STA $FE
    lda #$A9
    jsr emit_byte
    lda zp_gen_hi
    jsr emit_byte           // LDA #hi
    lda #$85
    jsr emit_byte
    lda #$FF
    jsr emit_byte           // STA $FF
    lda #$A2
    jsr emit_byte
    lda #$FF
    jsr emit_byte           // LDX #$FF  ← outer label (+0 from here)
    lda #$CA
    jsr emit_byte           // DEX       (+2)
    lda #$D0
    jsr emit_byte
    lda #$FD
    jsr emit_byte           // BNE -3    (+3, loops back to DEX)
    lda #$C6
    jsr emit_byte
    lda #$FE
    jsr emit_byte           // DEC $FE   (+5)
    lda #$D0
    jsr emit_byte
    lda #$F7
    jsr emit_byte           // BNE -9    (+7, loops back to LDX #$FF)
    lda #$C6
    jsr emit_byte
    lda #$FF
    jsr emit_byte           // DEC $FF   (+9)
    lda #$D0
    jsr emit_byte
    lda #$F3
    jsr emit_byte           // BNE -13   (+11, loops back to LDX #$FF)
    jmp next_slot

// LOOP BACK: check stop flag; if clear, JMP $5000; else fall through to CLI/RTS
// Generated bytes (7):
//   A5 11       LDA zp_stop_flag   ; load stop flag ($11)
//   D0 03       BNE +3             ; if set, skip JMP (fall through to CLI/RTS)
//   4C 00 50    JMP $5000          ; loop back to start of generated code
emit_loop_back:
    lda #$A5                // LDA zp (zero page)
    jsr emit_byte
    lda #zp_stop_flag       // ZP address of stop flag ($11)
    jsr emit_byte
    lda #$D0                // BNE
    jsr emit_byte
    lda #$03                // +3 (skip the JMP)
    jsr emit_byte
    lda #$4C                // JMP abs
    jsr emit_byte
    lda #<GEN_CODE_BUF
    jsr emit_byte
    lda #>GEN_CODE_BUF
    jsr emit_byte
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

.assert "Codegen segment fits", * <= $3800, true
