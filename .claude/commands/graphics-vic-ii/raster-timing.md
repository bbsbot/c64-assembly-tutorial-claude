# Skill: VIC-II Raster Timing & Interrupts

## Purpose
This skill enables Claude to perform cycle-exact graphics programming. It focuses on the Raster Interrupt ($D011/$D012) to synchronize code with the display beam for flickering-free visuals.

## Core Concepts
- **The Raster Beam:** The C64 draws 312 lines (PAL) or 263 lines (NTSC). Claude must know the difference to ensure music and animations run at the correct speed.
- **The Raster Interrupt:** Using `$D012` to trigger code at a specific scanline.
- **Stable Raster:** For advanced effects (like side-border opening), Claude must use a "double-interrupt" or "cycle-counting" to ensure the CPU is perfectly synced with the beam.

## Raster Implementation Pattern
When the user wants a background change or a split-screen, Claude should use this KickAss template:

```kickasm
// Setup Raster Interrupt
    sei
    lda #$7f
    sta $dc0d      // Disable CIA 1 Timer IRQ
    lda $d01a
    ora #$01       // Enable Raster IRQ
    sta $d01a
    
    lda #60        // Trigger at line 60
    sta $d012
    lda $d011
    and #$7f       // Clear 8th bit of raster line
    sta $d011

    lda #<irq_handler
    sta $0314
    lda #>irq_handler
    sta $0315
    cli
    rts

irq_handler:
    dec $d019      // Acknowledge IRQ
    inc $d020      // Visual effect: flash border
    // --- Code Here ---
    dec $d020
    jmp $ea31      // Return to Kernal IRQ

```

## Advanced Effects Logic

* **Smooth Scrolling:** Managing the `$D016` (Horizontal) and `$D011` (Vertical) fine-scroll bits.
* **Flexible Line Interpretation (FLI):** Knowledge of how to trick the VIC-II into refreshing color data more frequently.
* **Bad Lines:** Claude must account for "Bad Lines" (every 8th line in text mode) where the VIC-II "steals" 40-43 CPU cycles to fetch character data.

## Expert Advice

If the user is a beginner, Claude should suggest simple `$D020` border color changes first. If an expert, Claude should offer to calculate exact cycle counts for "stable raster" loops.
