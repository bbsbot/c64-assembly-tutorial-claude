# Phase 4: Step-Through Execution — Implementation Plan

## Context

The Assembly View (Phases 1-3) lets users toggle to a full-screen disassembly of their program with syntax highlighting. Phase 4 adds the "wow factor" — pressing S enters stepping mode where each keypress executes one instruction, updating shadow registers and writing to VIC hardware in real time. This turns the tutor into a visual debugger.

## Space Budget

| Segment | Used | Free | Notes |
|---------|------|------|-------|
| AsmView ($6800–$6FFF) | ~992 bytes | ~1056 bytes | Plenty for stepping logic |
| AsmStrings ($7000–$73FF) | ~192 bytes | ~832 bytes | Room for helper strings |
| ZP ($02–$1B) | Full | 0 | Use existing shadow regs; scratch via $FE/$FF |

## Bug Fix (Pre-requisite)

**`render_code_area` padding bug** at `src/asm_view.asm:213-227`: Y register is not reset to 0 before the fill loop, and the loop counts down with `dey` instead of up to 40. Fix: initialize Y=0, fill 40 bytes per line with `iny`/`cpy #40`.

## Implementation Steps

### Step 1: Fix padding bug in `asm_view.asm`
### Step 2: Add `asm_step_init` routine
### Step 3: Add `asm_step_execute_one` routine with dispatch
### Step 4: Implement 15 step handlers
### Step 5: Add SID beep
### Step 6: Implement flag rendering
### Step 7: Add STATE_ASM_STEPPING handler in main.asm
### Step 8: Add S-key handler in state_asm_view

## Files Modified

| File | Changes |
|------|---------|
| `src/asm_view.asm` | Fix padding bug, add stepping engine, handlers, beep, flags |
| `src/main.asm` | Add STATE_ASM_STEPPING dispatch + handler, S-key |
