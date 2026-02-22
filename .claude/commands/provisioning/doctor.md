# Skill: Environment Doctor

## Purpose
This skill provides diagnostic logic to troubleshoot and verify the C64 development environment. Use this when the user reports build failures or when starting a session after a long break.

## Diagnostic Checklist

### 1. Java & Compiler Health
- **Check:** Run `java -version` and `java -jar bin/KickAss.jar`.
- **Failure Logic:** If Java is found but the JAR is missing, trigger the `bootstrap` skill to re-download Kick Assembler.
- **Path Check:** Ensure the `bin/` folder is in the local context.

### 2. Emulator Connectivity
- **Check:** `x64sc --version 2>/dev/null || echo "VICE not found"`
- **Common Windows path:** `C:\tools\vice\bin\x64sc.exe` — verify with `ls /c/tools/vice/bin/x64sc.exe`
- **If missing:** Follow `skills/provisioning/bootstrap.md` §3 (manual download required on Windows — SourceForge is Cloudflare-blocked).
- **ViceMCP Check:** If the user is using ViceMCP, verify the MCP server is running and responding to a `ping` or `list_devices` command.

### 2a. Automated Test Health
- **Run the smoke test:** `bash test.sh` (builds, runs headless, pixel-diffs against golden)
- **Regenerate golden:** `bash test.sh --golden` (use after an intentional visual change)
- **Key files:**
  - `build/test_last.png` — screenshot from the most recent test run
  - `build/test_golden.png` — reference screenshot (commit this to git after approval)
  - `build/test_vice.log` — full VICE stdout/stderr for post-mortem debugging
- **Size sanity:** A valid C64 screenshot from VICE is typically 384×272 PNG, ~1–10 KB.
  If `test_last.png` is < 500 bytes the VICE run likely crashed — check `test_vice.log`.

### 3. Ultimate 64 / Hardware Link
- **Check:** If the project is configured for real hardware, attempt to reach the Ultimate 64 IP address.
- **Tool Check:** Verify `c64u-mcp-server` is active in the Claude Code configuration.

### 4. Folder Integrity
- **Check:** Verify the existence of:
    - `build/` (Output directory)
    - `src/` (Source directory)
    - `assets/` (Data directory)
- **Action:** Auto-create any missing directories immediately.

## "Doctor" Command Response
When the user asks "Is my environment okay?" or "Check my setup":
1. Run all checks above.
2. Provide a summary table:
    | Component | Status | Action Needed |
    | :--- | :--- | :--- |
    | Java | OK | None |
    | KickAss | MISSING | Re-run Bootstrap |
    | VICE | OK | None |
3. If errors exist, offer to fix them automatically.