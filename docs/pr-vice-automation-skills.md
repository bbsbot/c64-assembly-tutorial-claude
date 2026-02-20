# Feature Request / PR Proposal — VICE Automation & Headless Testing Skills

**Target repository:** `bbsbot/ultimate-64-dev`
**Proposed by:** C64 Assembly Tutorials project (claude-assisted)
**Date:** 2026-02-19

---

## Summary

This PR adds two new skill sections and updates two existing provisioning skills
to enable fully automated, headless VICE testing and reliable Windows VICE
installation. These additions would have prevented several hours of debugging in
a real project session and should be part of the swarm's baseline knowledge.

---

## Problem Statement

When building a new C64 project from scratch with Claude Code + this skills system:

1. **VICE installation on Windows completely failed** — the bootstrap skill says
   "provide the download link" but never warns that SourceForge is behind
   Cloudflare, making every automated download attempt (curl, PowerShell
   `Invoke-WebRequest`, wget) return a Cloudflare challenge page. The user had
   to manually download VICE with no guidance on where to install it or how to
   add it to PATH.

2. **No skill existed for headless VICE testing** — the swarm had no knowledge of
   `-warp`, `-limitcycles`, or `-exitscreenshot`, so automated build verification
   was not proposed. Every test required the user to manually launch VICE and look
   at the screen.

3. **A critical gotcha (pipe kills screenshot)** was discovered experimentally:
   piping VICE output through `grep` or `awk` prevents `-exitscreenshot` from
   writing the file on Windows. This would have taken hours to diagnose without
   the skill documenting it.

---

## Proposed Changes

### 1. Update `skills/provisioning/bootstrap.md` — §3 VICE Emulator Setup

**Add Windows-specific manual install procedure:**

```markdown
> **Windows note:** SourceForge's VICE download page is behind Cloudflare and
> blocks automated HTTP clients. **Do not attempt to download VICE
> programmatically on Windows.** Instruct the user to download manually.

**Manual install steps (Windows):**
1. Browser → https://vice-emu.sourceforge.io/ → Download → GTK3 binaries (zip)
2. Extract to `C:\tools\vice\` (so `C:\tools\vice\bin\x64sc.exe` exists)
3. Add to PATH (PowerShell, run once):
   ```powershell
   $p = [Environment]::GetEnvironmentVariable("Path","User")
   [Environment]::SetEnvironmentVariable("Path","$p;C:\tools\vice\bin","User")
   ```
4. Restart terminal, then `x64sc --version` to confirm.

**Linux/macOS (automated):**
```bash
sudo apt install vice   # Debian/Ubuntu
brew install vice       # macOS
```
```

---

### 2. Update `skills/provisioning/doctor.md` — §2 Emulator Connectivity

**Add automated test health check section:**

```markdown
### 2a. Automated Test Health
- Run: `bash test.sh` to build + headless-run + pixel-diff against golden
- Regenerate golden: `bash test.sh --golden` after intentional visual changes
- Key files: `build/test_last.png`, `build/test_golden.png`, `build/test_vice.log`
- Valid screenshot: 384×272 PNG from VICE is typically 1–10 KB.
  If < 500 bytes → VICE crashed; check `test_vice.log`.
```

---

### 3. New file: `skills/testing/vice-automation.md`

Full skill covering:

- **VICE headless flags:** `-warp`, `-limitcycles N`, `-exitscreenshot FILE`
- **Cycle budget table:** 100M PAL cycles (≈ 0.5 s in warp) is the right default
  for most projects; boot + BASIC autostart + program init all complete by then
- **Golden reference workflow:** `--golden` flag saves reference; commit to git
- **Pixel comparison:** PowerShell `System.Drawing.Bitmap` (Windows) or
  ImageMagick `compare -metric AE` (Linux/macOS); 0.5% tolerance for jitter
- **Critical gotcha — never pipe VICE output:** Piping VICE stdout/stderr to
  grep/awk kills the `-exitscreenshot` hook on Windows. Always redirect to a
  log file: `>"$LOGFILE" 2>&1 || true`, then grep the log.
- **test.sh reference implementation** (full working script)
- **Troubleshooting table:** screenshot empty, all-blue screen, 100% diff, etc.
- **CI integration:** GitHub Actions snippets for Ubuntu, macOS, Windows runners

---

### 4. Update `CLAUDE.md` skills table

Add the new testing skill to the quick-reference table:

```markdown
| `skills/testing/vice-automation.md` | Headless VICE testing, golden screenshots, CI |
```

---

## Files Changed (diff summary)

```
skills/provisioning/bootstrap.md     — VICE Windows manual install procedure
skills/provisioning/doctor.md        — Automated test health check section
skills/testing/vice-automation.md    — NEW: full headless testing skill
CLAUDE.md                            — Add testing skill to table
```

---

## Acceptance Criteria

- [ ] A new C64 project can be set up on a fresh Windows machine by following
      `bootstrap.md` without any undocumented steps
- [ ] `bash test.sh` produces a `PASS` result on the first run with no manual
      VICE interaction required
- [ ] The skills table in `CLAUDE.md` links to the new testing skill
- [ ] `doctor.md` check for automated tests passes alongside the existing checks

---

## Background / Evidence

This feature request was generated from a real session log where the following
issues occurred sequentially:

1. `curl` returned a 3KB Cloudflare HTML page instead of the VICE zip
2. PowerShell `Invoke-WebRequest` returned the same Cloudflare block
3. Multiple winget/chocolatey/scoop attempts all failed (VICE not packaged)
4. User had to manually download VICE (30+ minutes lost)
5. After VICE was installed, automated testing was discovered by reading VICE
   `--help` output and cross-referencing with known CI patterns
6. Screenshot was 0 bytes for 45 minutes because VICE output was being piped
   instead of redirected — only caught by `bash -x` trace
7. Screenshot threshold of 10,000 bytes was wrong (C64 PNG ~3 KB due to
   compression) — caught immediately once the pipeline ran end-to-end

All of these are now documented in the proposed skills files above.
