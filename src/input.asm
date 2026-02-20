// ============================================================
// input.asm — Joystick edge detection + keyboard read
// ============================================================
// Joystick 2 on CIA1 $DC00, bits 0-4, active-LOW.
// We invert so pressed=1.  Edge detect gives only NEW presses.
//
// Bit constants (after inversion):
//   JOY_UP=$01  JOY_DOWN=$02  JOY_LEFT=$04  JOY_RIGHT=$08  JOY_FIRE=$10
// ============================================================
.filenamespace Input

.pc = $1800 "Input"

// ============================================================
// input_read_joystick
// Inputs:  none
// Outputs: zp_joy_edge = bits newly pressed this frame
//          zp_joy_curr = current pressed state
// Clobbers: A
// ============================================================
input_read_joystick:
    lda CIA1_PORTA      // read joystick port 2 (bits 0-4)
    and #$1F            // mask to 5 joystick bits
    eor #$1F            // invert: active-low → active-high (1=pressed)
    sta zp_joy_curr

    // edge detect: new presses = curr AND (NOT prev)
    lda zp_joy_prev
    eor #$1F            // invert prev to get "was not pressed"
    and zp_joy_curr     // AND with current: only bits new this frame
    sta zp_joy_edge

    // save current as previous for next frame
    lda zp_joy_curr
    sta zp_joy_prev
    rts

// ============================================================
// input_read_keyboard
// Inputs:  none
// Outputs: zp_last_key = PETSCII char (0 if none or nav key)
//          zp_joy_edge |= joystick bit if cursor/space pressed
//          Z flag set if no key pressed
// Clobbers: A
//
// Cursor keys and SPACE are translated to joystick edge bits
// so the state machine needs no changes for keyboard support.
//   CRSR UP=$91  CRSR DOWN=$11  CRSR LEFT=$9D  CRSR RIGHT=$1D
//   SPACE=$20 → JOY_FIRE
// ============================================================
input_read_keyboard:
    jsr KERNAL_GETIN        // A = PETSCII or 0 if no key
    beq !done+              // nothing pressed

    // --- translate cursor/space → joystick edge bits ---
    cmp #$91                // CRSR UP
    bne !k1+
    lda #JOY_UP
    jmp !inject+
!k1:
    cmp #$11                // CRSR DOWN
    bne !k2+
    lda #JOY_DOWN
    jmp !inject+
!k2:
    cmp #$9D                // CRSR LEFT
    bne !k3+
    lda #JOY_LEFT
    jmp !inject+
!k3:
    cmp #$1D                // CRSR RIGHT
    bne !k4+
    lda #JOY_RIGHT
    jmp !inject+
!k4:
    cmp #$20                // SPACE → FIRE
    bne !not_nav+
    lda #JOY_FIRE
!inject:
    ora zp_joy_edge         // merge into existing edge bits
    sta zp_joy_edge
    lda #0
    sta zp_last_key         // don't expose nav keys as zp_last_key
    rts

!not_nav:                   // regular key: F1, F3, DEL, etc.
    sta zp_last_key
    rts

!done:
    lda #0
    sta zp_last_key
    rts

// ============================================================
// input_joy_pressed
// Inputs:  A = bit mask to test (e.g. JOY_UP)
// Outputs: Z=0 (not zero) if the bit is set in zp_joy_edge
//          Z=1 if not pressed this frame
// Usage:   lda #JOY_UP : jsr input_joy_pressed : bne do_up
// Clobbers: A
// ============================================================
input_joy_pressed:
    and zp_joy_edge
    rts

// ============================================================
// input_joy_held
// Inputs:  A = bit mask to test
// Outputs: Z=0 if currently held, Z=1 if not
// Clobbers: A
// ============================================================
input_joy_held:
    and zp_joy_curr
    rts

.assert "Input segment fits", * <= $2000, true
