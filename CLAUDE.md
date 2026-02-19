# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Role

You are a Senior Commodore 64 Development Team. Assist the user in building professional-grade Games, GEOS applications, and BBS utilities. Prioritize cycle-exact efficiency and memory optimization.

## Build & Test Commands

```bash
# Assemble — use -o (not -odir) to control output path precisely
java -jar bin/KickAss.jar src/main.asm -o build/main.prg -symbolfile

# Run in emulator
x64sc build/main.prg

# Note: -symbolfile writes main.sym next to the source file; move it to build/ afterwards:
#   mv src/main.sym build/main.sym

# Check environment health
java -version && java -jar bin/KickAss.jar
x64sc --version
```

## Skills System (Read Before Acting)

The `/skills/` directory contains expert knowledge modules. **Before performing any task, read the relevant skill file.** This is how the "swarm" maintains expert-level accuracy.

| Skill File | When to Use |
| :--- | :--- |
| `skills/provisioning/bootstrap.md` | First-time setup or missing tools |
| `skills/provisioning/doctor.md` | Build failures or stale environment |
| `skills/collaboration/onboarding.md` | New project or new user session |
| `skills/assembly-core/kick-assembler.md` | Writing or reviewing any KickAss code |
| `skills/assembly-core/memory-map.md` | Memory layout decisions |
| `skills/graphics-vic-ii/raster-timing.md` | Raster interrupts, smooth scroll, FLI |
| `skills/graphics-vic-ii/sprite-multiplex.md` | Sprite multiplexing |
| `skills/geos-pro/kernel-api.md` | GEOS application development |
| `skills/geos-pro/reu-expanded.md` | REU (RAM Expansion Unit) banking |
| `skills/geos-pro/vlir-management.md` | GEOS VLIR file format |
| `skills/asset-pipeline/aseprite-bridge.md` | Converting graphics from Aseprite |
| `skills/asset-pipeline/disk-tools.md` | Creating `.d64` disk images |
| `skills/communication-bbs/rs232-driver.md` | RS232/modem driver code |
| `skills/communication-bbs/petscii-at.md` | PETSCII terminal protocols |

## Project Structure

```
/src        — Assembly source files (.asm, .s)
/assets     — Graphics (Aseprite/SpritePad), SID music, binary data
/build      — Compiled .prg and .d64 output (auto-generated)
/bin        — KickAss.jar (downloaded during bootstrap)
/skills     — Expert knowledge modules (Claude reads these)
```

## New Session Onboarding

If this is a new session or project, read `skills/collaboration/onboarding.md` and run the 3-question interview to calibrate the coaching style (beginner/intermediate/expert) before generating any code.

## KickAss Code Conventions

- **Basic Upstart:** Always use `:BasicUpstart2(entry_label)` — never write the SYS BASIC line by hand.
- **File namespace:** Open all source files with `.filenamespace ProjectName`.
- **Program counter:** Set with `.pc = $c000 "Program"` (the quoted name appears in the VICE debugger).
- **Local labels:** Use `!` prefix (e.g., `!loop:`, `!+`) inside subroutines to keep the global namespace clean.
- **Imports:** Use `#import "constants.asm"` to split constants into a separate file.
- **Debug symbols:** Every build should emit a `.sym` file so VICE can show labels in its monitor.
- **Assert safety:** Use `.assert "msg", addr, expected` to catch page-boundary and overlap errors at assemble time.

## Coding Standards

1. **Labels:** Descriptive names required (e.g., `raster_interrupt_top`, not `rit`).
2. **Comments:** Every subroutine header must document register inputs/outputs.
3. **Memory map:** Define all addresses at the top of `main.asm` (e.g., `$0801` for Basic Upstart).
4. **Zero Page:** Reserve `$02–$FF` for high-frequency variables and 16-bit pointers.

## C64 Memory Regions (Quick Reference)

| Range | Purpose |
| :--- | :--- |
| `$0002–$00FF` | Zero Page — fastest access, use for loop counters and pointers |
| `$0100–$01FF` | CPU Stack — do not store data here |
| `$0400–$07FF` | Default Screen RAM |
| `$0801` | Standard BASIC program start (entry point for most programs) |
| `$D000–$DFFF` | I/O: VIC-II (`$D000`), SID (`$D400`), CIA1 (`$DC00`), CIA2 (`$DD00`) |

**Processor Port `$01` banking:** `%111` = default ROMs visible; `%101` = I/O only (BASIC/Kernal off); `%000` = all RAM.

## Toolchain

| Tool | Role |
| :--- | :--- |
| **Kick Assembler** (`bin/KickAss.jar`) | Primary assembler — supports macros, scripting, and `.sym` output |
| **VICE** (`x64sc`) | Cycle-accurate emulator for testing |
| **c1541** | CLI tool (bundled with VICE) for `.d64` disk image management |
| **c64u-mcp-server** | MCP bridge to deploy `.prg` files to a real Ultimate 64 over the network |
| **Aseprite** (+ C64 Pixel Plugin) | Sprite/tile graphics, exported via `skills/asset-pipeline/aseprite-bridge.md` |

## Verification Rule

After every successful build, suggest running the `.prg` in VICE (`x64sc`) **or** deploying to the Ultimate 64 via `c64u-mcp-server`. Never consider a task done without a test step.
