# Skill: VICE Headless Automated Testing

## Purpose
Run a C64 `.prg` file non-interactively in VICE, capture a screenshot at a fixed
cycle count, and compare it pixel-for-pixel against a golden reference image.
This gives every build a fast, deterministic smoke test with no human in the loop.

---

## VICE Headless Flags

| Flag | Purpose |
|---|---|
| `-warp` | Run at maximum host CPU speed (skip real-time throttle) |
| `-limitcycles N` | Exit after exactly N emulated cycles; always exits with code 1 (normal) |
| `-exitscreenshot FILE` | Write a PNG screenshot at the moment VICE exits |
| `-headless` | (VICE ≥ 3.7) Skip all GUI/display initialisation — faster on CI |

**Minimum useful command:**
```bash
x64sc -warp -limitcycles 100000000 -exitscreenshot build/test_last.png build/main.prg \
  >build/test_vice.log 2>&1 || true
```

The `|| true` prevents the shell from aborting on VICE's normal exit-code-1.

---

## Cycle Budget

VICE uses PAL timing: **985,248 cycles/second**.

| Cycles | Wall time (warp) | What happens |
|---|---|---|
| 2,000,000 | ~instant | BASIC ROM barely started |
| 15,000,000 | < 0.1 s | BASIC `READY.` visible |
| **100,000,000** | **~0.5 s** | Boot + BASIC autostart + program fully initialised |
| 500,000,000 | ~2 s | Safe for programs with long startup animations |

Use **100M cycles** for most projects. Increase if the program has a long loading
screen or splash animation that must be visible in the screenshot.

---

## Golden Reference Workflow

```
bash test.sh --golden   # build + run + save test_last.png as test_golden.png
git add build/test_golden.png
git commit -m "test: update golden reference"

bash test.sh            # build + run + compare against golden
```

After every intentional visual change, regenerate the golden with `--golden`.

---

## Pixel Comparison (Windows — PowerShell)

```powershell
Add-Type -AssemblyName System.Drawing
$a = [System.Drawing.Bitmap]::FromFile((Resolve-Path 'build/test_golden.png'))
$b = [System.Drawing.Bitmap]::FromFile((Resolve-Path 'build/test_last.png'))
if ($a.Width -ne $b.Width -or $a.Height -ne $b.Height) {
    Write-Output "SIZE_MISMATCH"
} else {
    $diff = 0
    for ($y = 0; $y -lt $a.Height; $y++) {
        for ($x = 0; $x -lt $a.Width; $x++) {
            if ($a.GetPixel($x,$y) -ne $b.GetPixel($x,$y)) { $diff++ }
        }
    }
    Write-Output "DIFF $diff $($a.Width * $a.Height)"
}
```

**Tolerance:** Allow up to **0.5%** pixel difference to absorb raster-timing jitter
between VICE versions (`$DIFF_PX / $TOTAL_PX <= 0.005`).

---

## Pixel Comparison (Linux/macOS — ImageMagick)

```bash
# Install: sudo apt install imagemagick  or  brew install imagemagick
compare -metric AE build/test_golden.png build/test_last.png /dev/null 2>&1
# Output = number of differing pixels; 0 = identical
```

---

## test.sh Structure (reference implementation)

```bash
#!/usr/bin/env bash
VICE="${VICE:-/c/tools/vice/bin/x64sc.exe}"   # override with env var
KICKASS="java -jar bin/KickAss.jar"
ROOT="$(cd "$(dirname "$0")" && pwd)"          # always use absolute paths!
PRG="$ROOT/build/main.prg"
SCREENSHOT="$ROOT/build/test_last.png"
GOLDEN="$ROOT/build/test_golden.png"
CYCLES="${CYCLES:-100000000}"
FAIL=0

# 1. Assemble
BUILD_OUT=$($KICKASS src/main.asm -o "$PRG" -symbolfile 2>&1)
echo "$BUILD_OUT" | grep -q "0 failed" || { echo "Build failed"; exit 1; }
mv src/main.sym "$ROOT/build/main.sym" 2>/dev/null || true

# 2. Run headless — do NOT pipe VICE output; redirect to log file only
"$VICE" -warp -limitcycles "$CYCLES" -exitscreenshot "$SCREENSHOT" "$PRG" \
  >"$ROOT/build/test_vice.log" 2>&1 || true

SIZE=$(stat -c%s "$SCREENSHOT" 2>/dev/null || echo 0)
[ "$SIZE" -gt 500 ] || { echo "Screenshot missing/empty"; exit 1; }

# 3. Golden compare (or save)
if [ "${1:-}" = "--golden" ]; then
  cp "$SCREENSHOT" "$GOLDEN"; echo "Golden saved"; exit 0
fi
# ... pixel diff via PowerShell or ImageMagick ...
```

### Critical: never pipe VICE to grep/awk
Piping VICE's output (`"$VICE" ... | grep ...`) causes the screenshot to **not be
written** on some OS+VICE combinations, because the pipe keeps the process group
alive in a way that prevents the exit-screenshot hook from firing.
**Always redirect to a log file** (`>log 2>&1`) and then grep the log afterwards.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Screenshot is 0 bytes | VICE crashed at startup | Check `test_vice.log` for ROM path errors |
| Screenshot < 500 bytes | VICE exited before drawing anything | Increase `CYCLES` |
| Screenshot shows only blue screen | Program crashes before drawing | Use VICE monitor (`Alt+M`) to debug |
| Pixel diff 100% | Resolution changed between VICE versions | Regenerate golden |
| DLL errors in vice log | Missing optional libs (HardSID, WinPcap) | Safe to ignore — not fatal |
| `limitcycles` exits code 0 | Old VICE (<3.5) | Update VICE; code 1 is correct in 3.10 |

---

## CI Integration (GitHub Actions)

```yaml
- name: Install VICE (Ubuntu)
  run: sudo apt-get install -y vice

- name: Assemble & test
  run: bash test.sh
  env:
    VICE: x64sc
    CYCLES: 100000000
```

On macOS runners use `brew install vice`. On Windows runners, VICE must be
pre-installed as an action input (SourceForge is Cloudflare-blocked for
programmatic downloads — see `skills/provisioning/bootstrap.md`).
