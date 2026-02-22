# Skill: Sprite Multiplexing (Virtual Sprites)

## Purpose
To enable Claude to overcome the C64's hardware limit of 8 sprites. This skill provides the logic for a "Sprite Multiplexer," which dynamically reassigns the 8 hardware sprite slots as the raster beam moves down the screen.

## Core Logic
1. **The Sprite Table:** Maintain a virtual table of up to 32 sprites, each with X, Y, Color, and Pointer data.
2. **Y-Sorting:** Every frame, the virtual sprites must be sorted by their Y-coordinate. This is critical for the multiplexer to know which sprite to display next.
3. **The Raster Chain:** - Set a raster interrupt for the Y-position of the first sprite.
    - In the interrupt, update the hardware registers ($D000-$D00F) for that sprite.
    - Set the next interrupt for the next sprite in the sorted list.

## Implementation Guidelines
Claude should suggest the following structure for a multiplexer engine:

- **Sort Routine:** Use a simple Bubble Sort or Shell Sort (since sprite order usually doesn't change drastically between frames).
- **The "Top" Interrupt:** An interrupt at line 0 to reset the multiplexer pointers and sort the list for the new frame.
- **The "Dynamic" Interrupts:** Use the `raster-timing.md` skill to create cycle-stable updates to prevent "sprite flickering" or "shearing."

## Constraints & Expert Tips
- **The 8-Sprite Limit per Line:** Even with a multiplexer, you cannot have more than 8 sprites on the *same* horizontal scanline.
- **Timing Margin:** Remind the user that the CPU needs time to update the registers. If sprites are too close vertically (less than 21 lines), the multiplexer may fail.
- **X-Expansion:** If a sprite is expanded horizontally, it takes up more "room" in the timing budget.

## Example Pattern
When asked for "more than 8 sprites," Claude should output a template for a `Sprite_Data_Table` and a `Sort_Sprites` subroutine, then offer to write the IRQ chain logic.