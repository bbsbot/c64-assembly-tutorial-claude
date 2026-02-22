# Skill: GEOS Kernal API & Architecture

## Purpose
To provide Claude with the knowledge required to develop "System Compliant" GEOS applications. This focuses on using the Kernal jump tables, the event-loop, and standard UI elements rather than direct hardware poking.

## Core GEOS Principles
- **The Event Loop:** GEOS is event-driven. Claude must use `MainLoop` and register handlers for mouse clicks, menu selections, and keyboard input.
- **The DeskTop:** Programs must be able to "Exit to DeskTop" cleanly using the `EnterDeskTop` Kernal call.
- **No Direct Hardware:** Poking VIC-II or SID registers directly can crash GEOS. Always use Kernal routines like `SetGraphicsMode` or `DrawSprite` where possible.

## Critical Jump Table Addresses
Claude should use these standard GEOS vectors (typically accessed via `#import "geosmac.inc"`):
- `InitForIO` ($C16B): Temporarily enables hardware registers.
- `DoneWithIO` ($C16E): Restores GEOS state after hardware access.
- `GraphicsString` ($C135): The primary way to draw UI (lines, boxes, text).
- `GetNextEvent` ($C192): The heart of the event manager.

## Memory Management
- **Application Space:** GEOS apps usually reside from `$0400` to `$C000`.
- **The Header:** Every GEOS app must have a specific 256-byte header containing the icon, author, and file type.
- **Safety:** Page 0 ($00-$FF) is heavily used by the Kernal; Claude must check `geos.inc` to see which Zero Page addresses are safe for the application.

## Example Pattern: Basic GEOS UI
```kickasm
// GEOS Header and Main
#import "geosmac.inc"

start:
    LoadW r0, myMenuTable
    jsr DoMenu          // Draw a standard GEOS menu
    jmp MainLoop        // Hand control to the Kernal

myMenuTable:
    .byte 0, 15         // Top/Bottom
    .word 0, 60         // Left/Right
    .byte 1             // Number of items
    .byte MENU_ACTION   // Type
    .word labelText     // Text
    .word handleAction  // Subroutine

```

## Creative Guidance

When building for GEOS, Claude should suggest using standard dialog boxes (`DoDlgBox`) and menus to ensure the app feels like a natural part of the GEOS ecosystem.
