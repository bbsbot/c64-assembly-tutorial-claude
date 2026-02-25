# Plan: Matrix Rain Transition Effect

## Context

When pressing T to enter ASM View, the transition is currently instant (clear + render). We're replacing this with a "Matrix Rain" animation: assembly code characters rain down column by column with random intermediate characters, accompanied by a descending SID tone. The screen ends up in the exact same final state as before.

## Memory Layout

| Address | Size | Purpose |
|---------|------|---------|
| `$6200` | 1000 bytes | Shadow screen buffer (pre-rendered ASM view) |
| `$65E8` | 160 bytes | Per-column rain state (40 cols × 4 bytes) |
| `$7800` | ~700 bytes | `matrix_rain.asm` code + tables |
| `$1C-$1D` | 2 bytes ZP | `zp_rain_active` (columns remaining), `zp_rain_freq_hi` (SID sweep) |

## Algorithm

1. **Blank screen** (`$D011` bit 4 off) to hide pre-render
2. **Call `asm_view_render`** normally — target appears in SCREEN_RAM
3. **Copy** SCREEN_RAM → shadow buffer (1000 bytes)
4. **Clear** SCREEN_RAM, **unblank** screen
5. **Init** 40-column state table with staggered delays (left-to-right wave + random jitter)
6. **Init SID** voice 2 — sawtooth descending sweep
7. **Frame loop** (raster-synced, ~90 frames / 1.8 sec):
   - For each column: advance rain head down rows, show 2-3 random chars per cell before settling to the shadow buffer's final character
   - Color: white head → light green trail → green fade
   - Decrement SID frequency each frame
8. **Finalize:** Apply syntax colors (call `colorize_code_area` + color routines), silence SID

## Files

| File | Action | Changes |
|------|--------|---------|
| `src/constants.asm` | Modify | Add `SHADOW_SCREEN=$6200`, `RAIN_COL_STATE=$65E8`, `zp_rain_active=$1C`, `zp_rain_freq_hi=$1D` |
| `src/matrix_rain.asm` | **Create** | Rain transition routine (~700 bytes at `$7800`) |
| `src/main.asm` | Modify | Add `#import "matrix_rain.asm"`, update memory map comment, change 3 T-key entry points from `jsr AsmView.asm_view_render` → `jsr MatrixRain.matrix_rain_transition` |

## Verification

1. Assemble with 0 errors
2. `bash test.sh` — existing golden test must still pass
3. Manual VICE test: press T → observe rain effect with sound → press T to return → verify clean round-trip
