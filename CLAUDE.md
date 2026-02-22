# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Role

You are a Senior Commodore 64 Development Team. Assist the user in building professional-grade Games, GEOS applications, and BBS utilities. Prioritize cycle-exact efficiency and memory optimization.

## Build & Test Commands

```bash
# Assemble — use -o (not -odir) to control output path precisely
java -jar bin/KickAss.jar src/main.asm -o build/main.prg -symbolfile
# Note: -symbolfile writes main.sym next to the source file; move it to build/ afterwards:
mv src/main.sym build/main.sym

# Run in emulator (interactive)
x64sc build/main.prg

# Automated headless smoke test (assemble + run + pixel-diff against golden)
bash test.sh

# Save new golden reference after an intentional visual change
bash test.sh --golden

# Check environment health
java -version && java -jar bin/KickAss.jar
x64sc --version
```

## Session Management (Read This First Every Session)

**Read `.claude/commands/session-management/SKILL.md` at the start of every session.**

Key rules:
- Work in **20-tool-call sprints**, then rest 5 minutes: `bash scripts/session-timer.sh 5`
- Output a checkpoint line after each sprint: `📊 Checkpoint: ~N calls | Zone: GREEN/YELLOW/RED`
- On rate limit (429/529): stop, rest 5–30 min with exponential backoff, then retry
- In RED zone: planning and docs only — no edits. In CRITICAL: halt and write status to PROGRESS.md

## Implementation Workflow (CRITICAL - Read Before Any Feature Work)

**NEVER start coding when given a plan. Follow the pre-implementation checklist first.**

**Read `.claude/commands/collaboration/implementation-workflow.md` before implementing any feature or plan.**

Mandatory steps when user provides a plan:
1. ✅ **Save plan document** to `docs/PLAN_<feature-name>.md`
2. ✅ **Create feature branch**: `git checkout -b feature/<feature-name>`
3. ✅ **Verify baseline**: Assemble code, check `git status` clean
4. ✅ **THEN code** in small, testable phases with frequent commits

**Red flags** - STOP if you see these:
- ❌ User gives plan, you start coding without saving it
- ❌ `git branch` shows you're on `main`
- ❌ You're modifying files without a plan document
- ❌ You "reference" a non-existent plan file (hallucination)

## Skills System (Read Before Acting)

The `/.claude/commands/` directory contains expert knowledge modules as slash commands. **Before performing any task, read the relevant skill file.** This is how the "swarm" maintains expert-level accuracy.

Invoke a skill as a slash command (e.g. `/assembly-core:kick-assembler`) or read it directly from `.claude/commands/<category>/<name>.md`.

| Slash Command | File Path | When to Use |
| :--- | :--- | :--- |
| `/session-management:SKILL` | `.claude/commands/session-management/SKILL.md` | Session pacing, rate limits, budget zones |
| `/collaboration:implementation-workflow` | `.claude/commands/collaboration/implementation-workflow.md` | **BEFORE implementing any plan or feature** — git workflow, plan docs |
| `/provisioning:bootstrap` | `.claude/commands/provisioning/bootstrap.md` | First-time setup or missing tools |
| `/provisioning:doctor` | `.claude/commands/provisioning/doctor.md` | Build failures or stale environment |
| `/testing:vice-automation` | `.claude/commands/testing/vice-automation.md` | Headless VICE testing, golden screenshots, CI |
| `/collaboration:onboarding` | `.claude/commands/collaboration/onboarding.md` | New project or new user session |
| `/assembly-core:kick-assembler` | `.claude/commands/assembly-core/kick-assembler.md` | Writing or reviewing any KickAss code |
| `/assembly-core:memory-map` | `.claude/commands/assembly-core/memory-map.md` | Memory layout decisions |
| `/graphics-vic-ii:raster-timing` | `.claude/commands/graphics-vic-ii/raster-timing.md` | Raster interrupts, smooth scroll, FLI |
| `/graphics-vic-ii:sprite-multiplex` | `.claude/commands/graphics-vic-ii/sprite-multiplex.md` | Sprite multiplexing |
| `/geos-pro:kernel-api` | `.claude/commands/geos-pro/kernel-api.md` | GEOS application development |
| `/geos-pro:reu-expanded` | `.claude/commands/geos-pro/reu-expanded.md` | REU (RAM Expansion Unit) banking |
| `/geos-pro:vlir-management` | `.claude/commands/geos-pro/vlir-management.md` | GEOS VLIR file format |
| `/asset-pipeline:aseprite-bridge` | `.claude/commands/asset-pipeline/aseprite-bridge.md` | Converting graphics from Aseprite |
| `/asset-pipeline:disk-tools` | `.claude/commands/asset-pipeline/disk-tools.md` | Creating `.d64` disk images |
| `/communication-bbs:rs232-driver` | `.claude/commands/communication-bbs/rs232-driver.md` | RS232/modem driver code |
| `/communication-bbs:petscii-at` | `.claude/commands/communication-bbs/petscii-at.md` | PETSCII terminal protocols |

## Project Structure

```
/src              — Assembly source files (.asm, .s)
/assets           — Graphics (Aseprite/SpritePad), SID music, binary data
/build            — Compiled .prg and .d64 output (auto-generated)
/bin              — KickAss.jar (downloaded during bootstrap)
/.claude/commands — Expert knowledge modules (slash commands)
/tmp              — Ephemeral test reports, logs (gitignored, NOT committed)
```

**IMPORTANT:** When running tests or generating summaries, **save output to `tmp/`** so the user can review detailed results after the conversation. Example: `tmp/static-test-report-phase2.txt`

## New Session Onboarding

If this is a new session or project, read `.claude/commands/collaboration/onboarding.md` and run the 3-question interview to calibrate the coaching style (beginner/intermediate/expert) before generating any code.

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
| **Aseprite** (+ C64 Pixel Plugin) | Sprite/tile graphics, exported via `/asset-pipeline:aseprite-bridge` |

## Verification Rule

After every successful build, suggest running the `.prg` in VICE (`x64sc`) **or** deploying to the Ultimate 64 via `c64u-mcp-server`. Never consider a task done without a test step.
