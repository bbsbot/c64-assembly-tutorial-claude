// ============================================================
// main.asm — C64 Block Tutor  v1.0
// ============================================================
// Memory map:
//   $0801  BASIC Upstart stub
//   $0810  init + main loop + state machine  (this file)
//   $1000  ui_render.asm
//   $1800  input.asm
//   $2000  sprite_data.asm  (64-byte aligned; ptr = 128)
//   $2800  blocks_data.asm
//   $3000  codegen.asm
//   $3800  strings.asm
//   $4000  program_store.asm (slot array + routines)
//   $5000  runtime generated code buffer
// ============================================================

#import "constants.asm"

.filenamespace Main

:BasicUpstart2(start)

.pc = $0810 "Main"

// ============================================================
// NMI handler — installed at $0318/$0319
// Invoked by RESTORE key.  Stops running programs, returns to
// STATE_PALETTE, disables sprites.
// ============================================================
nmi_handler:
    pha
    lda #STATE_PALETTE
    sta zp_state
    lda #0
    sta VIC_SPR_ENA         // disable all sprites
    lda #UIRender.STATUS_READY
    jsr UIRender.ui_render_status
    pla
    rti

// ============================================================
// start — init sequence
// ============================================================
start:
    sei                     // disable IRQ during init

    // 1. Clear screen and color RAM
    jsr UIRender.ui_clear_screen

    // 2. Set border/bg black
    lda #COL_BLACK
    sta VIC_BORDER
    sta VIC_BG0

    // 3. Sprite 0 pointer → $2000 (pointer value = $2000/64 = 128)
    lda #128
    sta SPRITE0_PTR

    // 4. Disable all sprites
    lda #0
    sta VIC_SPR_ENA

    // 5. Install NMI handler at $0318/$0319
    lda #<nmi_handler
    sta $0318
    lda #>nmi_handler
    sta $0319

    // 6. Init slot array
    jsr ProgramStore.store_clear_all

    // 7. Init ZP vars
    lda #STATE_PALETTE
    sta zp_state
    lda #0
    sta zp_pal_cursor
    sta zp_pgm_cursor
    sta zp_joy_prev
    sta zp_joy_curr
    sta zp_joy_edge
    sta zp_edit_val
    sta zp_edit_slot
    sta zp_frame
    sta zp_last_key

    // 8. Draw static chrome
    jsr UIRender.ui_render_frame

    // 9. Draw initial palette list
    jsr UIRender.ui_render_palette

    // 10. Draw initial (empty) program panel
    jsr UIRender.ui_render_program

    // 11. Initial value bar (slot 0, block 0 default)
    lda #0
    sta zp_edit_slot
    lda BlocksData.block_param_default
    sta zp_edit_val
    jsr UIRender.ui_render_value_bar

    // 12. Status: READY
    lda #UIRender.STATUS_READY
    jsr UIRender.ui_render_status

    cli                     // re-enable IRQ

    jmp main_loop

// ============================================================
// main_loop — runs every raster frame
// ============================================================
main_loop:
    // Wait for raster line 250 to sync to frame rate
    // (simple approach: wait for raster top of screen)
!wait_raster:
    lda $D012
    cmp #250
    bne !wait_raster-

    inc zp_frame

    // Read input
    jsr Input.input_read_joystick
    jsr Input.input_read_keyboard

    // Dispatch on state
    lda zp_state
    cmp #STATE_PALETTE
    beq state_palette
    cmp #STATE_PROGRAM
    beq state_program
    cmp #STATE_EDIT_PARAM
    beq state_edit_param
    // STATE_RUNNING: program is executing via JSR $5000 from codegen;
    // we never reach here during run — NMI returns us to STATE_PALETTE
    jmp main_loop

// ============================================================
// STATE_PALETTE handler
// ============================================================
state_palette:
    // UP → move cursor up
    lda #JOY_UP
    jsr Input.input_joy_pressed
    beq !pal_not_up+
    lda zp_pal_cursor
    beq !pal_not_up+         // already at top
    dec zp_pal_cursor
    jsr UIRender.ui_render_palette
