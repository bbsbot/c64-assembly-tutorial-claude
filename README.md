![C64 Block Tutor Architectural Diagram](docs/c64dev-how-it-works.png)

# C64 Block Tutor

> A Scratch-like block-programming interface for the Commodore 64 — compose a program with a joystick, press F1, and real 6502 machine code assembles itself and executes inside the running C64.

*35/35 tests passing · [Full write-up with embedded video →](https://bbsbot.github.io/c64-assembly-tutorial-claude)*

---

## What is it?

The C64 Block Tutor is a native Commodore 64 program written entirely in **6502 assembly** (assembled with [KickAss v5.25](http://theweb.dk/KickAssembler/)). It teaches beginners how the C64 works by letting them build a short program from a palette of visual blocks — no keyboard required, just a joystick:

| Block | Parameter | What it does |
|---|---|---|
| **SET BORDER** | colour (0–15) | Changes the screen border colour via `$D020` |
| **SET BG** | colour (0–15) | Changes the background colour via `$D021` |
| **PRINT** | character A–Z | Prints one PETSCII character via Kernal `$FFD2` |
| **SHOW SPRITE** | *(none)* | Enables sprite 0 at (150, 130) in light-blue |
| **WAIT** | seconds (1–9) | Busy-waits using a 16-bit PAL-timed loop |
| **LOOP BACK** | *(none)* | Jumps back to `$5000`; stop with RESTORE |

Pressing **F1** walks the slot array, emits one block's worth of 6502 opcodes per entry, appends `CLI / RTS`, and jumps to `$5000` — executing the freshly assembled program right inside the running C64.

---

## Demo

[![Watch the demo](docs/preview.png)](https://bbsbot.github.io/c64-assembly-tutorial-claude/test_recording_vice.mp4)

The recording shows the full automated test suite running at real C64 speed (no warp mode). All 35/35 checks pass.
**[Download / watch · `docs/test_recording_vice.mp4` · 0.8 MB · 3 min 4 s](https://bbsbot.github.io/c64-assembly-tutorial-claude/test_recording_vice.mp4)**
See the [Github page](https://bbsbot.github.io/c64-assembly-tutorial-claude) for a timestamped walkthrough of every test group.

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| **Java** | 11+ (tested on 25.0.1) | Required to run KickAss |
| **KickAss** | 5.25 | `bin/KickAss.jar` — included in repo |
| **VICE x64sc** | 3.x | [vice-emu.sourceforge.io](https://vice-emu.sourceforge.io/) |
| **Python 3** | 3.10+ | Interactive test suite only |

On Windows, VICE is expected at `C:\tools\vice\bin\x64sc.exe`. Override with the `VICE` environment variable.

---

## Quick Start

```bash
# 1. Assemble
java -jar bin/KickAss.jar src/main.asm -o build/main.prg -symbolfile
mv src/main.sym build/main.sym

# 2. Run in VICE (interactive)
x64sc build/main.prg

# 3. Automated smoke test (assemble + run + pixel-diff against golden)
bash test.sh

# 4. Save a new golden reference after an intentional visual change
bash test.sh --golden

# 5. Full interactive test suite (35 checks via VICE remote monitor)
python test_interactive.py

# 6. Record the test suite to video
bash scripts/run_and_record.sh
```

### Joystick controls (inside the C64 program)

| Input | Action |
|---|---|
| **UP / DOWN** | Move cursor |
| **LEFT / RIGHT** | Switch panels / adjust parameter in edit mode |
| **FIRE** | Add block / confirm edit |
| **F1** | Run the program |
| **F3** | Clear all blocks |
| **DEL** | Remove the selected block |
| **RESTORE** | Emergency stop (NMI handler) |

---

## Project Structure

```
/src
  constants.asm       — ZP variables, VIC-II/CIA/Kernal addresses, block/state IDs
  main.asm            — BASIC upstart, NMI handler, init, main loop, state machine
  ui_render.asm       — Screen-code drawing (panels, cursor, status bar)
  input.asm           — Joystick edge-detection + GETIN wrapper
  sprite_data.asm     — 64-byte robot sprite bitmap (64-byte aligned → ptr = 128)
  blocks_data.asm     — Block name strings, param types, default values
  codegen.asm         — Walk slots, emit 6502 opcodes to $5000, JSR $5000
  strings.asm         — UI strings (title, help row, value labels)
  program_store.asm   — 16-slot × 3-byte array + stride table + access helpers

/build               — Compiled .prg, .sym, test screenshots (git-ignored)
/bin                 — KickAss.jar
/docs                — index.html write-up + test_recording_vice.mp4
/scripts
  run_and_record.sh  — Run test suite + record desktop with ffmpeg
  session-timer.sh   — Pacing timer for AI-assisted development sessions
/skills              — Expert knowledge modules (for AI pair-programming)
```

### Memory map

| Address | Module |
|---|---|
| `$0801` | BASIC Upstart stub (`SYS 2066`) |
| `$0810` | `main.asm` — init, main loop, state machine |
| `$1000` | `ui_render.asm` |
| `$1800` | `input.asm` |
| `$2000` | `sprite_data.asm` (64-byte aligned; pointer byte = 128) |
| `$2800` | `blocks_data.asm` |
| `$3000` | `codegen.asm` |
| `$3800` | `strings.asm` |
| `$4000` | `program_store.asm` — slot array (16 slots × 3 bytes = 48 bytes) |
| `$5000` | *(runtime)* — generated machine-code buffer |

---

## Architecture

### State machine

```
STATE_PALETTE (0)    — UP/DN moves palette cursor; FIRE adds block; RIGHT → program panel
STATE_PROGRAM (1)    — UP/DN moves program cursor; FIRE → edit; LEFT → palette panel; F1 → run
STATE_EDIT_PARAM (2) — LEFT/RIGHT cycles param value; FIRE confirms and returns to program
STATE_RUNNING (3)    — transient; set during JSR $5000, cleared on return
```

### Slot array (`$4000`)

Each of the 16 slots is 3 bytes:

```
offset+0  block_type   (0–5, or $FF = empty)
offset+1  param_value  (colour, char code, seconds, etc.)
offset+2  (reserved / future use)
```

A pre-computed stride table (`slot_stride3_table`) converts a slot index 0–15 into the byte offset (0, 3, 6, … 45) so the codegen loop avoids a multiply.

### Code generation (`src/codegen.asm`)

`codegen_run` at `$3000`:

1. Points `zp_cg_ptr` at `$5000`
2. Emits `SEI` (`$78`) — disables IRQ during user code
3. Loops over slots 0 → `zp_slots_used - 1`:
   - Reads `block_type` (→ A) and `param_value` (→ Y)
   - Does an indirect jump via `jmp (zp_gen_lo)` into the matching emitter
4. Appends `CLI` (`$58`) + `RTS` (`$60`)
5. `JSR $5000` — runs it

Each emitter calls `emit_byte` once per opcode/operand byte. `emit_byte` stores A at `[zp_cg_ptr]` and increments the pointer.

**Key subtlety:** `emit_byte` uses `LDY #0` internally for its indirect store, clobbering Y. Emitters that need their param (passed in Y) must save it to ZP before the first `emit_byte` call:

```asm
emit_border:
    sty zp_gen_lo       ; save param — emit_byte clobbers Y via ldy #0
    lda #$A9            ; LDA immediate
    jsr emit_byte
    lda zp_gen_lo       ; restore param (the colour index)
    jsr emit_byte
    lda #$8D            ; STA absolute
    jsr emit_byte
    lda #$20            ; $D020 lo
    jsr emit_byte
    lda #$D0            ; $D020 hi
    jsr emit_byte
    jmp next_slot
; → 5 bytes emitted: A9 n 8D 20 D0  (LDA #n / STA $D020)
```

---

## Testing

The project has two complementary test levels.

### Level 1 — Headless smoke test (`test.sh`)

Assembles, runs VICE in warp mode for 100 M PAL cycles, captures a screenshot, and pixel-diffs it against a golden reference (0.5% tolerance).

```bash
bash test.sh            # compare to golden
bash test.sh --golden   # save new golden after intentional visual change
```

### Level 2 — Interactive test suite (`test_interactive.py`)

Launches VICE with the remote monitor enabled (`-remotemonitor`, port 6510), connects over TCP, and drives the full UI by writing joystick edges and key codes directly into zero-page variables — then reads hardware registers to assert correctness.

```bash
python test_interactive.py          # warp mode (fast)
python test_interactive.py --no-warp  # real C64 speed (use with run_and_record.sh)
```

**35 checks across 13 test groups:**

| # | Group | What's verified |
|---|---|---|
| 1 | Init | `zp_state = PALETTE`, `zp_pal_cursor = 0`, `zp_slots_used = 0` |
| 2 | Palette cursor | UP/DOWN moves cursor; wraps correctly |
| 3 | Add blocks | FIRE adds slot; `zp_slots_used` increments |
| 4 | Panel switch | RIGHT → program panel; LEFT → palette panel |
| 5 | SET BORDER codegen | `$D020` reads back correct colour after F1 |
| 6 | SET BG codegen | `$D021` reads back correct colour after F1 |
| 7 | Param editor | LEFT/RIGHT cycles value; FIRE commits to slot; re-run applies it |
| 8 | DEL | Removes mid-slot; remaining slots shift down correctly |
| 9 | SHOW SPRITE | `$D015` bit 0 set; `$D027` = colour 14; `$07F8` = 128; bitmap spot-check |
| 10 | LOOP BACK stop flag | `zp_stop_flag` is set by NMI, cleared by `do_run` |
| 11 | PRINT codegen | Exact bytes `78 A9 48 20 D2 FF 58 60` in buffer |
| 12 | WAIT codegen | SEI prefix; `outer_hi = n×3`; CLI/RTS at correct offsets |
| 13 | LOOP BACK execution | Break at `$5000`; inject stop-flag; tutor returns to PALETTE |

The harness injects input by writing to ZP via the VICE remote monitor:

```python
write_byte(s, 0x08, 0x02)   # zp_joy_edge: JOY_DOWN bit → cursor moves down
write_byte(s, 0x10, 0x85)   # zp_last_key: $85 = F1 → trigger codegen
```

After injection it polls `zp_state` until the main loop returns to idle, then reads hardware registers to assert the result.

### Recording a test run

```bash
bash scripts/run_and_record.sh
# → build/test_recording.mp4  (full-desktop fMP4)
```

The script uses `ffmpeg gdigrab` for capture and `-movflags frag_keyframe+empty_moov` so the file is valid even if ffmpeg is terminated without a graceful shutdown (no moov-atom-at-end required).

---

## KickAss Conventions

- **BASIC upstart:** `:BasicUpstart2(entry_label)` — never write the SYS line by hand.
- **File namespace:** `.filenamespace ModuleName` on every source file.
- **Program counter:** `.pc = $c000 "Label"` — the quoted label appears in the VICE monitor.
- **Local labels:** `!loop:` / `!+` inside subroutines to keep the global namespace clean.
- **Debug symbols:** Every build emits `build/main.sym`; load in VICE with `l "main.sym" 0`.
- **Assemble-time assertions:** `.assert "msg", addr, expected` catches page-boundary and overlap bugs.

### Known KickAss v5.25 gotchas

- No `:` statement separator — each instruction on its own line.
- `asl a` is not valid syntax — use bare `asl` for accumulator shift.
- `dec a` / `inc a` don't exist on 6502 — use `sec/sbc #1` or `clc/adc #1`.
- Long branches (emitter bodies > ±127 bytes) — use `bne !skip+ : jmp target` or a ZP jump table.
- Sprite data must be **exactly 64 bytes** (21 rows × 3 = 63, plus 1 padding byte).
- Cross-file constants must live in `constants.asm`, not inside a namespaced file.

---

## Known Gaps / Future Work

- **WAIT timing test:** a real-time test that measures wall-clock duration of the generated busy-loop and verifies it runs within ±10% of N seconds (requires `--no-warp` and `time.sleep` in the harness).
- **More blocks:** `SET COLOR` (text colour via colour RAM), `PLAY NOTE` (SID register writes), `CLEAR SCREEN`.
- **Save/load:** Persist slot arrays to a `.d64` disk image via the Kernal `OPEN/SAVE` routines.
- **Joystick port 1:** Currently reads port 2 only (`$DC00`); add port 1 (`$DC01`) as an alternative.

---

## Toolchain Summary

| Tool | Role |
|---|---|
| **KickAss v5.25** (`bin/KickAss.jar`) | Assembler — macros, scripting, `.sym` output |
| **VICE x64sc** | Cycle-accurate PAL C64 emulator |
| **ffmpeg** (gdigrab) | Screen recording for test runs |
| **Python 3** + TCP socket | Interactive test harness via VICE remote monitor |
| **PowerShell** | Pixel-diff comparison in `test.sh` |
