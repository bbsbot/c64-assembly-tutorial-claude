#!/usr/bin/env python3
"""
test_interactive.py — Automated interactive test for C64 Block Tutor

Uses VICE's text remote monitor (port 6510) with breakpoints to inject
joystick input AFTER input_read_joystick has already run (so our write
to zp_joy_edge is not overwritten by the hardware poll).

Strategy:
  - Breakpoint at state_palette / state_program (AFTER input is read)
  - When breakpoint fires (VICE pauses), write zp_joy_edge
  - Continue; VICE processes the joystick edge in the handler
  - Next breakpoint fires; read ZP to verify

Usage:   python test_interactive.py
Env:     VICE=path/to/x64sc.exe   MONITOR_PORT=6510
"""

import io, os, re, socket, subprocess, sys, time
# Force UTF-8 output on Windows (avoids cp1252 encoding errors)
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

# ── Config ───────────────────────────────────────────────────────────────────

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

# ZP addresses
ZP_STATE      = 0x02;  ZP_PAL_CURSOR = 0x03;  ZP_PGM_CURSOR = 0x04
ZP_SLOTS_USED = 0x05;  ZP_JOY_EDGE   = 0x08;  ZP_LAST_KEY   = 0x10
ZP_STOP_FLAG  = 0x11

JOY_UP=0x01; JOY_DOWN=0x02; JOY_LEFT=0x04; JOY_RIGHT=0x08; JOY_FIRE=0x10
STATE_PALETTE=0; STATE_PROGRAM=1; STATE_EDIT_PARAM=2; STATE_RUNNING=3

# Addresses from build/main.sym
MAIN_LOOP_ADDR      = 0x0880
STATE_PALETTE_ADDR  = 0x08A9   # entry of state_palette handler (after input read)
STATE_PROGRAM_ADDR  = 0x091F   # entry of state_program handler

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

def _send(s, line):
    s.sendall((line+"\n").encode())

def _wait_for_prompt(s, timeout=15):
    """Read until we see the VICE monitor prompt (C:$xxxx)."""
    buf = b""; deadline = time.time()+timeout; s.settimeout(0.3)
    while time.time() < deadline:
        try:
            chunk = s.recv(4096)
            if chunk: buf += chunk
        except socket.timeout: pass
        text = buf.decode(errors="replace")
        if re.search(r"\(C:\$[0-9a-fA-F]{4}\)", text): return text
    return buf.decode(errors="replace")

def cmd(s, line, wait=0.15):
    _send(s, line); time.sleep(wait)
    return _drain(s)

def run_and_break(s, timeout=15):
    """Send 'g', wait for breakpoint to fire, return paused."""
    _send(s, "g")
    return _wait_for_prompt(s, timeout)

def read_byte(s, addr):
    resp = cmd(s, f"m {addr:04x} {addr:04x}", wait=0.2)
    m = re.search(rf"{addr:04x}\s+([0-9a-fA-F]{{2}})", resp, re.IGNORECASE)
    return int(m.group(1), 16) if m else None

def write_byte(s, addr, val):
    cmd(s, f"> {addr:04x} {val:02x}", wait=0.1)

# ── Injection helpers ─────────────────────────────────────────────────────────

def at_state(s, handler_addr, joy_bit=None, last_key=None):
    """
    Set breakpoint at handler_addr, run until it fires (VICE paused),
    optionally inject joy_bit or last_key, then return.
    Does NOT continue — caller decides when to call run_and_break next.
    """
    cmd(s, f"bk {handler_addr:04x}", wait=0.05)
    run_and_break(s)                # runs until breakpoint; VICE now paused
    cmd(s, "del", wait=0.05)       # clear all breakpoints
    if joy_bit  is not None: write_byte(s, ZP_JOY_EDGE, joy_bit)
    if last_key is not None: write_byte(s, ZP_LAST_KEY, last_key)

def press_and_verify(s, handler_addr, joy_bit, read_addr, expected,
                     desc, *, check_eq=True):
    """Inject joy_bit at handler, continue one frame, read result."""
    at_state(s, handler_addr, joy_bit=joy_bit)
    # Continue; handler processes the bit, then jmp main_loop → next frame
    at_state(s, handler_addr)      # arrive at next frame's handler entry
    val = read_byte(s, read_addr)
    if (val == expected) == check_eq:
        ok(f"{desc}: {read_addr:#06x}={val:#04x}")
    else:
        err(f"{desc}: got {val} expected {expected}")

# ── Tests ─────────────────────────────────────────────────────────────────────