!pal_not_up:

    // DOWN → move cursor down
    lda #JOY_DOWN
    jsr Input.input_joy_pressed
    beq !pal_not_dn+
    lda zp_pal_cursor
    cmp #NUM_BLOCKS-1
    beq !pal_not_dn+
    inc zp_pal_cursor
    jsr UIRender.ui_render_palette
!pal_not_dn:

    // RIGHT → switch to program panel
    lda #JOY_RIGHT
    jsr Input.input_joy_pressed
    beq !pal_not_right+
    lda #STATE_PROGRAM
    sta zp_state
    jsr UIRender.ui_render_palette   // re-draw (removes palette cursor)
    jsr UIRender.ui_render_program
    jmp main_loop
!pal_not_right:

    // FIRE → add selected block to program
    lda #JOY_FIRE
    jsr Input.input_joy_pressed
    beq !pal_not_fire+
    // get block id and default param
    ldx zp_pal_cursor
    lda BlocksData.block_param_default, x
    tay                     // Y = param
    txa                     // A = block type
    jsr ProgramStore.store_add_block
    bcs !prog_full+
    // success
    jsr UIRender.ui_render_program
    lda #UIRender.STATUS_ADDED
    jsr UIRender.ui_render_status
    jmp !pal_not_fire+
!prog_full:
    lda #UIRender.STATUS_FULL
    jsr UIRender.ui_render_status
!pal_not_fire:

    // Keyboard: F1 → RUN
    lda zp_last_key
    cmp #$85                // F1 PETSCII = $85
    bne !no_f1_pal+
    jsr do_run
!no_f1_pal:

    // Keyboard: F3 → CLEAR
    lda zp_last_key
    cmp #$86                // F3 PETSCII = $86
    bne !no_f3+
    jsr ProgramStore.store_clear_all
    jsr UIRender.ui_render_program
    lda #UIRender.STATUS_CLEARED
    jsr UIRender.ui_render_status
!no_f3:

    jmp main_loop

// ============================================================
// STATE_PROGRAM handler
// ============================================================
state_program:
    // UP
    lda #JOY_UP
    jsr Input.input_joy_pressed
    beq !pgm_not_up+
    lda zp_pgm_cursor
    beq !pgm_not_up+
    dec zp_pgm_cursor
    jsr UIRender.ui_render_program
!pgm_not_up:

    // DOWN
    lda #JOY_DOWN
    jsr Input.input_joy_pressed
    beq !pgm_not_dn+
    lda zp_pgm_cursor
    cmp zp_slots_used
    beq !pgm_not_dn+
    cmp #MAX_SLOTS-1
    beq !pgm_not_dn+
    inc zp_pgm_cursor
    jsr UIRender.ui_render_program
!pgm_not_dn:

    // LEFT → back to palette
    lda #JOY_LEFT
    jsr Input.input_joy_pressed
    beq !pgm_not_left+
    lda #STATE_PALETTE
    sta zp_state
    jsr UIRender.ui_render_palette
    jsr UIRender.ui_render_program
    jmp main_loop
!pgm_not_left:

    // FIRE → enter edit param (if slot is filled)
    lda #JOY_FIRE
    jsr Input.input_joy_pressed
    beq !pgm_not_fire+
    ldx zp_pgm_cursor
    cpx zp_slots_used
    bcs !pgm_not_fire+      // cursor past filled slots
    // load current param into zp_edit_val
    stx zp_edit_slot
    lda ProgramStore.slot_stride3_table, x
    tay
    lda ProgramStore.slot_array+1, y
    sta zp_edit_val
    lda #STATE_EDIT_PARAM
    sta zp_state
    jsr UIRender.ui_render_value_bar
    lda #UIRender.STATUS_EDITING
    jsr UIRender.ui_render_status
