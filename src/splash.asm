// ============================================================
// splash.asm — Text-mode credit screen with SID music
// ============================================================
// Displays centered credit text, plays Swamp Sollies SID,
// waits for FIRE/SPACE or timeout, then restores and returns.
// Inputs:  SID data loaded at $9000-$CFFF
// Outputs: Screen cleared, SID silenced, text mode restored
// Clobbers: A, X, Y
// ============================================================

.filenamespace Splash

.pc = $7400 "Splash"

// ============================================================
// splash_show
// Main entry: display credits, play SID, wait, clean up.
// ============================================================
splash_show:
    sei

    // Disable loading_irq — restore default Kernal IRQ handler
    lda #<$EA31
    sta $0314
    lda #>$EA31
    sta $0315

    // ── 1. Clear screen + set colors ────────────────────────────
    lda #$20                    // space character
    ldx #0
!clr_screen:
    sta SCREEN_RAM, x
    sta SCREEN_RAM + 256, x
    sta SCREEN_RAM + 512, x
    sta SCREEN_RAM + 768, x
    inx
    bne !clr_screen-

    // Set all color RAM to light blue
    lda #COL_LT_BLUE
    ldx #0
!clr_color:
    sta COLOR_RAM, x
    sta COLOR_RAM + 256, x
    sta COLOR_RAM + 512, x
    sta COLOR_RAM + 768, x
    inx
    bne !clr_color-

    // Border + background black
    lda #COL_BLACK
    sta VIC_BORDER
    sta VIC_BG0

    // ── 2. Print centered credit lines ──────────────────────────
    // Row 8: "C64 BLOCK TUTOR" (15 chars, col 12)
    ldx #0
!print_title:
    lda txt_title, x
    beq !done_title+
    sta SCREEN_RAM + (8 * 40) + 12, x
    inx
    bne !print_title-
!done_title:
    // Color the title line cyan
    lda #COL_CYAN
    ldx #14
!col_title:
    sta COLOR_RAM + (8 * 40) + 12, x
    dex
    bpl !col_title-

    // Row 11: "MUSIC: SWAMP SOLLIES" (20 chars, col 10)
    ldx #0
!print_music:
    lda txt_music, x
    beq !done_music+
    sta SCREEN_RAM + (11 * 40) + 10, x
    inx
    bne !print_music-
!done_music:

    // Row 12: "BY CHRISTOF MUHLAN (BANANA)" (27 chars, col 6)
    ldx #0
!print_author:
    lda txt_author, x
    beq !done_author+
    sta SCREEN_RAM + (12 * 40) + 6, x
    inx
    bne !print_author-
!done_author:

    // Row 13: "1987 THE ELECTRONIC KNIGHTS" (27 chars, col 6)
    ldx #0
!print_group:
    lda txt_group, x
    beq !done_group+
    sta SCREEN_RAM + (13 * 40) + 6, x
    inx
    bne !print_group-
!done_group:

    // Color rows 11-13 in light grey
    lda #COL_LT_GREY
    ldx #39
!col_credits:
    sta COLOR_RAM + (11 * 40), x
    sta COLOR_RAM + (12 * 40), x
    sta COLOR_RAM + (13 * 40), x
    dex
    bpl !col_credits-

    // Row 16: "PRESS FIRE OR SPACE" (19 chars, col 10)
    ldx #0
!print_prompt:
    lda txt_prompt, x
    beq !done_prompt+
    sta SCREEN_RAM + (16 * 40) + 10, x
    inx
    bne !print_prompt-
!done_prompt:
    // Color the prompt yellow
    lda #COL_YELLOW
    ldx #18
!col_prompt:
    sta COLOR_RAM + (16 * 40) + 10, x
    dex
    bpl !col_prompt-

    // ── 3. Init SID ─────────────────────────────────────────────
    lda #0
    jsr SID_INIT

    // Flush keyboard buffer (VICE autostart leaves RUN in buffer)
    lda #0
    sta $C6                     // keyboard buffer count = 0

    cli

    // ── 4. Frame loop: play SID, check input, timeout ───────────
    ldx #SPLASH_FRAMES          // frame countdown
