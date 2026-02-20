#!/usr/bin/env bash
# ============================================================
# test.sh — Automated build + smoke test for C64 projects
#
# Usage:
#   bash test.sh            # build + run + compare to golden
#   bash test.sh --golden   # build + run + save new golden reference
#
# Environment overrides:
#   VICE=x64sc              # path to x64sc binary
#   CYCLES=100000000        # emulated PAL cycles before exit
# ============================================================

VICE="${VICE:-/c/tools/vice/bin/x64sc.exe}"
KICKASS="java -jar bin/KickAss.jar"
ROOT="$(cd "$(dirname "$0")" && pwd)"   # absolute project root
PRG="$ROOT/build/main.prg"
SYM="$ROOT/build/main.sym"
SCREENSHOT="$ROOT/build/test_last.png"
GOLDEN="$ROOT/build/test_golden.png"
CYCLES="${CYCLES:-100000000}"   # 100M PAL cycles ≈ boot + autostart + idle
FAIL=0

ok()   { echo "  OK  $*"; }
err()  { echo "  ERR $*"; FAIL=$((FAIL+1)); }

# ── 1. Assemble ──────────────────────────────────────────────
echo "[1/3] Assembling src/main.asm..."
BUILD_OUT=$($KICKASS src/main.asm -o "$PRG" -symbolfile 2>&1)
if echo "$BUILD_OUT" | grep -q "0 failed"; then
  mv src/main.sym "$SYM" 2>/dev/null || true
  ok "build/main.prg assembled cleanly"
else
  echo "$BUILD_OUT" | grep -E "^(Got|Error)" | head -5
  err "assembly failed"
  exit 1
fi

# ── 2. Headless VICE run ─────────────────────────────────────
echo "[2/3] Running headless ($((CYCLES/1000000))M PAL cycles)..."
# Redirect all output to a log; use absolute paths so VICE resolves them correctly
VICE_LOG="$ROOT/build/test_vice.log"
"$VICE" -warp -limitcycles "$CYCLES" -exitscreenshot "$SCREENSHOT" "$PRG" \
  >"$VICE_LOG" 2>&1 || true   # exit 1 is normal for -limitcycles

SIZE=$(stat -c%s "$SCREENSHOT" 2>/dev/null || echo 0)
if [ "$SIZE" -gt 500 ]; then
  ok "screenshot captured (${SIZE} bytes) → $SCREENSHOT"
else
  err "screenshot missing or too small (${SIZE} bytes) — VICE may have crashed"
  cat "$VICE_LOG" | grep -i "error\|fatal\|crash" | head -5 || true
  exit 1
fi

# ── 3. Golden comparison ─────────────────────────────────────
if [ "${1:-}" = "--golden" ]; then
  cp "$SCREENSHOT" "$GOLDEN"
  ok "golden reference saved → $GOLDEN"
  echo ""
  echo "Run 'bash test.sh' to compare future builds."
  exit 0
fi

if [ ! -f "$GOLDEN" ]; then
  echo "[3/3] No golden reference yet. Run: bash test.sh --golden"
  exit 0
fi

echo "[3/3] Comparing screenshot to golden..."
RESULT=$(powershell.exe -NoProfile -Command "
Add-Type -AssemblyName System.Drawing
\$a = [System.Drawing.Bitmap]::FromFile((Resolve-Path '$GOLDEN'))
\$b = [System.Drawing.Bitmap]::FromFile((Resolve-Path '$SCREENSHOT'))
if (\$a.Width -ne \$b.Width -or \$a.Height -ne \$b.Height) {
  Write-Output 'SIZE_MISMATCH'
} else {
  \$diff = 0
  for (\$y = 0; \$y -lt \$a.Height; \$y++) {
    for (\$x = 0; \$x -lt \$a.Width; \$x++) {
      if (\$a.GetPixel(\$x,\$y) -ne \$b.GetPixel(\$x,\$y)) { \$diff++ }
    }
  }
  Write-Output \"DIFF \$diff \$(\$a.Width * \$a.Height)\"
}
" 2>/dev/null | tr -d '\r')

case "$RESULT" in
  "DIFF 0 "*)
    ok "pixel-perfect match"
    ;;
  "SIZE_MISMATCH")
    err "screenshot dimensions changed"
    ;;
  "DIFF "*)
    DIFF_PX=$(echo "$RESULT" | awk '{print $2}')
    TOTAL_PX=$(echo "$RESULT" | awk '{print $3}')
    PCT=$(awk "BEGIN{printf \"%.2f\", $DIFF_PX/$TOTAL_PX*100}")
    WITHIN=$(awk "BEGIN{print ($DIFF_PX/$TOTAL_PX <= 0.005) ? 1 : 0}")
    if [ "$WITHIN" = "1" ]; then
      ok "${DIFF_PX}px differ (${PCT}%) — within 0.5% tolerance"
    else
      err "${DIFF_PX}px differ (${PCT}%) — exceeds 0.5% tolerance"
    fi
    ;;
  *)
    err "comparison error: $RESULT"
    ;;
esac

echo ""
[ "$FAIL" -eq 0 ] && echo "PASS" && exit 0
echo "FAIL ($FAIL error(s))" && exit 1
