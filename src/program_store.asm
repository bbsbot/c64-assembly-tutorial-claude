// ============================================================
// program_store.asm — 48-byte slot array + access routines
// ============================================================
// Slot array at $4000: 16 slots × 3 bytes each
//   byte 0: block_type  ($FF = SLOT_EMPTY)
//   byte 1: param_value
//   byte 2: reserved (0)
// ============================================================
.filenamespace ProgramStore

.pc = $4000 "ProgramStore"

// ------------------------------------------------------------
// slot_array — 48 bytes of slot storage
// ------------------------------------------------------------
slot_array:
    .fill 48, $FF

// ------------------------------------------------------------
// slot_stride3_table[i] = i * 3  (i = 0..15)
// ------------------------------------------------------------
slot_stride3_table:
    .byte 0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45

// ============================================================
// store_clear_all
// Inputs:  none
// Outputs: slot_array filled with SLOT_EMPTY; zp_slots_used=0
// Clobbers: A, X
// ============================================================
store_clear_all:
    lda #SLOT_EMPTY
    ldx #47
!fill:
    sta slot_array, x
    dex
    bpl !fill-
    lda #0
    sta zp_slots_used
    rts

// ============================================================
// store_add_block
// Inputs:  A = block_type,  Y = param_value
// Outputs: C=0 ok (slot added); C=1 program full
//          zp_slots_used incremented on success
// Clobbers: A, X
// ============================================================
store_add_block:
    ldx zp_slots_used
    cpx #MAX_SLOTS
    bcs !full+

    pha                         // save block_type
    lda slot_stride3_table, x
    tax                         // X = byte offset
    pla                         // restore block_type
    sta slot_array, x           // .type   = block_type
    tya
    sta slot_array+1, x         // .param  = param_value
    lda #0
    sta slot_array+2, x         // .reserved = 0
    inc zp_slots_used
    clc
    rts
!full:
    sec
    rts

// ============================================================
// store_remove_block_impl
// Inputs:  zp_pgm_cursor = slot index to remove
// Outputs: slots above cursor shifted down; zp_slots_used--
//          C=0 ok, C=1 nothing to remove
// Clobbers: A, X, Y
// ============================================================
store_remove_block_impl:
    lda zp_slots_used
    beq !empty+
    ldx zp_pgm_cursor
    cpx zp_slots_used
    bcs !empty+

    // shift slots [cursor+1 .. slots_used-1] down by one
    stx zp_ptr_lo               // zp_ptr_lo = dest slot index
!shift:
    lda zp_ptr_lo
    clc
    adc #1
    cmp zp_slots_used
    bcs !done_shift+

    // copy slot[ptr_lo+1] → slot[ptr_lo]
    tax
    lda slot_stride3_table, x   // source offset
    tay
    dex
    lda slot_stride3_table, x   // dest offset
    tax
    lda slot_array, y
    sta slot_array, x
    lda slot_array+1, y
    sta slot_array+1, x
    lda slot_array+2, y
    sta slot_array+2, x
    inc zp_ptr_lo
    jmp !shift-

!done_shift:
    // blank the vacated last slot
    lda zp_slots_used
    sec
    sbc #1
    tax
    lda slot_stride3_table, x
    tax
    lda #SLOT_EMPTY
    sta slot_array, x
    dec zp_slots_used

    // clamp pgm_cursor to new valid range
    lda zp_slots_used
    beq !zero_slots+
    sec
    sbc #1                      // max valid index = slots_used - 1
    cmp zp_pgm_cursor
    bcs !ok+                    // cursor <= max: OK
    sta zp_pgm_cursor           // clamp to max
    jmp !ok+
!zero_slots:
    lda #0
    sta zp_pgm_cursor
!ok:
    clc
    rts
!empty:
    sec
    rts

// ============================================================
// store_get_slot_offset
// Inputs:  X = slot index (0..15)
// Outputs: X = byte offset into slot_array
// Clobbers: X
// ============================================================
store_get_slot_offset:
    lda slot_stride3_table, x
    tax
    rts

.assert "ProgramStore segment fits", * <= $5000, true
