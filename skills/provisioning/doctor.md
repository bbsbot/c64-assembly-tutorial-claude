# Skill: Environment Doctor

## Purpose
This skill provides diagnostic logic to troubleshoot and verify the C64 development environment. Use this when the user reports build failures or when starting a session after a long break.

## Diagnostic Checklist

### 1. Java & Compiler Health
- **Check:** Run `java -version` and `java -jar bin/KickAss.jar`.
- **Failure Logic:** If Java is found but the JAR is missing, trigger the `bootstrap` skill to re-download Kick Assembler.
- **Path Check:** Ensure the `bin/` folder is in the local context.

### 2. Emulator Connectivity
- **Check:** Attempt to call `x64sc --version` or check the path defined in `.claude/CLAUDE.md`.
- **ViceMCP Check:** If the user is using ViceMCP, verify the MCP server is running and responding to a `ping` or `list_devices` command.

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