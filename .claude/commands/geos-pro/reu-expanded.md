# Skill: REU Mastery & GEOS Memory Expansion

## Purpose
To empower the AI to utilize RAM Expansion Units (REUs) for high-performance data handling. This includes support for vintage 1700/1750/1764 units and the expanded 16MB REU capabilities of the Ultimate 64 and Chameleon.

## REU Hardware Fundamentals
- **The REC (RAM Expansion Controller):** Located at `$DF00`. Claude must interact with these registers to trigger DMA (Direct Memory Access) transfers.
- **Transfer Types:** - **Stash:** Move data from C64 RAM to REU.
    - **Fetch:** Move data from REU to C64 RAM.
    - **Swap:** Exchange data between C64 and REU.
    - **Verify:** Compare C64 RAM with REU data.

## GEOS Integration
GEOS uses the REU primarily for "Fast Wheel" (task switching) and as a RAM disk. Claude should prioritize these patterns:
- **Detecting REU:** Use the GEOS `GetREUSize` or check the `reuPresent` flag.
- **Safe Zones:** Ensure DMA transfers do not overwrite the GEOS Kernal or the REU-based disk drivers.
- **Banking:** For Ultimate 64 users, Claude can manage up to 256 banks of 64KB each.

## Implementation: DMA Transfer Macro
Claude should use this logic for high-speed memory moves:
```kickasm
// DMA Move Macro (Simplified)
.macro DMA_Move(c64_addr, reu_addr, length, bank, command) {
    lda #<c64_addr; sta $df02
    lda #>c64_addr; sta $df03
    lda #<reu_addr; sta $df04
    lda #>reu_addr; sta $df05
    lda #bank;      sta $df06
    lda #<length;   sta $df07
    lda #>length;   sta $df08
    lda #command;   sta $df01 // Execute (e.g., $91 for Fetch)
}

```

## Expert Scenarios

* **Large Games:** Use the REU as a "VRAM" to swap out entire levels or large sprite sets in a single frame.
* **BBS/Comms:** Use REU as a massive buffer for high-speed RS232 file transfers.
* **Ultimate 64 Hardware:** Claude should offer to use the `Ultimate Command Interface` to automate REU image loading.

## Safety Check

Always remind the user to check the Power Supply; vintage REUs are notorious for overtaxing original C64 bricks. On modern hardware (U64), this is not an issue.
