 Assembly View Toggle - v2.0 Feature Plan                                       
                                                        
 Context

 The C64 Block Tutor currently provides a visual block-based programming
 experience where users create programs by assembling blocks (SET BORDER, SET
 BG, PRINT, SHOW SPRITE, WAIT, LOOP BACK). Behind the scenes, a dynamic code
 generator at $3000 translates these blocks into 6502 machine code at $5000 and
  executes it with JSR $5000.

 The Problem: Users see their blocks and the results, but never see the
 assembly code or understand how their blocks translate to machine-level
 instructions. This hides the core learning objective - understanding 6502
 assembly.

 The Solution: Add a toggle feature (T key) that switches between:
 1. Block View (existing) - visual programming interface
 2. Assembly View (new) - full-screen disassembly with debugger-like stepping

 This creates the complete learning experience: users start with blocks, then
 peek behind the curtain to see real assembly code executing
 instruction-by-instruction.

 ---
 Implementation Approach

 1. Metadata Collection System

 Strategy: During code generation, build a parallel metadata array that tracks
 each generated instruction.

 Data Structure ($6000, 480 bytes):
 Each entry = 6 bytes:
   byte 0: mnemonic_id (enum: LDA_IMM=0, STA_ABS=1, etc.)
   byte 1: operand_byte_1
   byte 2: operand_byte_2
   byte 3: operand_length (0-2)
   byte 4: source_block_idx (which block created this)
   byte 5: address_offset (offset from $5000)

 Modifications to codegen.asm:
 - Add emit_instruction_meta() helper called by each emitter
 - Track total instruction count in zp_asm_inst_count
 - Emitters annotate their output (one call per logical instruction)

 ---
 2. State Machine Extension

 New States:
 - STATE_ASM_VIEW (4) - viewing disassembly, scrolling, can press S to step
 - STATE_ASM_STEPPING (5) - single-stepping through code with live register
 display

 New ZP Variables ($12-$1A, 9 bytes):
 zp_asm_cursor      = $12   // current line in view (0-79)
 zp_asm_pc          = $13   // program counter (16-bit)
 zp_asm_pc_hi       = $14
 zp_asm_inst_count  = $15   // total instructions
 zp_asm_reg_a       = $16   // shadow registers
 zp_asm_reg_x       = $17
 zp_asm_reg_y       = $18
 zp_asm_reg_sp      = $19
 zp_asm_reg_flags   = $1A
 zp_asm_prev_state  = $1B   // state before entering asm view

 T-Key Handler: Add to all existing states (PALETTE, PROGRAM, EDIT_PARAM) to
 enter STATE_ASM_VIEW

 ---
 3. Screen Layout (40×25)

 Row 0:    ASSEMBLY VIEW  [F1:RUN T:BLOCKS]
 Row 1:    ADDR  OPCODE MNEMONIC    OPERAND
 Row 2-18: >5000  78     SEI                      (17 lines of code)
           5001  A9 06  LDA        #$06          (cursor = green bg)
           5003  8D 20  STA        $D020         (VIC write = cyan)
           ...
 Row 19:   A:06 X:00 Y:48 SP:FF [NV-BDIZC]
 Row 20:   BLOCK #1: SET BORDER (CYAN)
 Row 21:   UP/DN:SCROLL S:STEP F1:RUN T:EXIT
 Row 22-24: STATUS: READY

 Syntax Highlighting Colors:
 - Cursor line: green background ($05)
 - VIC I/O writes: cyan text ($03)
 - Kernal calls: yellow text ($07)
 - Control flow: red text ($02)
 - System (SEI/CLI): purple text ($04)
 - Default: light grey ($0F)

 ---
 4. Single-Step Execution

 Strategy: Instruction-level interpretation (NOT re-execution)

 How it works:
 1. User presses S key → enters STATE_ASM_STEPPING
 2. On each step (FIRE or S key):
   - Read metadata[zp_asm_cursor]
   - Dispatch to mnemonic handler (jump table)
   - Handler updates shadow registers (zp_asm_reg_*)
   - For VIC writes: actually write to hardware ($D020, etc.)
   - For CPU-only ops: just update shadows
   - Increment cursor, render screen, play beep
 3. At RTS: stop stepping, return to view mode

 Opcode Handlers Needed (only for instructions our emitters generate):
 - LDA #n, LDA abs
 - STA abs, STA zp
 - LDX #n, LDY #n
 - DEX, DEC abs, BNE rel
 - JSR abs (special: summarize or skip)
 - SEI, CLI, RTS

 Sound Effects:
 - Step forward: SID tone at $D400/$D401, gate on/off at $D404
 - Different pitches for different instruction types
 - Completion chime at RTS

 ---
 5. Memory Allocation
 ┌─────────┬───────────┬──────────────────────────────────────────────┐
 │ Address │   Size    │                   Purpose                    │
 ├─────────┼───────────┼──────────────────────────────────────────────┤
 │ $6000   │ 480 bytes │ Metadata buffer (80 instructions × 6 bytes)  │
 ├─────────┼───────────┼──────────────────────────────────────────────┤
 │ $6800   │ ~2KB      │ asm_view.asm - rendering & stepping engine   │
 ├─────────┼───────────┼──────────────────────────────────────────────┤
 │ $7000   │ ~1KB      │ asm_strings.asm - mnemonic strings & helpers │
 └─────────┴───────────┴──────────────────────────────────────────────┘
 Total footprint: ~3.5KB (fits comfortably below BASIC ROM at $A000)

 ---
 Implementation Phases

 Phase 1: Metadata Foundation

 Files: constants.asm, codegen.asm

 1. Add ZP variables ($12-$1B)
 2. Add metadata buffer address constant (ASM_META_BUF = $6000)
 3. Add state constants (STATE_ASM_VIEW, STATE_ASM_STEPPING)
 4. Modify codegen.asm:
   - Add emit_instruction_meta() subroutine
   - Modify each emitter (emit_border, emit_bg, etc.) to call it
   - Initialize zp_asm_inst_count = 0 at start of codegen_run
 5. Test: Assemble, run F1, use VICE monitor to inspect $6000 and verify
 metadata

 ---
 Phase 2: Static Assembly View

 Files: Create asm_view.asm, asm_strings.asm; modify main.asm

 1. Create asm_view.asm at .pc = $6800:
   - asm_view_render() - clear screen, draw title/header
   - asm_view_render_code_area() - render 17 lines of disassembly from metadata
   - asm_view_render_registers() - display A/X/Y/SP/PC/flags
   - asm_view_render_help() - key hints on row 21
 2. Create asm_strings.asm at .pc = $7000:
   - Mnemonic lookup table (30 strings: "SEI", "LDA", "STA", etc.)
   - Hex-to-screen-code conversion helpers
 3. Modify main.asm:
   - Add T-key check in state_palette, state_program, state_edit_param
   - Save current state to zp_asm_prev_state
   - Switch to STATE_ASM_VIEW, call asm_view_render()
   - Add state_asm_view handler:
       - UP/DOWN: scroll through disassembly
     - T: return to previous state
     - F1: re-run code
 4. Test: Press T after creating blocks → see full-screen assembly view

 ---
 Phase 3: Syntax Highlighting

 Files: asm_view.asm

 1. Add color table indexed by mnemonic category
 2. Modify asm_view_render_code_area():
   - Apply color to COLOR_RAM based on mnemonic type
   - Highlight cursor line with green background
   - Cyan for VIC writes, yellow for Kernal calls, etc.
 3. Test: Assembly view shows colorful, readable code

 ---
 Phase 4: Step-Through Execution

 Files: asm_view.asm

 1. Implement asm_step_init():
   - Reset shadow registers: A=0, X=0, Y=0, SP=$FF, flags=0
   - Set cursor to first instruction
   - Clear hardware state (border=black, etc.)
 2. Implement asm_step_execute_one():
   - Read metadata at cursor position
   - Dispatch via jump table to mnemonic handler
   - Handler updates shadows + writes hardware if needed
   - Increment cursor
 3. Create step handlers:
   - step_lda_imm, step_sta_abs, step_sei, step_cli, step_rts
   - For WAIT block loops: special handler that summarizes "LOOP 3 TIMES"
 4. Modify main.asm:
   - Add S-key check in state_asm_view → enter STATE_ASM_STEPPING
   - Add state_asm_stepping handler:
       - FIRE or S: call asm_step_execute_one(), render screen
     - T: return to view mode
 5. Implement asm_step_beep(): write SID registers for short tone
 6. Test: Press S in assembly view → step through code with live register
 updates

 ---
 Phase 5: Block Annotations

 Files: asm_view.asm

 1. Add row 20 renderer: "BLOCK #N:  ()"
 2. Read metadata[cursor].source_block_idx
 3. Lookup block name from blocks_data.asm
 4. Update on cursor movement
 5. Test: Each instruction shows originating block

 ---
 Phase 6: Polish & Sound

 Files: asm_view.asm

 1. Refine SID beep tones:
   - Ascending pitch on each step
   - Lower boop on VIC writes
   - Completion chime at RTS
 2. Add screen transition (fast clear+render)
 3. Add help text animations (blink cursor on S-key hint)
 4. Test: Pleasant audio-visual feedback during stepping

 ---
 Critical Files

 Modified:
 - /src/constants.asm - new ZP vars, states, memory addresses
 - /src/codegen.asm - metadata tracking in all 6 emitters
 - /src/main.asm - T-key handlers, new state handlers

 Created:
 - /src/asm_view.asm - rendering & stepping engine (~2KB)
 - /src/asm_strings.asm - mnemonic strings & utilities (~1KB)

 ---
 Verification Steps

 After each phase:
 1. Assemble: java -jar bin/KickAss.jar src/main.asm -o build/main.prg
 -symbolfile
 2. Run in VICE: x64sc build/main.prg
 3. Manual test:
   - Create a program with 3-4 blocks
   - Press F1 to run
   - Press T to enter assembly view
   - Verify disassembly is accurate (compare with VICE monitor disass 5000)
   - Press S to step through
   - Verify registers update correctly
   - Press T to return to block view
 4. Automated test: bash test.sh (golden screenshot should show block view, not
  asm view)

 ---
 Risk Mitigation

 High Risk: Step execution correctness
 - Start with minimal opcode set (LDA/STA only)
 - Expand incrementally
 - Compare shadow registers vs. VICE monitor after real execution

 Medium Risk: Metadata sync
 - Add .assert checks in codegen
 - Verify metadata count matches generated code size
 - Test with all 16 slots filled

 Low Risk: Screen flicker
 - Use fast clear+render (acceptable on C64)
 - No double-buffering needed (not in critical path)

 ---
 Success Criteria

 - T key toggles between block view and assembly view
 - Assembly view shows accurate disassembly with syntax highlighting
 - S key enables single-step mode with live register display
 - Sound effects play on each step
 - Each instruction shows which block created it
 - User can learn assembly by seeing blocks → code → execution

