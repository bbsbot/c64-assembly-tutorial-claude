// ============================================================
// splash.asm — Multicolor bitmap splash screen display routine
// ============================================================
// Inputs:  Splash data loaded at $8000, $8C00, $A000
// Outputs: Displays splash for ~3 sec, then restores text mode
// Clobbers: A, X, Y
// ============================================================

.filenamespace Splash

.pc = $7400 "Splash"

// ============================================================
// splash_show
// Main entry: show splash bitmap, wait, restore text mode.
// ============================================================
splash_show:
    sei

    // ── 1. Wait for vblank ────────────────────────────────────
!wait_vblank:
    lda $D012
    cmp #$FB
    bne !wait_vblank-

    // ── 2. Copy 1000 bytes: $8000 → $D800 (Color RAM) ────────
    // 4 pages of 256 = 1024, but we only need 1000 = 3*256 + 232
    ldx #0
!copy0:
    lda SplashData.color_data, x
    sta COLOR_RAM, x
    lda SplashData.color_data + 256, x
    sta COLOR_RAM + 256, x
    lda SplashData.color_data + 512, x
    sta COLOR_RAM + 512, x
    inx
    bne !copy0-
    // Remaining 232 bytes (768..999)
    ldx #0
!copy_tail:
    lda SplashData.color_data + 768, x
    sta COLOR_RAM + 768, x
    inx
    cpx #232
    bne !copy_tail-

    // ── 3. Switch VIC to Bank 2, bitmap mode ──────────────────
    // CIA2 port A: bits 0-1 = %01 → VIC bank 2 ($8000-$BFFF)
    lda CIA2_PORTA
    and #%11111100
    ora #%01
    sta CIA2_PORTA

    // $D018 = $38: screen at +$0C00 ($8C00), bitmap at +$2000 ($A000)
    lda #$38
    sta VIC_D018

    // Enable bitmap mode (BMM = bit 5 of $D011)
    lda VIC_D011
    ora #%00100000
    sta VIC_D011

    // Enable multicolor mode (MCM = bit 4 of $D016)
    lda VIC_D016
    ora #%00010000
    sta VIC_D016

    // Set background color
    lda #SPLASH_BG_COLOR
    sta VIC_BG0
    lda #COL_BLACK
    sta VIC_BORDER

    cli

    // ── 4. Wait ~150 frames, with FIRE/SPACE early-skip ──────
    lda #0
    sta zp_frame               // use frame counter as timer
    ldx #SPLASH_FRAMES
!wait_loop:
    // Wait for raster to LEAVE line 250 (so we don't double-count)
!wait_leave:
    lda $D012
    cmp #250
    beq !wait_leave-
    // Now wait for raster to ARRIVE at line 250 (once per frame)
!wait_arrive:
    lda $D012
    cmp #250
    bne !wait_arrive-

    // Check joystick FIRE (bit 4 of CIA1 port A, active-low)
    lda CIA1_PORTA
    and #%00010000
    beq !skip_splash+          // bit clear = fire pressed

    // Check SPACE key via GETIN
    jsr KERNAL_GETIN
    cmp #$20                   // space bar
    beq !skip_splash+

    dex
    bne !wait_loop-

!skip_splash:
    sei

    // ── 5. Restore text mode ─────────────────────────────────
    // Disable bitmap mode
    lda VIC_D011
    and #%11011111             // clear BMM bit
    sta VIC_D011

    // Disable multicolor
    lda VIC_D016
    and #%11101111             // clear MCM bit
    sta VIC_D016

    // Restore VIC bank 0
    lda CIA2_PORTA
    ora #%00000011             // bank 0 = %11
    sta CIA2_PORTA

    // Restore default memory pointers ($14 = screen at $0400, charset at $1000)
    lda #$14
    sta VIC_D018

    // Black background
    lda #COL_BLACK
    sta VIC_BG0
    sta VIC_BORDER

    // Clear screen
    jsr clear_bitmap_residue

    cli
    rts

// ============================================================
// clear_bitmap_residue
// Clears screen RAM ($0400) and color RAM ($D800) after bitmap
// mode, so text mode starts clean.
// Clobbers: A, X
// ============================================================
clear_bitmap_residue:
    lda #$20                   // space character
    ldx #0
!clr0:
    sta SCREEN_RAM, x
    sta SCREEN_RAM + 256, x
    sta SCREEN_RAM + 512, x
    sta SCREEN_RAM + 768, x
    inx
    bne !clr0-
    // Color RAM: set to light blue (default C64)
    lda #COL_LT_BLUE
    ldx #0
!clr1:
    sta COLOR_RAM, x
    sta COLOR_RAM + 256, x
    sta COLOR_RAM + 512, x
    sta COLOR_RAM + 768, x
    inx
    bne !clr1-
    rts

.assert "Splash routine fits before $7800", * <= $7800, true