!frame_loop:
    // Wait for raster to leave line 250
!wait_leave:
    lda $D012
    cmp #250
    beq !wait_leave-
    // Wait for raster to arrive at line 250
!wait_arrive:
    lda $D012
    cmp #250
    bne !wait_arrive-

    // Play one frame of SID
    txa
    pha
    jsr SID_PLAY
    pla
    tax

    // Check joystick FIRE (bit 4 of CIA1 port A, active-low)
    lda CIA1_PORTA
    and #%00010000
    beq !exit_splash+           // fire pressed

    // Check SPACE via GETIN
    txa
    pha
    jsr KERNAL_GETIN
    cmp #$20                    // space bar
    beq !exit_pop+
    pla
    tax

    dex
    bne !frame_loop-
    jmp !silence+

!exit_pop:
    pla                         // discard saved X
!exit_splash:

    // ── 5. Silence SID ──────────────────────────────────────────
!silence:
    ldx #$18                    // $D400-$D418 = 25 registers
    lda #0
!sil_loop:
    sta $D400, x
    dex
    bpl !sil_loop-

    // ── 6. Clear screen for main app ────────────────────────────
    lda #$20
    ldx #0
!clr2:
    sta SCREEN_RAM, x
    sta SCREEN_RAM + 256, x
    sta SCREEN_RAM + 512, x
    sta SCREEN_RAM + 768, x
    inx
    bne !clr2-

    lda #COL_LT_BLUE
    ldx #0
!clr2c:
    sta COLOR_RAM, x
    sta COLOR_RAM + 256, x
    sta COLOR_RAM + 512, x
    sta COLOR_RAM + 768, x
    inx
    bne !clr2c-

    rts

// ============================================================
// Text data (screen codes, 0-terminated)
// Screen code: A=$01, B=$02, ... Z=$1A, 0-9=$30-$39, space=$20
// ============================================================
txt_title:
    // "C64 BLOCK TUTOR"
    .byte $03, $36, $34, $20   // C64_
    .byte $02, $0C, $0F, $03, $0B  // BLOCK
    .byte $20                  // _
    .byte $14, $15, $14, $0F, $12  // TUTOR
    .byte 0

txt_music:
    // "MUSIC: SWAMP SOLLIES"
    .byte $0D, $15, $13, $09, $03  // MUSIC
    .byte $3A, $20             // :_
    .byte $13, $17, $01, $0D, $10  // SWAMP
    .byte $20                  // _
    .byte $13, $0F, $0C, $0C, $09, $05, $13  // SOLLIES
    .byte 0

txt_author:
    // "BY CHRISTOF MUHLAN (BANANA)"
    .byte $02, $19, $20        // BY_
    .byte $03, $08, $12, $09, $13, $14, $0F, $06  // CHRISTOF
    .byte $20                  // _
    .byte $0D, $15, $08, $0C, $01, $0E  // MUHLAN
    .byte $20, $28             // _(
    .byte $02, $01, $0E, $01, $0E, $01  // BANANA
    .byte $29                  // )
    .byte 0

txt_group:
    // "1987 THE ELECTRONIC KNIGHTS"
    .byte $31, $39, $38, $37, $20  // 1987_
    .byte $14, $08, $05, $20  // THE_
    .byte $05, $0C, $05, $03, $14, $12, $0F, $0E, $09, $03  // ELECTRONIC
    .byte $20                  // _
    .byte $0B, $0E, $09, $07, $08, $14, $13  // KNIGHTS
    .byte 0

txt_prompt:
    // "PRESS FIRE OR SPACE"
    .byte $10, $12, $05, $13, $13  // PRESS
    .byte $20                  // _
    .byte $06, $09, $12, $05  // FIRE
    .byte $20                  // _
    .byte $0F, $12             // OR
    .byte $20                  // _
    .byte $13, $10, $01, $03, $05  // SPACE
    .byte 0

.assert "Splash routine fits before $7800", * <= $7800, true