!pgm_not_fire:

    // DEL key → remove block
    lda zp_last_key
    cmp #$14                // DEL PETSCII = $14
    bne !no_del+
    jsr ProgramStore.store_remove_block_impl
    jsr UIRender.ui_render_program
    lda #UIRender.STATUS_REMOVED
    jsr UIRender.ui_render_status
!no_del:

    // F1 → RUN
    lda zp_last_key
    cmp #$85
    bne !no_f1_pgm+
    jsr do_run
!no_f1_pgm:

    // F3 → CLEAR
    lda zp_last_key
    cmp #$86
    bne !no_f3_pgm+
    jsr ProgramStore.store_clear_all
    jsr UIRender.ui_render_program
    lda #UIRender.STATUS_CLEARED
    jsr UIRender.ui_render_status
!no_f3_pgm:

    jmp main_loop

// ============================================================
// STATE_EDIT_PARAM handler
// ============================================================
state_edit_param:
    // Get param bounds for current slot's block type
    ldx zp_edit_slot
    lda ProgramStore.slot_stride3_table, x
    tay
    lda ProgramStore.slot_array, y      // block type
    tax
    lda BlocksData.block_param_type, x
    cmp #PARAM_NONE
    beq !edit_confirm+                   // no param to edit — fire confirms

    // LEFT → decrement param (wrap at min)
    lda #JOY_LEFT
    jsr Input.input_joy_pressed
    beq !edit_not_left+
    lda zp_edit_val
    ldx zp_edit_slot
    lda ProgramStore.slot_stride3_table, x
    tay
    lda ProgramStore.slot_array, y
    tax
    lda BlocksData.block_param_min, x
    cmp zp_edit_val
    beq !edit_not_left+                 // already at min
    dec zp_edit_val
    jsr UIRender.ui_render_value_bar
!edit_not_left:

    // RIGHT → increment param (stop at max)
    lda #JOY_RIGHT
    jsr Input.input_joy_pressed
    beq !edit_not_right+
    ldx zp_edit_slot
    lda ProgramStore.slot_stride3_table, x
    tay
    lda ProgramStore.slot_array, y
    tax
    lda BlocksData.block_param_max, x
    cmp zp_edit_val
    beq !edit_not_right+                // already at max
    inc zp_edit_val
    jsr UIRender.ui_render_value_bar
!edit_not_right:

    // FIRE → confirm, write back to slot
!edit_confirm:
    lda #JOY_FIRE
    jsr Input.input_joy_pressed
    beq !edit_not_fire+
    // write zp_edit_val back to slot param byte
    ldx zp_edit_slot
    lda ProgramStore.slot_stride3_table, x
    clc : adc #1            // param byte offset
    tax
    lda zp_edit_val
    sta ProgramStore.slot_array, x
    // return to program state
    lda #STATE_PROGRAM
    sta zp_state
    jsr UIRender.ui_render_program
    lda #UIRender.STATUS_READY
    jsr UIRender.ui_render_status
!edit_not_fire:

    jmp main_loop

// ============================================================
// do_run — compile and execute
// ============================================================
do_run:
    lda zp_slots_used
    beq !run_empty+
    lda #STATE_RUNNING
    sta zp_state
    lda #UIRender.STATUS_RUNNING
    jsr UIRender.ui_render_status
    jsr Codegen.codegen_run         // compiles and calls JSR $5000
    // After return (from RTS in generated code), back to palette
    lda #STATE_PALETTE
    sta zp_state
    lda #0
    sta VIC_SPR_ENA
    lda #UIRender.STATUS_READY
    jsr UIRender.ui_render_status
!run_empty:
    rts

// ============================================================
// #import all modules
// ============================================================
#import "ui_render.asm"
#import "input.asm"
#import "sprite_data.asm"
#import "blocks_data.asm"
#import "codegen.asm"
#import "strings.asm"
#import "program_store.asm"
