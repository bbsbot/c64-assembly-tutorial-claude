#!/usr/bin/env python3
"""
test_interactive.py — Automated interactive test for C64 Block Tutor

Uses VICE's text remote monitor (port 6510) with breakpoints to inject
joystick/keyboard input AFTER input_read_joystick has already run, so
writes to zp_joy_edge are not overwritten by the hardware poll.

Strategy:
  - Breakpoint at state_palette / state_program / state_edit_param
  - When breakpoint fires (VICE pauses), write zp_joy_edge or zp_last_key
  - Continue; handler processes the input; next breakpoint verifies result

Tests:
  1.  Init state
  2.  Palette cursor UP/DOWN
  3.  Add blocks via FIRE
  4.  Panel switch LEFT/RIGHT
  5.  F1 codegen — verify $D020 (border) changes
  6.  F1 codegen — verify $D021 (background) changes
  7.  Param editor — enter edit, cycle value, confirm, read slot array
  8.  DEL key — removes block, shifts slot array
  9.  SHOW SPRITE codegen — $D015 bit 0 set, $D000/$D001 = X/Y
  10. LOOP BACK stop flag read/write

Usage:   python test_interactive.py
Env:     VICE=path/to/x64sc.exe   MONITOR_PORT=6510
"""

import io, os, re, socket, subprocess, sys, time

WARP = "--no-warp" not in sys.argv
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

# ── Config ────────────────────────────────────────────────────────────────────

def _find_vice():
    for c in [os.environ.get("VICE",""), r"C:\tools\vice\bin\x64sc.exe", "x64sc"]:
        if not c: continue
        c = re.sub(r"^/([a-zA-Z])/", lambda m: m.group(1).upper()+":\\", c).replace("/","\\")
        if os.path.isfile(c) or "\\" not in c: return c
    return "x64sc"

VICE    = _find_vice()
ROOT    = os.path.dirname(os.path.abspath(__file__))
PRG     = os.path.join(ROOT, "build", "main.prg")
PORT    = int(os.environ.get("MONITOR_PORT", "6510"))
LOGFILE = os.path.join(ROOT, "build", "test_interactive.log")

# ZP addresses (from constants.asm)
ZP_STATE      = 0x02;  ZP_PAL_CURSOR = 0x03;  ZP_PGM_CURSOR = 0x04
ZP_SLOTS_USED = 0x05;  ZP_JOY_EDGE   = 0x08;  ZP_EDIT_VAL   = 0x09
ZP_EDIT_SLOT  = 0x0A;  ZP_LAST_KEY   = 0x10;  ZP_STOP_FLAG  = 0x11

# Hardware registers
VIC_BORDER    = 0xD020   # border colour
VIC_BG        = 0xD021   # background colour
VIC_SPR_ENA   = 0xD015   # sprite enable bits
VIC_SPR0_X    = 0xD000   # sprite 0 X
VIC_SPR0_Y    = 0xD001   # sprite 0 Y
VIC_SPR0_COL  = 0xD027   # sprite 0 colour
SPRITE0_PTR   = 0x07F8   # sprite 0 data pointer ($2000/64 = 128)
SPRITE0_DATA  = 0x2000   # sprite 0 bitmap (64 bytes)

SLOT_ARRAY    = 0x4000   # 16 slots x 3 bytes
GEN_CODE_BUF  = 0x5000   # generated machine code buffer

JOY_UP=0x01; JOY_DOWN=0x02; JOY_LEFT=0x04; JOY_RIGHT=0x08; JOY_FIRE=0x10
STATE_PALETTE=0; STATE_PROGRAM=1; STATE_EDIT_PARAM=2; STATE_RUNNING=3

# Addresses from build/main.sym
MAIN_LOOP_ADDR       = 0x0880
STATE_PALETTE_ADDR   = 0x08A9
STATE_PROGRAM_ADDR   = 0x091F
STATE_EDIT_ADDR      = 0x09AB

PASS=0; FAIL=0

def ok(msg):  global PASS; PASS+=1; print(f"  OK  {msg}")
def err(msg): global FAIL; FAIL+=1; print(f"  ERR {msg}")

