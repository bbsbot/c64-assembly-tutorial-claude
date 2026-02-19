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
// Outputs: zp_last_key = PETSCII char read (0 if none)
//          Z flag set if no key pressed
// Clobbers: A
// ============================================================
input_read_keyboard:
    jsr KERNAL_GETIN    // returns PETSCII in A; 0 if no key
    sta zp_last_key
    cmp #0              // sets Z if no key
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