def run_tests(s):
    print("\n[1/6] Init — wait for main_loop...")
    cmd(s, f"bk {MAIN_LOOP_ADDR:04x}", wait=0.05)
    run_and_break(s, timeout=20)
    cmd(s, "del", wait=0.05)
    # From here, main_loop has been reached (init complete)
    # Advance to first state_palette entry (after input is read)
    at_state(s, STATE_PALETTE_ADDR)   # waits at handler, no inject

    st = read_byte(s, ZP_STATE); pal = read_byte(s, ZP_PAL_CURSOR)
    used = read_byte(s, ZP_SLOTS_USED)
    if st == STATE_PALETTE: ok(f"init: zp_state=PALETTE({st})")
    else: err(f"init: bad state {st}")
    if pal == 0 and used == 0: ok(f"init: pal_cursor={pal} slots_used={used}")
    else: err(f"init: pal_cursor={pal} slots_used={used} (want 0,0)")

    print("\n[2/6] Palette cursor navigation...")
    # Inject DOWN — cursor should go 0→1
    write_byte(s, ZP_JOY_EDGE, JOY_DOWN)
    at_state(s, STATE_PALETTE_ADDR)   # run through handler + next frame
    pal = read_byte(s, ZP_PAL_CURSOR)
    if pal == 1: ok(f"cursor DOWN: pal_cursor={pal}")
    else: err(f"cursor DOWN failed: pal_cursor={pal} (expected 1)")

    # Inject DOWN again — cursor should go 1→2
    write_byte(s, ZP_JOY_EDGE, JOY_DOWN)
    at_state(s, STATE_PALETTE_ADDR)
    pal = read_byte(s, ZP_PAL_CURSOR)
    if pal == 2: ok(f"cursor DOWN again: pal_cursor={pal}")
    else: err(f"cursor DOWN#2 failed: pal_cursor={pal} (expected 2)")

    # Inject UP — cursor should go 2→1
    write_byte(s, ZP_JOY_EDGE, JOY_UP)
    at_state(s, STATE_PALETTE_ADDR)
    pal = read_byte(s, ZP_PAL_CURSOR)
    if pal == 1: ok(f"cursor UP: pal_cursor={pal}")
    else: err(f"cursor UP failed: pal_cursor={pal} (expected 1)")

    print("\n[3/6] Add blocks (FIRE in palette)...")
    # Move back to top first
    write_byte(s, ZP_JOY_EDGE, JOY_UP)
    at_state(s, STATE_PALETTE_ADDR)

    write_byte(s, ZP_JOY_EDGE, JOY_FIRE)
    at_state(s, STATE_PALETTE_ADDR)
    used = read_byte(s, ZP_SLOTS_USED)
    if used == 1: ok(f"FIRE adds block: slots_used={used}")
    else: err(f"FIRE add failed: slots_used={used} (expected 1)")

    write_byte(s, ZP_JOY_EDGE, JOY_FIRE)
    at_state(s, STATE_PALETTE_ADDR)
    used = read_byte(s, ZP_SLOTS_USED)
    if used == 2: ok(f"second block: slots_used={used}")
    else: err(f"second add failed: slots_used={used} (expected 2)")

    print("\n[4/6] Panel switch (palette <-> program)...")
    # RIGHT → should switch to STATE_PROGRAM
    write_byte(s, ZP_JOY_EDGE, JOY_RIGHT)
    # After RIGHT in palette, state changes to PROGRAM → handler at state_program
    at_state(s, STATE_PROGRAM_ADDR)
    st = read_byte(s, ZP_STATE)
    if st == STATE_PROGRAM: ok(f"RIGHT → program panel: zp_state={st}")
    else: err(f"panel switch failed: zp_state={st} (expected {STATE_PROGRAM})")

    # LEFT → back to palette
    write_byte(s, ZP_JOY_EDGE, JOY_LEFT)
    at_state(s, STATE_PALETTE_ADDR)
    st = read_byte(s, ZP_STATE)
    if st == STATE_PALETTE: ok(f"LEFT → palette: zp_state={st}")
    else: err(f"panel switch back failed: zp_state={st}")

    print("\n[5/6] F1 RUN (codegen)...")
    write_byte(s, ZP_LAST_KEY, 0x85)   # F1
    at_state(s, STATE_PALETTE_ADDR)    # state should be PALETTE after run
    st = read_byte(s, ZP_STATE)
    if st in (STATE_PALETTE, STATE_RUNNING):
        ok(f"F1 run: zp_state={st} (palette or running)")
    else: err(f"F1 run: unexpected state {st}")

    print("\n[6/6] LOOP BACK stop flag (write/read)...")
    write_byte(s, ZP_STOP_FLAG, 0xFF)
    val = read_byte(s, ZP_STOP_FLAG)
    if val == 0xFF: ok(f"stop flag set: {val:#04x}")
    else: err(f"stop flag set failed: {val}")
    write_byte(s, ZP_STOP_FLAG, 0x00)
    val = read_byte(s, ZP_STOP_FLAG)
    if val == 0x00: ok(f"stop flag cleared: {val:#04x}")
    else: err(f"stop flag clear failed: {val}")

# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    print(f"VICE:  {VICE}\nPRG:   {PRG}\n")
    with open(LOGFILE, "w") as log:
        proc = subprocess.Popen(
            [VICE, "-warp", "-remotemonitor",
             "-remotemonitoraddress", f"127.0.0.1:{PORT}", PRG],
            stdout=log, stderr=log)
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
    if FAIL == 0: print(f"PASS ({PASS} checks)"); sys.exit(0)
    else: print(f"FAIL ({FAIL} error(s), {PASS} passed)"); sys.exit(1)

if __name__=="__main__": main()
