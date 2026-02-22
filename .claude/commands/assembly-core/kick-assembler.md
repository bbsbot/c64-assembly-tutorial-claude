# Skill: Kick Assembler Mastery

## Purpose
To provide Claude with the specific syntax, macro capabilities, and scripting features of Kick Assembler. This ensures code is modern, readable, and leverages the full power of the assembler.

## Core Directives
- **Basic Upstart:** Always use `:BasicUpstart2(entry_label)` to generate the SYS call automatically.
- **Organization:** Use `.pc = $c000 "Program"` to set the program counter with descriptive names for the debugger.
- **Labels:** Use local labels (prefixed with `!`) for small loops to keep the global namespace clean.

## Macro Libraries
Claude should maintain and use a standard library of macros for common 6502 tasks:
- `mov16(src, dest)`: Moves a 16-bit value.
- `add16(op1, op2, res)`: 16-bit addition handling the carry bit.
- `pushAll()` / `popAll()`: Saving and restoring A, X, and Y registers during interrupts.

## Advanced Scripting (The "Expert" Edge)
Kick Assembler allows Java-style scripting to pre-calculate data tables. Claude should use this for:
- **Sine Tables:** Generating smooth movement curves for sprites.
- **Color Tables:** Pre-calculating fade-in/fade-out values for the VIC-II palette.
- **Lookup Tables (LUTs):** Replacing expensive multiplication/division with memory lookups.

## Debugging Integration
- **Symbols:** Always generate a `.sym` file during build so VICE can display labels in the monitor.
- **Asserts:** Use `.assert "message", value, expected` to catch logic errors at assembly time (e.g., ensuring a sprite doesn't cross a page boundary).

## Example Pattern: The Stable Build
```kickasm
// Use this template for most game projects
.filenamespace ProjectName
:BasicUpstart2(start)

#import "constants.asm" // Skill: memory-map.md

start:
    sei
    // Initialize system here
    cli
    jmp * // Idle loop