# ── Monitor comms ─────────────────────────────────────────────────────────────

def connect(retries=30):
    for _ in range(retries):
        try:
            s = socket.socket(); s.connect(("127.0.0.1", PORT)); s.settimeout(0.5)
            time.sleep(0.4); _drain(s); return s
        except (ConnectionRefusedError, OSError): time.sleep(0.4)
    raise RuntimeError(f"Cannot connect to VICE monitor on port {PORT}")

def _drain(s):
    buf = b""
    try:
        while True: buf += s.recv(4096)
    except socket.timeout: pass
    return buf.decode(errors="replace")

def _send(s, line): s.sendall((line+"\n").encode())

def _wait_for_prompt(s, timeout=20):
    buf = b""; deadline = time.time()+timeout; s.settimeout(0.3)
    while time.time() < deadline:
        try:
            chunk = s.recv(4096)
            if chunk: buf += chunk
        except socket.timeout: pass
        if re.search(rb"\(C:\$[0-9a-fA-F]{4}\)", buf): return buf.decode(errors="replace")
    return buf.decode(errors="replace")

def cmd(s, line, wait=0.15):
    _send(s, line); time.sleep(wait); return _drain(s)

def read_byte(s, addr):
    resp = cmd(s, f"m {addr:04x} {addr:04x}", wait=0.2)
    m = re.search(rf"{addr:04x}\s+([0-9a-fA-F]{{2}})", resp, re.IGNORECASE)
    return int(m.group(1), 16) if m else None

def write_byte(s, addr, val): cmd(s, f"> {addr:04x} {val:02x}", wait=0.1)

def run_and_break(s, timeout=20):
    _send(s, "g"); return _wait_for_prompt(s, timeout)

# ── Input injection ───────────────────────────────────────────────────────────

def at_state(s, handler_addr, joy_bit=None, last_key=None):
    """Set breakpoint, run until handler fires (VICE paused), optionally inject input."""
    cmd(s, f"bk {handler_addr:04x}", wait=0.05)
    run_and_break(s)
    cmd(s, "del", wait=0.05)
    if joy_bit  is not None: write_byte(s, ZP_JOY_EDGE, joy_bit)
    if last_key is not None: write_byte(s, ZP_LAST_KEY, last_key)

def palette_press(s, joy_bit):
    """Inject joy_bit at state_palette, advance one full frame, return at next handler."""
    write_byte(s, ZP_JOY_EDGE, joy_bit)
    at_state(s, STATE_PALETTE_ADDR)

def program_press(s, joy_bit=None, last_key=None):
    """Inject input at state_program handler, advance one frame."""
    write_byte(s, ZP_JOY_EDGE, joy_bit or 0)
    if last_key: write_byte(s, ZP_LAST_KEY, last_key)
    at_state(s, STATE_PROGRAM_ADDR)

def clear_all_blocks(s):
    """F3 from palette to clear program."""
    write_byte(s, ZP_LAST_KEY, 0x86)   # F3
    at_state(s, STATE_PALETTE_ADDR)

# ── Test helpers ──────────────────────────────────────────────────────────────

def add_block_at_cursor(s, pal_index):
    """Move palette cursor to pal_index and FIRE to add block."""
    cur = read_byte(s, ZP_PAL_CURSOR)
    while cur != pal_index:
        if cur < pal_index:
            palette_press(s, JOY_DOWN); cur += 1
        else:
            palette_press(s, JOY_UP);  cur -= 1
    palette_press(s, JOY_FIRE)

def run_program(s):
    """F1 from palette, wait for program to execute and return to PALETTE."""
    write_byte(s, ZP_LAST_KEY, 0x85)   # F1
    # Run until we're back in STATE_PALETTE (do_run returns after JSR $5000)
    # Use a generous timeout — WAIT blocks need real time in warp
    at_state(s, STATE_PALETTE_ADDR, timeout_override=30)

