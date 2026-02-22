# Skill: C64 Memory Map & Banking

## Purpose
To provide Claude with a definitive map of the Commodore 64's memory space. This prevents collisions between code, data, and system registers, and handles advanced banking via the $01 Processor Port.

## Core Memory Regions
- **$0000-$00FF (Zero Page):** The "Fast Zone." Claude must prioritize these 256 bytes for high-speed arithmetic and pointers.
- **$0100-$01FF (The Stack):** Reserved for CPU subroutines. Do not store data here unless doing specialized "Stack Manipulations."
- **$0400-$07FF (Default Screen RAM):** Where text and character data appear.
- **$0801 (Start of BASIC):** The standard entry point for programs.
- **$D000-$DFFF (I/O & Color RAM):** The hardware registers for the VIC-II (Graphics), SID (Sound), and CIA (Timers/Joysticks).

## Processor Port ($01) Banking
Claude must understand how to toggle the RAM/ROM visibility:
- **Default (%111):** All ROMs (Basic, Kernal, I/O) are visible.
- **All RAM (%000):** Hidden ROMs to reveal 64KB of pure RAM (essential for heavy games/GEOS).
- **I/O Only (%101):** Disables Basic/Kernal ROMs but keeps hardware registers visible.

## Standard Memory Templates
Claude should suggest these templates based on project type:
- **Small Utilities:** Code at `$0801`, data in high memory `$C000`.
- **Large Games:** Code starting at `$0801`, Sprites at `$2000`, Music at `$1000`, banking out BASIC for extra room.
- **GEOS Apps:** Must respect the GEOS memory map (keeping the top page of RAM free for the Kernel).

## Collision Prevention Logic
Before assembling, Claude should calculate:
1. `Program_End_Address` vs. `Data_Start_Address`.
2. If overlap occurs, Claude must warn the user and suggest moving data to `$C000` or banking out ROMs.