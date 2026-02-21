// ============================================================
// main.asm — C64 Block Tutor  v2.0
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
//   $6000  assembly metadata buffer (80 instructions × 6 bytes)
//   $6800  asm_view.asm (assembly view rendering)
//   $7000  asm_strings.asm (mnemonic strings, hex conversion)
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
    lda #$FF
    sta zp_stop_flag        // signal LOOP BACK to exit on next iteration
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
    sta zp_stop_flag
    // Init ASM view ZP vars
    sta zp_asm_cursor
    sta zp_asm_pc_lo
    sta zp_asm_pc_hi
    sta zp_asm_inst_count
    sta zp_asm_reg_a
    sta zp_asm_reg_x
    sta zp_asm_reg_y
    lda #$FF
    sta zp_asm_reg_sp       // stack starts at $FF
    lda #0
    sta zp_asm_reg_flags
    sta zp_asm_prev_state

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

    // Dispatch on state (use jmp to avoid branch-too-far errors)
    lda zp_state
    cmp #STATE_PALETTE
    bne !not_pal+
    jmp state_palette
!not_pal:
    cmp #STATE_PROGRAM
    bne !not_pgm+
    jmp state_program
!not_pgm:
    cmp #STATE_EDIT_PARAM
    bne !not_edit+
    jmp state_edit_param
!not_edit:
    cmp #STATE_ASM_VIEW
    bne !not_asm+
    jmp state_asm_view
!not_asm:
    // STATE_RUNNING or STATE_ASM_STEPPING: executing — NMI will flip us back to STATE_PALETTE
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

    // Keyboard: T → ASSEMBLY VIEW (if instructions exist)
    lda zp_last_key
    cmp #$54                // T PETSCII = $54
    bne !no_t_pal+
    lda zp_asm_inst_count
    beq !no_t_pal+          // no instructions generated yet
    lda #STATE_PALETTE
    sta zp_asm_prev_state   // save current state
    lda #0
    sta zp_asm_cursor       // reset cursor to top
    lda #STATE_ASM_VIEW
    sta zp_state
    jsr AsmView.asm_view_render
    jmp main_loop
!no_t_pal:

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

    // T → ASSEMBLY VIEW (if instructions exist)
    lda zp_last_key
    cmp #$54                // T PETSCII = $54
    bne !no_t_pgm+
    lda zp_asm_inst_count
    beq !no_t_pgm+
    lda #STATE_PROGRAM
    sta zp_asm_prev_state
    lda #0
    sta zp_asm_cursor
    lda #STATE_ASM_VIEW
    sta zp_state
    jsr AsmView.asm_view_render
    jmp main_loop
!no_t_pgm:

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
    clc
    adc #1                  // param byte offset (stride3 + 1)
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

    // T → ASSEMBLY VIEW (if instructions exist)
    lda zp_last_key
    cmp #$54                // T PETSCII = $54
    bne !no_t_edit+
    lda zp_asm_inst_count
    beq !no_t_edit+
    lda #STATE_EDIT_PARAM
    sta zp_asm_prev_state
    lda #0
    sta zp_asm_cursor
    lda #STATE_ASM_VIEW
    sta zp_state
    jsr AsmView.asm_view_render
    jmp main_loop
!no_t_edit:

    jmp main_loop

// ============================================================
// STATE_ASM_VIEW handler
// ============================================================
state_asm_view:
    // UP → scroll up
    lda #JOY_UP
    jsr Input.input_joy_pressed
    beq !asm_not_up+
    lda zp_asm_cursor
    beq !asm_not_up+            // already at top
    dec zp_asm_cursor
    jsr AsmView.asm_view_render
!asm_not_up:

    // DOWN → scroll down
    lda #JOY_DOWN
    jsr Input.input_joy_pressed
    beq !asm_not_dn+
    lda zp_asm_cursor
    clc
    adc #17                     // cursor + visible lines
    cmp zp_asm_inst_count       // at end?
    bcs !asm_not_dn+            // can't scroll further
    inc zp_asm_cursor
    jsr AsmView.asm_view_render
!asm_not_dn:

    // T → return to previous state
    lda zp_last_key
    cmp #$54                    // T PETSCII = $54
    bne !no_t_asm+
    lda zp_asm_prev_state
    sta zp_state
    // Re-render the previous state's UI
    cmp #STATE_PALETTE
    bne !not_pal_ret+
    jsr UIRender.ui_clear_screen
    jsr UIRender.ui_render_frame
    jsr UIRender.ui_render_palette
    jsr UIRender.ui_render_program
    jsr UIRender.ui_render_value_bar
    lda #UIRender.STATUS_READY
    jsr UIRender.ui_render_status
    jmp main_loop
!not_pal_ret:
    cmp #STATE_PROGRAM
    bne !not_pgm_ret+
    jsr UIRender.ui_clear_screen
    jsr UIRender.ui_render_frame
    jsr UIRender.ui_render_palette
    jsr UIRender.ui_render_program
    jsr UIRender.ui_render_value_bar
    lda #UIRender.STATUS_READY
    jsr UIRender.ui_render_status
    jmp main_loop
!not_pgm_ret:
    cmp #STATE_EDIT_PARAM
    bne !no_t_asm+
    jsr UIRender.ui_clear_screen
    jsr UIRender.ui_render_frame
    jsr UIRender.ui_render_palette
    jsr UIRender.ui_render_program
    jsr UIRender.ui_render_value_bar
    lda #UIRender.STATUS_EDITING
    jsr UIRender.ui_render_status
!no_t_asm:

    // F1 → re-run program
    lda zp_last_key
    cmp #$85                    // F1 PETSCII = $85
    bne !no_f1_asm+
    jsr do_run
    // After run, return to assembly view
    lda #STATE_ASM_VIEW
    sta zp_state
    lda #0
    sta zp_asm_cursor           // reset to top
    jsr AsmView.asm_view_render
!no_f1_asm:

    jmp main_loop

// ============================================================
// do_run — compile and execute
// ============================================================
do_run:
    lda zp_slots_used
    beq !run_empty+
    lda #0
    sta zp_stop_flag                // clear stop flag before each run
    lda #STATE_RUNNING
    sta zp_state
    lda #UIRender.STATUS_RUNNING
    jsr UIRender.ui_render_status
    jsr Codegen.codegen_run         // compiles and calls JSR $5000
    // After return (from RTS in generated code), back to palette
    // Note: sprites are NOT disabled here — NMI (RESTORE) handles cleanup
    lda #STATE_PALETTE
    sta zp_state
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
#import "asm_strings.asm"
#import "asm_view.asm"