def at_state(s, handler_addr, joy_bit=None, last_key=None, timeout_override=20):
    cmd(s, f"bk {handler_addr:04x}", wait=0.05)
    run_and_break(s, timeout=timeout_override)
    cmd(s, "del", wait=0.05)
    if joy_bit  is not None: write_byte(s, ZP_JOY_EDGE, joy_bit)
    if last_key is not None: write_byte(s, ZP_LAST_KEY, last_key)

# ── Tests ─────────────────────────────────────────────────────────────────────

def run_tests(s):

    # ── 1. Init ───────────────────────────────────────────────────────────────
    print("\n[1] Init...")
    cmd(s, f"bk {MAIN_LOOP_ADDR:04x}", wait=0.05)
    run_and_break(s, timeout=20); cmd(s, "del", wait=0.05)
    at_state(s, STATE_PALETTE_ADDR)   # advance to first handler entry

    st = read_byte(s, ZP_STATE); pal = read_byte(s, ZP_PAL_CURSOR)
    used = read_byte(s, ZP_SLOTS_USED)
    if st == STATE_PALETTE: ok(f"init: state=PALETTE({st})")
    else: err(f"init: bad state {st}")
    if pal == 0 and used == 0: ok(f"init: pal_cursor={pal} slots_used={used}")
    else: err(f"init: pal_cursor={pal} slots_used={used}")

    # ── 2. Palette cursor ─────────────────────────────────────────────────────
    print("\n[2] Palette cursor...")
    palette_press(s, JOY_DOWN)
    pal = read_byte(s, ZP_PAL_CURSOR)
    if pal == 1: ok(f"DOWN: pal_cursor={pal}")
    else: err(f"DOWN: pal_cursor={pal} (expected 1)")

    palette_press(s, JOY_DOWN)
    pal = read_byte(s, ZP_PAL_CURSOR)
    if pal == 2: ok(f"DOWN x2: pal_cursor={pal}")
    else: err(f"DOWN x2: pal_cursor={pal} (expected 2)")

    palette_press(s, JOY_UP)
    pal = read_byte(s, ZP_PAL_CURSOR)
    if pal == 1: ok(f"UP: pal_cursor={pal}")
    else: err(f"UP: pal_cursor={pal} (expected 1)")

    # back to top
    palette_press(s, JOY_UP)

    # ── 3. Add blocks ─────────────────────────────────────────────────────────
    print("\n[3] Add blocks (FIRE)...")
    palette_press(s, JOY_FIRE)   # add SET BORDER (block 0)
    used = read_byte(s, ZP_SLOTS_USED)
    if used == 1: ok(f"FIRE adds block: slots_used={used}")
    else: err(f"FIRE add failed: slots_used={used}")

    palette_press(s, JOY_FIRE)   # add second SET BORDER
    used = read_byte(s, ZP_SLOTS_USED)
    if used == 2: ok(f"second block: slots_used={used}")
    else: err(f"second add: slots_used={used}")

    # ── 4. Panel switch ───────────────────────────────────────────────────────
    print("\n[4] Panel switch...")
    palette_press(s, JOY_RIGHT)
    at_state(s, STATE_PROGRAM_ADDR)   # now in program panel
    st = read_byte(s, ZP_STATE)
    if st == STATE_PROGRAM: ok(f"RIGHT -> program: state={st}")
    else: err(f"RIGHT failed: state={st}")

    at_state(s, STATE_PROGRAM_ADDR, joy_bit=JOY_LEFT)
    at_state(s, STATE_PALETTE_ADDR)
    st = read_byte(s, ZP_STATE)
    if st == STATE_PALETTE: ok(f"LEFT -> palette: state={st}")
    else: err(f"LEFT failed: state={st}")

    # ── 5. Codegen: SET BORDER changes $D020 ─────────────────────────────────
    print("\n[5] Codegen: SET BORDER ($D020)...")
    clear_all_blocks(s)

    # Add SET BORDER (block 0, default param = color 0 = BLACK)
    add_block_at_cursor(s, 0)    # ensure cursor=0, add SET BORDER
    used = read_byte(s, ZP_SLOTS_USED)
    if used != 1: err(f"setup: slots_used={used} (expected 1)"); return

    # Set border to a known non-zero value first so we can detect change
    write_byte(s, VIC_BORDER, 0x0E)   # light blue — unlikely to be default

    # F1 to run
    write_byte(s, ZP_LAST_KEY, 0x85)
    at_state(s, STATE_PALETTE_ADDR, timeout_override=15)

    border_after = read_byte(s, VIC_BORDER)
    # VIC-II color registers always read back as $Fx — mask to lower nibble
    if border_after & 0x0F == 0x00:
        ok(f"SET BORDER: $D020={border_after:#04x} -> color 0 (black)")
    else:
        err(f"SET BORDER: $D020={border_after:#04x} (expected color 0=black, got {border_after & 0x0F})")

    # ── 6. Codegen: SET BG changes $D021 ─────────────────────────────────────
    print("\n[6] Codegen: SET BG ($D021)...")
    clear_all_blocks(s)

    # Navigate to SET BG (block 1)
    add_block_at_cursor(s, 1)   # block 1 = SET BG, default = 5 (green)
    used = read_byte(s, ZP_SLOTS_USED)
    if used != 1: err(f"setup: slots_used={used}"); return

    write_byte(s, VIC_BG, 0x0E)   # set bg to light blue so change is detectable
    write_byte(s, ZP_LAST_KEY, 0x85)
    at_state(s, STATE_PALETTE_ADDR, timeout_override=15)

    bg_after = read_byte(s, VIC_BG)
    # VIC-II color registers always read back as $Fx — mask to lower nibble
    if bg_after & 0x0F == 0x05:
        ok(f"SET BG: $D021={bg_after:#04x} -> color 5 (green)")
    else:
        err(f"SET BG: $D021={bg_after:#04x} (expected color 5=green, got {bg_after & 0x0F})")

    # ── 7. Param editor ───────────────────────────────────────────────────────
    print("\n[7] Param editor...")
    clear_all_blocks(s)

    # Add SET BORDER (block 0, default color=0=black)
    add_block_at_cursor(s, 0)    # ensure cursor=0 before FIRE

    # Switch to program panel
    palette_press(s, JOY_RIGHT)
    at_state(s, STATE_PROGRAM_ADDR)

    # FIRE to enter edit mode
    at_state(s, STATE_PROGRAM_ADDR, joy_bit=JOY_FIRE)
    at_state(s, STATE_EDIT_ADDR)   # now in STATE_EDIT_PARAM

    st = read_byte(s, ZP_STATE)
    if st == STATE_EDIT_PARAM: ok(f"enter edit: state={st}")
    else: err(f"enter edit: state={st} (expected {STATE_EDIT_PARAM})")

    edit_val_before = read_byte(s, ZP_EDIT_VAL)

    # RIGHT to increment color (0 -> 1)
    write_byte(s, ZP_JOY_EDGE, JOY_RIGHT)
    at_state(s, STATE_EDIT_ADDR)
    edit_val = read_byte(s, ZP_EDIT_VAL)
    if edit_val == edit_val_before + 1:
        ok(f"RIGHT increments: zp_edit_val {edit_val_before} -> {edit_val}")
    else:
        err(f"RIGHT: zp_edit_val={edit_val} (expected {edit_val_before+1})")

    # RIGHT again (1 -> 2)
    write_byte(s, ZP_JOY_EDGE, JOY_RIGHT)
    at_state(s, STATE_EDIT_ADDR)
    edit_val = read_byte(s, ZP_EDIT_VAL)
    expected = min(edit_val_before + 2, 15)
    if edit_val == expected:
        ok(f"RIGHT x2: zp_edit_val={edit_val}")
    else:
        err(f"RIGHT x2: zp_edit_val={edit_val} (expected {expected})")

    # FIRE to confirm
    write_byte(s, ZP_JOY_EDGE, JOY_FIRE)
    at_state(s, STATE_PROGRAM_ADDR)   # returns to program state

    # Read slot 0's param byte (offset 1 in 3-byte slot)
    slot0_param = read_byte(s, SLOT_ARRAY + 1)
    if slot0_param == edit_val:
        ok(f"FIRE confirms: slot_array[0].param={slot0_param:#04x}")
    else:
        err(f"FIRE confirm: slot param={slot0_param:#04x} (expected {edit_val:#04x})")

    # Now run — border should be set to the new color
    at_state(s, STATE_PROGRAM_ADDR, joy_bit=JOY_LEFT)   # back to palette
    at_state(s, STATE_PALETTE_ADDR)

    write_byte(s, VIC_BORDER, 0x00)   # reset border
    write_byte(s, ZP_LAST_KEY, 0x85)
    at_state(s, STATE_PALETTE_ADDR, timeout_override=15)

    border = read_byte(s, VIC_BORDER)
    # VIC-II color registers always read back as $Fx — mask to lower nibble
    if border & 0x0F == slot0_param:
        ok(f"run with edited param: $D020={border:#04x} -> color {slot0_param} (correct)")
    else:
        err(f"run with edited param: $D020={border:#04x} (expected color {slot0_param})")

    # ── 8. DEL removes block ──────────────────────────────────────────────────
    print("\n[8] DEL removes block...")
    clear_all_blocks(s)

    # Add 3 blocks: SET BORDER(0), SET BG(1), PRINT(2)
    add_block_at_cursor(s, 0)    # slot 0: SET BORDER (explicit cursor=0)
    add_block_at_cursor(s, 1)    # slot 1: SET BG
    add_block_at_cursor(s, 2)    # slot 2: PRINT

    used = read_byte(s, ZP_SLOTS_USED)
    if used == 3: ok(f"setup: 3 blocks added")
    else: err(f"setup: slots_used={used} (expected 3)")

    # Switch to program panel, navigate to slot 1 (middle)
    palette_press(s, JOY_RIGHT)
    at_state(s, STATE_PROGRAM_ADDR)
    write_byte(s, ZP_JOY_EDGE, JOY_DOWN)
    at_state(s, STATE_PROGRAM_ADDR)   # cursor now at slot 1

    pgm_cur = read_byte(s, ZP_PGM_CURSOR)
    if pgm_cur == 1: ok(f"cursor at slot 1")
    else: err(f"cursor={pgm_cur} (expected 1)")

    # DEL
    write_byte(s, ZP_LAST_KEY, 0x14)   # DEL PETSCII
    at_state(s, STATE_PROGRAM_ADDR)

    used = read_byte(s, ZP_SLOTS_USED)
    slot0_type = read_byte(s, SLOT_ARRAY)       # should still be SET BORDER (0)
    slot1_type = read_byte(s, SLOT_ARRAY + 3)   # should now be PRINT (2, shifted down)
    if used == 2: ok(f"DEL: slots_used={used}")
    else: err(f"DEL: slots_used={used} (expected 2)")
    if slot0_type == 0: ok(f"DEL: slot 0 still SET BORDER ({slot0_type})")
    else: err(f"DEL: slot 0 type={slot0_type} (expected 0=SET BORDER)")
    if slot1_type == 2: ok(f"DEL: slot 1 shifted to PRINT ({slot1_type})")
    else: err(f"DEL: slot 1 type={slot1_type} (expected 2=PRINT)")

    # ── 9. SHOW SPRITE sets $D015/$D000/$D001 ────────────────────────────────
    print("\n[9] SHOW SPRITE codegen...")
    # Switch back to palette first
    at_state(s, STATE_PROGRAM_ADDR, joy_bit=JOY_LEFT)
    at_state(s, STATE_PALETTE_ADDR)
    clear_all_blocks(s)

    # Navigate to SHOW SPRITE (block 3)
    add_block_at_cursor(s, 3)
    used = read_byte(s, ZP_SLOTS_USED)
    if used != 1: err(f"setup: slots_used={used}"); return

    # Clear sprite registers first
    write_byte(s, VIC_SPR_ENA, 0x00)
    write_byte(s, VIC_SPR0_X, 0x00)
    write_byte(s, VIC_SPR0_Y, 0x00)

    write_byte(s, ZP_LAST_KEY, 0x85)   # F1
    at_state(s, STATE_PALETTE_ADDR, timeout_override=15)

    spr_ena = read_byte(s, VIC_SPR_ENA)
    spr_x   = read_byte(s, VIC_SPR0_X)
    spr_y   = read_byte(s, VIC_SPR0_Y)
    if spr_ena & 0x01: ok(f"SHOW SPRITE: $D015={spr_ena:#04x} (sprite 0 enabled)")
    else: err(f"SHOW SPRITE: $D015={spr_ena:#04x} (bit 0 not set)")
    if spr_x == 150: ok(f"SHOW SPRITE: $D000=150 (X correct)")
    else: err(f"SHOW SPRITE: $D000={spr_x} (expected 150)")
    if spr_y == 130: ok(f"SHOW SPRITE: $D001=130 (Y correct)")
    else: err(f"SHOW SPRITE: $D001={spr_y} (expected 130)")

    # Sprite data pointer ($07F8 = 128 → points to $2000)
    spr_ptr = read_byte(s, SPRITE0_PTR)
    if spr_ptr == 128: ok(f"SHOW SPRITE: $07F8={spr_ptr} (pointer → $2000)")
    else: err(f"SHOW SPRITE: $07F8={spr_ptr} (expected 128)")

    # Sprite 0 colour ($D027 = 14 = light blue, set by emit_sprite)
    spr_col = read_byte(s, VIC_SPR0_COL)
    if spr_col & 0x0F == 14: ok(f"SHOW SPRITE: $D027={spr_col:#04x} (colour 14=light blue)")
    else: err(f"SHOW SPRITE: $D027={spr_col:#04x} (expected colour 14=light blue)")

    # Spot-check bitmap at $2000 — row 0 is head top: %00000000 %00111100 %00000000
    bm = [read_byte(s, SPRITE0_DATA + i) for i in range(3)]
    if bm == [0x00, 0x3C, 0x00]:
        ok(f"SPRITE bitmap row 0: {' '.join(f'{b:02x}' for b in bm)} (head top)")
    else:
        err(f"SPRITE bitmap row 0: {' '.join(f'{b:02x}' for b in bm)} (expected 00 3c 00)")

    # ── 10. LOOP BACK stop flag ───────────────────────────────────────────────
    print("\n[10] LOOP BACK stop flag...")
    write_byte(s, ZP_STOP_FLAG, 0xFF)
    val = read_byte(s, ZP_STOP_FLAG)
    if val == 0xFF: ok(f"stop flag set: {val:#04x}")
    else: err(f"stop flag set failed: {val}")
    write_byte(s, ZP_STOP_FLAG, 0x00)
    val = read_byte(s, ZP_STOP_FLAG)
    if val == 0x00: ok(f"stop flag cleared: {val:#04x}")
    else: err(f"stop flag clear failed: {val}")

    # ── 11. PRINT codegen ────────────────────────────────────────────────────
    print("\n[11] PRINT codegen...")
    clear_all_blocks(s)
    add_block_at_cursor(s, 2)   # block 2 = PRINT, default char $48 = 'H' PETSCII

    write_byte(s, ZP_LAST_KEY, 0x85)   # F1
    at_state(s, STATE_PALETTE_ADDR, timeout_override=10)

    # Expected: SEI, LDA #$48, JSR $FFD2, CLI, RTS
    expected = [0x78, 0xA9, 0x48, 0x20, 0xD2, 0xFF, 0x58, 0x60]
    actual   = [read_byte(s, GEN_CODE_BUF + i) for i in range(8)]
    if actual == expected:
        ok(f"PRINT codegen: {' '.join(f'{b:02x}' for b in actual)}")
    else:
        err(f"PRINT codegen: got {' '.join(f'{b:02x}' for b in actual)}, expected {' '.join(f'{b:02x}' for b in expected)}")

    # ── 12. WAIT codegen ─────────────────────────────────────────────────────
    print("\n[12] WAIT codegen...")
    clear_all_blocks(s)
    add_block_at_cursor(s, 4)   # block 4 = WAIT, default n=2

    write_byte(s, ZP_LAST_KEY, 0x85)   # F1 (warp: 2s wait completes immediately)
    at_state(s, STATE_PALETTE_ADDR, timeout_override=15)

    # Read full 24-byte generated program
    # Layout: [0]=SEI [1..20]=WAIT(n=2) [21]=CLI [22]=RTS
    # Wait code: A9 00 85 FE A9 <outer_hi> 85 FF A2 FF CA D0 FD C6 FE D0 F7 C6 FF D0 F3
    # outer_hi = n*3 = 2*3 = 6 → at offset 6
    gen = [read_byte(s, GEN_CODE_BUF + i) for i in range(24)]
    if gen[0] == 0x78: ok(f"WAIT codegen: SEI at $5000 ({gen[0]:#04x})")
    else: err(f"WAIT codegen: expected SEI(0x78) at $5000, got {gen[0]:#04x}")
    if gen[6] == 0x06: ok(f"WAIT codegen: outer_hi=6 for n=2 ({gen[6]:#04x})")
    else: err(f"WAIT codegen: outer_hi={gen[6]:#04x} (expected 0x06 for n=2)")
    # emit_wait emits 21 bytes; with SEI prefix, CLI is at offset 22, RTS at 23
    if gen[22] == 0x58 and gen[23] == 0x60:
        ok(f"WAIT codegen: CLI/RTS at end ({gen[22]:#04x} {gen[23]:#04x})")
    else:
        err(f"WAIT codegen: expected CLI($58)/RTS($60) at end, got {gen[22]:#04x} {gen[23]:#04x}")

    # ── 13. LOOP BACK execution ───────────────────────────────────────────────
    print("\n[13] LOOP BACK execution...")
    clear_all_blocks(s)
    add_block_at_cursor(s, 0)   # SET BORDER (default color=0)
    add_block_at_cursor(s, 5)   # LOOP BACK

    # Break at $5000 — do_run clears stop_flag first, then JSR $5000
    cmd(s, f"bk {GEN_CODE_BUF:04x}", wait=0.05)
    write_byte(s, ZP_LAST_KEY, 0x85)   # F1
    run_and_break(s, timeout=10)        # pauses at $5000 (stop_flag is now 0)
    cmd(s, "del", wait=0.05)

    # Inject stop flag — LOOP BACK will see it and exit instead of looping
    write_byte(s, ZP_STOP_FLAG, 0xFF)

    # Resume — SET BORDER runs, LOOP BACK exits, program returns to PALETTE
    at_state(s, STATE_PALETTE_ADDR, timeout_override=10)

    state  = read_byte(s, ZP_STATE)
    border = read_byte(s, VIC_BORDER)
    if state == STATE_PALETTE: ok(f"LOOP BACK: returned to PALETTE (state={state})")
    else: err(f"LOOP BACK: state={state} (expected {STATE_PALETTE}=PALETTE)")
    if border & 0x0F == 0: ok(f"LOOP BACK: SET BORDER ran ($D020={border:#04x} → color 0)")
    else: err(f"LOOP BACK: $D020={border:#04x} (expected color 0, SET BORDER should have run)")

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print(f"VICE:  {VICE}\nPRG:   {PRG}\n")
    with open(LOGFILE, "w") as log:
        vice_args = [VICE]
        if WARP:
            vice_args.append("-warp")
        vice_args += ["-remotemonitor", "-remotemonitoraddress", f"127.0.0.1:{PORT}", PRG]
        proc = subprocess.Popen(vice_args, stdout=log, stderr=log)
    try:
        print("Connecting to VICE remote monitor...")
        s = connect()
        print(f"Connected on port {PORT}\n")
        run_tests(s)
        s.close()
    finally:
        proc.terminate()
        try: proc.wait(timeout=5)
        except subprocess.TimeoutExpired: proc.kill()

    print()
    total = PASS + FAIL
    if FAIL == 0: print(f"PASS  ({PASS}/{total} checks)"); sys.exit(0)
    else: print(f"FAIL  ({FAIL} error(s), {PASS}/{total} passed)"); sys.exit(1)

if __name__=="__main__": main()
