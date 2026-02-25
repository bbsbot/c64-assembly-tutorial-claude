# Project History: C64 Block Tutor

> The story of building a Commodore 64 program entirely with AI pair-programming — from first commit to Matrix Rain, over one week in February 2026.

---

## The Premise

What happens when you point a modern AI coding agent at a 43-year-old computer architecture?

The **C64 Block Tutor** started as an experiment: could [Claude Code](https://claude.ai/code) — Anthropic's AI pair-programming CLI — write production-quality 6502 assembly for the Commodore 64? Not toy examples, but a real interactive program with a state machine, joystick input, live code generation, SID audio, and automated testing?

The answer turned out to be yes — with caveats, workarounds, late-night rate limits, and more than a few assembler syntax surprises. This document tells that story.

---

## Day 1 — First Commit and the 11 PM Rate Limit (Feb 18)

### `3bc0716` first commit

The project began with a fork of [ultimate-64-dev](https://github.com/bbsbot/ultimate-64-dev), a template repository containing 15 "skill" files — expert knowledge modules that teach an AI agent about C64 development. Skills like `kick-assembler.md` explain KickAss syntax rules. Skills like `raster-timing.md` document VIC-II cycle counts. The idea: give the agent *domain expertise* before asking it to write code.

The first session started with the **onboarding skill** — a 3-question interview to calibrate the AI's coaching style (beginner, intermediate, or expert). Then we dove in: constants.asm for the zero-page layout, main.asm for the BASIC upstart stub, and the skeleton of a state machine.

### `785e2ce` WIP: hit rate limit — constants.asm + main.asm skeleton

And then, at 11 PM, the API rate limit hit.

This was the first lesson of agentic development: **the AI burns through tokens fast.** Each tool call (read a file, write a file, run a build) consumes part of a limited budget. When you're writing assembly — where every instruction matters and the AI needs to read existing code before each edit — those calls add up quickly.

The commit message says it all: "hit rate limit - constants.asm + main.asm skeleton resets 11pm ETC." We saved what we had and called it a night. This experience directly led to the creation of the **Session Management skill** — a Pomodoro-style pacing system with budget zones (GREEN/YELLOW/RED/CRITICAL) and exponential backoff for rate limits.

---

## Day 2 — Phase 1 Complete, Testing Infrastructure (Feb 19)

### `6e52798` WIP: Phase 1 completed, ready to test

The next morning, we resumed and finished the core program:
- **6 block types** (SET BORDER, SET BG, PRINT, SHOW SPRITE, WAIT, LOOP BACK)
- **Joystick-driven UI** with a split-panel layout (palette on the left, program on the right)
- **Runtime code generation** — walking a 16-slot array and emitting real 6502 opcodes at `$5000`
- **NMI handler** for emergency stop via the RESTORE key

The code generation engine was the most interesting challenge. Each block type has an "emitter" function that writes literal machine code bytes into a buffer at `$5000`. The WAIT emitter is particularly clever — it calculates `outer_hi = n × 3` at runtime and bakes it into a 21-byte busy-loop. At 985,248 Hz PAL timing, 768 outer passes × 256 inner × 5 cycles ≈ 1 second.

### `dfe23c2` feat: automated headless VICE testing + skills update

This was the commit that changed everything. Instead of manually launching VICE to test, we created `test.sh` — a headless smoke test that:

1. Assembles the program with KickAss
2. Runs VICE in warp mode for a fixed number of PAL cycles
3. Captures an exit screenshot
4. Pixel-diffs it against a golden reference image

This meant the AI could verify its own work without human intervention. Every code change could be followed by `bash test.sh` to confirm nothing broke. The testing infrastructure was documented in a new skill: **vice-automation.md**.

**Key discovery:** VICE's `-limitcycles` flag always exits with code 1 — this is normal behavior, not an error. We learned to use `|| true` to prevent the build script from aborting. Also: **never pipe VICE output** — redirecting stdout/stderr to a pipe prevents `-exitscreenshot` from firing on some OS/VICE combinations. Always redirect to a file: `>"log" 2>&1 || true`.

### `3e194fa` feat: keyboard nav (cursor+space) + fix LOOP BACK stop

With testing in place, we could iterate quickly. This commit added keyboard navigation alongside joystick input, and fixed a critical bug: the LOOP BACK block's infinite loop (`JMP $5000`) needed a stop mechanism. The solution: a zero-page flag (`zp_stop_flag`) that the NMI handler sets to `$FF`. The generated LOOP BACK code checks this flag each iteration and falls through to `RTS` when it's set.

---

## Day 3 — Testing Deep Dive, Documentation, Session Management (Feb 20)

### `8b7a08a` test: automated interactive test via VICE remote monitor

The headless screenshot test was good, but it could only verify visual output. We needed to test *behavior* — does the codegen emit the right bytes? Does the state machine transition correctly?

The answer was VICE's **remote monitor** (TCP port 6510). We built `test_interactive.py` — a Python harness that connects to VICE over TCP and injects input by writing directly to zero-page variables:

```python
write_byte(s, 0x08, 0x02)   # zp_joy_edge: JOY_DOWN
write_byte(s, 0x10, 0x85)   # zp_last_key: F1
```

Then it reads hardware registers and memory to assert correctness. 35 checks across 13 test groups — from basic init state to verifying exact opcode sequences in the `$5000` buffer.

### `93c25dc` feat: install session management skill

After the Day 1 rate limit incident, we formalized what we'd learned into the **Session Management skill**. It defines:
- **20-tool-call sprints** with mandatory 5-minute rests
- **Budget zones**: GREEN (0–50%), YELLOW (50–75%), RED (planning only), CRITICAL (halt)
- **Rate limit protocol**: on 429/529 errors, stop and wait with exponential backoff (5 → 10 → 30 → 60 minutes)

This skill was later contributed back to the upstream ultimate-64-dev repository.

### `9c7c972` FEAT: fully automated testing with video recording

Added `scripts/run_and_record.sh` — runs the interactive test suite while recording the desktop with ffmpeg. The recording shows every state transition at authentic C64 speed (no warp mode): cursor movement, block addition, code execution, sprite appearance, all 35/35 checks passing. This became the demo video on the project's GitHub Pages site.

### `496a62a` through `764fc9b` — Documentation blitz

Five commits in rapid succession: a comprehensive README, an index.html write-up page, and a series of fixes for broken links and video embeds. The README grew from a one-liner to a full project bible with architecture diagrams, memory maps, code examples, and test documentation.

**Lesson learned:** Link paths that work locally (like `docs/index.html`) don't work on GitHub — you need the GitHub Pages URL. We went through three rounds of fixes before getting all the links right.

---

## Day 4 — The Assembly View Feature Branch (Feb 21)

This was the most ambitious day. We created the `feature/assembly-view-toggle` branch and started a multi-phase feature plan.

### The Plan

The idea: press **T** to toggle from the block-programming view into a live **Assembly View** showing the disassembled machine code. Six phases:

1. **Metadata Foundation** — Track instruction addresses, mnemonic IDs, and source blocks during codegen
2. **Static Assembly View** — Render a scrollable disassembly screen
3. **Syntax Highlighting** — Colour-code instructions by category
4. **Step-Through Execution** — Execute instructions one at a time with live register display
5. **Animated Dataflow** — (future) Trace value flows with ASCII arrows
6. **Deluxe Annotations** — (future) Animated block previews

We saved this as `docs/PLAN_assembly_view_toggle_v2.md` — 352 lines of detailed specifications.

### `eeb66c0` PROCESS: Add implementation workflow safeguards

Before writing any feature code, we created the **Implementation Workflow skill**. This was born from a near-disaster in an earlier session where the AI started coding a feature directly on `main` without saving the plan. The skill mandates:

1. Save plan document to `docs/PLAN_<feature-name>.md`
2. Create feature branch: `git checkout -b feature/<feature-name>`
3. Verify baseline: assemble code, check `git status` clean
4. THEN code — in small, testable phases with frequent commits

It also defines **red flags** that should trigger an immediate stop:
- User gives plan, you start coding without saving it
- `git branch` shows you're on `main`
- You're modifying files without a plan document
- You "reference" a non-existent plan file (hallucination!)

### `e67ffd3` FEAT: Phase 1 — Assembly View Toggle Metadata Foundation

The codegen engine was extended to emit a 6-byte metadata record for every instruction: source block index, mnemonic ID, operand bytes, and address offset. This metadata lives at `$6000` (the ASM_META_BUF) and is what the Assembly View reads to render its disassembly.

### `ffc8eb6` FEAT: Phase 2 — Static Assembly View rendering

The `asm_view.asm` module was born — initially 300+ lines of screen-code rendering:
- Row 0: title bar ("ASSEMBLY VIEW [F1:RUN T:BLOCKS]")
- Row 1: column headers (ADDR OPCODE MNEMONIC OPERAND)
- Rows 2–18: 17 lines of scrollable disassembly
- Row 19: register display (A:00 X:00 Y:00 SP:FF [NV-BDIZC])
- Row 21: help text

### `59c80ad` PROCESS: Migrate skills/ to .claude/commands/

A structural change: we moved all skill files from `skills/` to `.claude/commands/` so they work as proper Claude Code slash commands. Now you can type `/assembly-core:kick-assembler` to invoke the assembler knowledge, or `/testing:vice-automation` to review the testing protocol.

### KickAss Syntax Gotchas Discovered

Day 4 was also when we discovered most of the KickAss v5.25 quirks that tripped up the AI:

- **No `:` statement separator** — `lda #$A9 : jsr foo` doesn't work. Each instruction needs its own line. The AI kept trying to write compact one-liners.
- **`asl a` is invalid** — the correct syntax is bare `asl` for accumulator shift.
- **`dec a` / `inc a` don't exist on 6502** — the AI occasionally confused 6502 with 65C02 instructions.
- **Long branches** — when a branch target exceeds ±127 bytes, KickAss reports a cryptic error. The fix is to invert the branch and add a JMP: `bne !skip+ : jmp target` instead of `beq target`.
- **Sprite data must be exactly 64 bytes** — 21 rows × 3 = 63, plus exactly 1 padding byte. Not 0, not 2.
- **`-odir build/` resolves relative to the source file** — so `src/main.asm -odir build/` produces `src/build/main.prg`. Use `-o build/main.prg` instead.

---

## Day 5 — Testing Phase 2, Syntax Highlighting (Feb 22–23)

### `1835aa5` TEST: Phase 2 headless integration tests — 8/8 PASS

The Assembly View needed its own tests. We extended `test.sh` to inject a `T` keypress via VICE's `-keybuf` flag and verify the screen changes.

**Key discovery about `-keybuf`:** Case matters! `-keybuf "t"` sends lowercase `t` → PETSCII `$54` → matches our T-key handler. But `-keybuf "T"` sends SHIFT+T → PETSCII `$74` → handler NOT matched. This cost about an hour of debugging.

**Another gotcha:** Double-keybuf (`-keybuf "tt"`) always produces a mysterious 1007-byte black PNG regardless of timing parameters. We never found the root cause. The workaround: use a single keybuf and verify the toggle-back behavior through code inspection rather than a second screenshot.

### `5c78e63` FEAT: Phase 3 — Syntax highlighting for Assembly View

The `colorize_code_area` routine walks the metadata buffer and applies colours based on instruction category:
- **Purple** for system instructions (SEI, CLI, RTS)
- **Cyan** for VIC-II I/O writes (STA $D020, LDA #color paired with VIC blocks)
- **Red** for flow control (BNE, JMP)
- **Yellow** for Kernal calls (JSR $FFD2)
- **Green** for the cursor line highlight

The colour mapping required a lookup table (`mnemonic_color_table`) indexed by mnemonic ID — one of the first times we put data tables in `asm_strings.asm` alongside the mnemonic string tables.

**Long branch crisis:** The colorize loop body exceeded 127 bytes, causing `bcs` and `bne` branches to fail. We had to apply the invert-and-JMP pattern multiple times: `bcs !skip+ → bcc !skip+ : jmp target`.

---

## Day 6 — Step-Through, Splash Screen, SID Music (Feb 23–24)

### `8d01d86` FEAT: Phase 4 — Step-through execution + multicolor bitmap splash screen

Two major features in one commit:

**Step-Through Engine:** Press S in Assembly View to enter stepping mode. Each press of S or FIRE executes one simulated instruction with live register updates. The engine uses a 15-entry jump table dispatching on mnemonic ID. VIC-II writes happen live — when you step through `STA $D020`, the border colour changes in real time. A SID beep plays on each step, and a 3-note ascending chime plays when RTS is reached.

**Clever optimization:** The WAIT block generates a 6-instruction busy-loop (LDX/DEX/BNE/DEC/BNE/DEC/BNE). Instead of making the user step through hundreds of thousands of loop iterations, the stepper detects WAIT blocks by checking `source_block_idx` and auto-skips the entire loop, setting shadow registers to their final values.

**Splash Screen Saga:** We originally planned a multicolor bitmap splash screen using VIC Bank 2 ($8000–$BFFF). A Python script (`convert_splash.py`) would convert a 1024×1024 image to 160×200 multicolor. But there was a problem: the SID music binary (Swamp Sollies by Banana, from the HVSC collection) occupies $9000–$CFFF — right in the middle of the bitmap region.

### `864371d` FEAT: Border color-cycle IRQ during startup loading

While figuring out the splash screen conflict, we added a quick visual indicator: a raster IRQ that cycles the border colour during initialization, so the user sees activity instead of a blank screen.

### `6a1e08f` FEAT: Text splash screen with SID music

The solution to the memory conflict: abandon the bitmap splash and use a **text-mode splash** instead. This frees up the bitmap region entirely. The splash shows project credits in screen codes while the SID plays Swamp Sollies. The `SKIP_SPLASH` build flag (`-define SKIP_SPLASH=1`) disables the splash for headless tests, since the 16 KB SID binary would otherwise slow down builds.

The SID integration required a custom Python script (`strip_sid_header.py`) to strip the 124-byte PSID header from the `.sid` file and produce a raw binary that loads at `$C000` with init at `$C000` and play at `$C475`.

---

## Day 7 — Matrix Rain and Completion (Feb 24)

### `7837a20` DOCS: Future ideas

Before the final feature, we brainstormed Phase 5+ ideas:
1. **Live Memory Visualizer** — a 16×16 thermal camera showing RAM activity
2. **Raster-Timed Split Screen** — Block View + ASM View simultaneously
3. **Matrix Rain Transition** — assembly code cascading like The Matrix
4. **Animated Dataflow Arrows** — ASCII arrows tracing value flows
5. **Deluxe Annotations** — animated block previews with sprite overlays

We chose Matrix Rain as the capstone feature.

### `d37236f` FEAT: Matrix Rain transition effect when entering ASM View

The final feature — and the most visually dramatic. When pressing T to enter Assembly View, instead of an instant clear-and-render, the screen erupts in a **column-by-column digital rain** animation:

**Algorithm:**
1. Blank the screen (VIC `$D011` bit 4 off)
2. Render the full ASM view into SCREEN_RAM
3. Copy SCREEN_RAM → shadow buffer at `$6200` (1000 bytes)
4. Clear SCREEN_RAM, unblank
5. Initialize 40 column state records with staggered delays (left-to-right wave + LFSR jitter)
6. Start SID voice 2 — sawtooth waveform, frequency sweeping from `$30` to `$01`
7. Run 90 frames (~1.8 seconds): each column rains random characters downward, settling to the final shadow buffer character 3 rows behind the head. Colour trail: white head → light green → green.
8. Finalize: copy shadow buffer back, apply syntax highlighting, silence SID

**Technical details:**
- Row address lookup tables generated with KickAss `.fill` — avoids multiply-by-40 at runtime
- 8-bit LFSR PRNG (`eor #$1D` tap) seeded from `zp_frame` for random characters
- 32-byte table of "digital rain" screen codes (letters + digits)
- Column stagger: `(col_index / 4) + (PRNG & $03)` — wave + jitter, ~12 frame total spread
- Per-column state: 4 bytes (delay, head_row, phase, seed) × 40 columns = 160 bytes at `$65E8`

The implementation required fixing a long-branch error (the column update loop exceeds 127 bytes) and working around a KickAss namespace issue (`.var` declarations aren't accessible across file namespaces — the `SKIP_SPLASH` check had to use `cmdLineVars` directly).

---

## The Merge

With Matrix Rain complete, we merged `feature/assembly-view-toggle` into `main` — a clean fast-forward of 24 commits spanning the entire feature branch history. The merge attempt initially deleted 8 skill files from disk (a git artifact from the `skills/` → `.claude/commands/` migration). A quick `git checkout HEAD --` restored them.

---

## By the Numbers

| Metric | Value |
|--------|-------|
| **Development time** | 7 days (Feb 18–24, 2026) |
| **Total commits** | 35 |
| **Assembly source files** | 14 |
| **Lines of 6502 assembly** | ~5,100 |
| **Memory used** | $0801–$CFFF (~50 KB of 64 KB) |
| **States in state machine** | 6 |
| **Block types** | 6 |
| **Test checks** | 35 (interactive) + headless golden screenshot |
| **KickAss asserts** | 13 |
| **AI skill modules** | 18 (15 inherited + 3 created) |
| **Plan documents** | 5 |
| **Rate limit incidents** | At least 2 (led to session management skill) |
| **KickAss syntax gotchas discovered** | 8 |

---

## Skills Created and Contributed Back

Three skills were created during this project that didn't exist in the upstream [ultimate-64-dev](https://github.com/bbsbot/ultimate-64-dev) template:

### 1. Implementation Workflow (`collaboration/implementation-workflow.md`)

Born from a near-miss where the AI started coding a feature on `main` without saving the plan. Defines mandatory pre-implementation steps (save plan → create branch → verify baseline → code), red flags that trigger an immediate stop, and structured commit message formats with phase tracking.

### 2. Session Management (`session-management/SKILL.md`)

Born from the Day 1 rate limit at 11 PM. Defines Pomodoro-style work cadence (20-call sprints, 5-minute rests), budget zones (GREEN/YELLOW/RED/CRITICAL), and rate limit detection with exponential backoff. Prevents the AI from burning through tokens too fast and hitting rate limits at critical moments.

### 3. VICE Automation (`testing/vice-automation.md`)

Born from the headless testing infrastructure built on Day 2. Documents VICE command-line flags for headless operation, cycle budget guidelines, golden reference workflow, pixel comparison techniques (PowerShell on Windows, ImageMagick on Unix), and a troubleshooting table for 9 common failure modes.

Two existing skills were also improved with Windows-specific workarounds:
- **bootstrap.md** — Added Cloudflare blocking workaround for VICE downloads from SourceForge
- **doctor.md** — Added test pipeline health checks and PNG size validation

---

## Lessons Learned

### About the Commodore 64

1. **The 6502 is ruthlessly simple.** No multiply instruction. No 16-bit registers. Branch targets limited to ±127 bytes. Every "complex" operation (like multiply-by-40 for screen row addresses) becomes a lookup table or a shift-and-add sequence.

2. **Memory is a shared resource.** The SID music, the VIC-II bitmap, the screen RAM, the generated code buffer, the metadata — everything has to be carefully arranged to avoid overlap. Our splash screen plan failed because the SID binary landed in the bitmap region.

3. **Screen codes ≠ PETSCII.** The C64 has two different character encodings depending on whether you're writing to screen RAM or using Kernal CHROUT. The AI had to learn this distinction.

4. **VIC-II colour RAM is at $D800, not next to screen RAM.** Syntax highlighting means writing to two separate 1000-byte regions for every screen update.

### About Agentic AI Development

1. **Skills are force multipliers.** The 15 inherited skill modules meant the AI rarely made architecture-level mistakes. It knew to use `:BasicUpstart2`, to put constants in `constants.asm`, to use `.filenamespace`. The skills it created during the project (workflow, session management, testing) prevented process-level mistakes.

2. **Rate limits are the new "running out of battery."** They hit at the worst times (11 PM, mid-feature). The Pomodoro cadence isn't just about the AI — it gives the human time to review what was just written.

3. **The AI hallucination risk is real for assembly.** The AI occasionally tried to use 65C02 instructions (`inc a`, `dec a`) on a 6502, or used KickAss syntax from a different version. The assembler caught these at build time, but they cost debugging cycles.

4. **Test infrastructure pays for itself immediately.** Once `test.sh` existed, every feature could be verified automatically. The AI would write code, build, test, and fix issues in a tight loop — often faster than a human could spot the problem visually.

5. **Plans prevent disasters.** The implementation workflow skill's insistence on "save plan, create branch, verify baseline, THEN code" prevented at least three potential messes where the AI would have started modifying code in the wrong context.

6. **Long branches are the #1 assembly gotcha.** Almost every non-trivial routine eventually exceeded the 127-byte branch limit. The invert-and-JMP pattern (`bne !skip+ → beq !skip+ : jmp target`) became second nature.

---

## What We'd Do Differently

- **Start with the testing infrastructure.** We built `test.sh` on Day 2, but if we'd built it on Day 1, the rate limit incident might not have cost us as much progress.
- **Plan the memory map upfront.** The splash screen bitmap/SID conflict could have been caught at planning time with a simple address range table.
- **Use `.var` less, `.label` more.** KickAss `.var` declarations don't cross namespace boundaries, which caused a build failure in the Matrix Rain module. `.label` is globally visible and simpler.

---

## Acknowledgments

- **Swamp Sollies** SID music by **Banana**, from the High Voltage SID Collection (HVSC)
- **KickAss assembler** by Mads Nielsen
- **VICE emulator** by the VICE team
- **ultimate-64-dev** template repository for the initial skill modules
- **Claude Code** by Anthropic — the AI pair-programmer that wrote all the assembly

---

*This history was reconstructed from git commit messages, plan documents, and the AI agent's memory files. The commit hashes are real; the narrative is as accurate as 35 commits and 5 plan documents can make it.*
