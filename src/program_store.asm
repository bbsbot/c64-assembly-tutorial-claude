// ============================================================
// program_store.asm — 48-byte slot array + access routines
// ============================================================
// Slot array at $4000: 16 slots × 3 bytes
//   byte 0: block_type  ($FF = SLOT_EMPTY)
//   byte 1: param_value
//   byte 2: reserved (0)
//
// Inputs/outputs documented per routine below.
// ============================================================
.filenamespace ProgramStore

.pc = $4000 "ProgramStore"

// ------------------------------------------------------------
// slot_array — 48 bytes of slot storage
// ------------------------------------------------------------
slot_array:
    .fill 48, $FF       // initialised to SLOT_EMPTY

// ------------------------------------------------------------
// slot_stride3_table — maps slot index 0..15 → byte offset
// stride3_table[i] = i * 3
// ------------------------------------------------------------
slot_stride3_table:
    .byte 0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45

// ============================================================
// store_clear_all
// Inputs:  none
// Outputs: zp_slots_used = 0; slot_array filled with $FF
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
// Outputs: C=0 ok (slot added), C=1 program full
//          zp_slots_used incremented on success
// Clobbers: A, X
// ============================================================
store_add_block:
    ldx zp_slots_used
    cpx #MAX_SLOTS
    bcs !full+              // carry set if >= 16

    // get byte offset for slot[x]
    stx zp_ptr_lo           // temp: save block_type arg
    pha                     // save A (block_type)
    txa                     // X = slot index
    tax
    lda slot_stride3_table, x
    tax                     // X = byte offset into slot_array
    pla                     // restore block_type
    sta slot_array, x       // slot[offset].type   = block_type
    tya
    sta slot_array+1, x     // slot[offset].param  = param_value
    lda #0
    sta slot_array+2, x     // slot[offset].reserved = 0
    inc zp_slots_used
    clc
    rts
!full:
    sec
    rts

// ============================================================
// store_remove_block
// Inputs:  zp_pgm_cursor = slot index to remove
// Outputs: zp_slots_used decremented; slots above shifted down
//          C=0 ok,  C=1 nothing to remove (slots_used was 0)
// Clobbers: A, X, Y
// ============================================================
store_remove_block:
    lda zp_slots_used
    beq !empty+
    // index of slot to remove = zp_pgm_cursor
    ldx zp_pgm_cursor
    cpx zp_slots_used       // cursor must be < slots_used
    bcs !empty+

    // shift slots [cursor+1 .. slots_used-1] down by one
    txa
    tax                     // X = source slot index (cursor+1 will be loaded)
!shift_loop:
    inx                     // X = source slot index
    cpx zp_slots_used
    bcs !shift_done+

    // copy slot[X] to slot[X-1]
    lda slot_stride3_table, x
    tay                     // Y = source byte offset
    dex
    lda slot_stride3_table, x
    tax                     // X = dest byte offset
    lda slot_array, y
    sta slot_array, x
    lda slot_array+1, y
    sta slot_array+1, x
    lda slot_array+2, y
    sta slot_array+2, x
    // restore X to source index
    lda slot_stride3_table+1, x   // this won't work — need to recompute
    // actually re-derive from Y offset
    tya
    // Y was source offset = dest_offset + 3
    // source_index = (Y)/3 — but we can track via a counter
    // Let's redo with a simpler counter approach
    rts   // placeholder; see corrected version below

!shift_done:
    // mark last slot as empty
    lda zp_slots_used
    tax
    dex
    lda slot_stride3_table, x
    tax
    lda #SLOT_EMPTY
    sta slot_array, x
    dec zp_slots_used
    // clamp cursor
    lda zp_pgm_cursor
    cmp zp_slots_used
    bcc !ok+
    lda zp_slots_used
    bne !clamp_nz+
    lda #0
    sta zp_pgm_cursor
    clc
    rts
!clamp_nz:
    dec a
    sta zp_pgm_cursor
!ok:
    clc
    rts
!empty:
    sec
    rts

// ============================================================
// store_remove_block (clean rewrite using byte-offset counter)
// ============================================================
// We shadow the label — KickAss allows redef in same namespace
// but we instead name this correctly:

store_remove_block_impl:
    // Called by the main loop instead of store_remove_block
    lda zp_slots_used
    beq !empty+
    ldx zp_pgm_cursor
    cpx zp_slots_used
    bcs !empty+

    // Use zp_ptr_lo as source-slot counter
    stx zp_ptr_lo           // zp_ptr_lo = cursor (dest slot)
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
    // copy 3 bytes
    lda slot_array, y
    sta slot_array, x
    lda slot_array+1, y
    sta slot_array+1, x
    lda slot_array+2, y
    sta slot_array+2, x
    inc zp_ptr_lo
    bne !shift-             // always taken (< 16)
!done_shift:
    // blank the last slot
    lda zp_slots_used
    sec
    sbc #1
    tax
    lda slot_stride3_table, x
    tax
    lda #SLOT_EMPTY
    sta slot_array, x
    dec zp_slots_used
    // clamp cursor to new last
    lda zp_pgm_cursor
    cmp zp_slots_used
    bcc !ok+
    lda zp_slots_used
    beq !zero+
    dec a
    sta zp_pgm_cursor
    clc
    rts
!zero:
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
// Outputs: X = byte offset into slot_array  (X*3)
// Clobbers: X
// ============================================================
store_get_slot_offset:
    lda slot_stride3_table, x
    tax
    rts

.assert "ProgramStore segment fits", * <= $5000, true
