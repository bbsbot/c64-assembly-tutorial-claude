# Skill: Environment Bootstrap

## Purpose
This skill allows Claude to transform an empty directory into a fully functional Commodore 64 development environment. It focuses on the "Auto-Install" philosophy for macOS/Linux/Windows.

## Workflow: "Let's Get Started"
When the user requests a setup, perform these steps in order:

### 1. Java Runtime Environment (JRE) Verification
- **Task:** Check if Java is installed (`java -version`).
- **Logic:** Kick Assembler requires Java. If missing, instruct the user to install the OpenJDK or use a package manager (brew/apt).

### 2. Kick Assembler Installation
- **Source:** http://theweb.dk/KickAssembler/
- **Task:** 1. Create a `bin/` directory if it doesn't exist.
    2. Download the latest KickAssembler zip.
    3. Extract `KickAss.jar` to the `bin/` folder.
- **Verification:** Run `java -jar bin/KickAss.jar` to ensure it responds.

### 3. VICE Emulator Setup

> **Windows note:** SourceForge's VICE download page is behind Cloudflare and blocks
> automated HTTP clients (curl, PowerShell `Invoke-WebRequest`, wget). **Do not attempt
> to download VICE programmatically on Windows — it will always fail with a Cloudflare
> challenge page.** Instruct the user to download manually instead.

**Automated check:**
```bash
x64sc --version 2>/dev/null || echo "VICE not found"
```

**If VICE is missing — Windows manual install procedure:**
1. User opens a browser and downloads the latest GTK3 VICE for Windows from:
   https://vice-emu.sourceforge.io/ → "Download" → GTK3 binaries (zip, ~80 MB)
2. Extract the zip to `C:\tools\vice\`
   — the `bin\` subfolder should contain `x64sc.exe`, `x64.exe`, etc.
3. Add to user PATH (PowerShell, run once):
   ```powershell
   $p = [Environment]::GetEnvironmentVariable("Path","User")
   [Environment]::SetEnvironmentVariable("Path","$p;C:\tools\vice\bin","User")
   ```
4. Restart the terminal, then verify:
   ```bash
   x64sc --version   # should print VICE version line
   ```

**If VICE is missing — Linux/macOS:**
```bash
# Debian/Ubuntu
sudo apt install vice
# macOS
brew install vice
```

**Configuring the path for future sessions:**
Store the resolved path in `.claude/CLAUDE.md` or in `test.sh` via the `VICE` env var:
```bash
export VICE=/c/tools/vice/bin/x64sc.exe   # Windows (Git Bash)
```

**Verification:** `x64sc -warp -limitcycles 1000000 /dev/null 2>/dev/null; echo "exit $?"`
(exit code 1 is normal when `-limitcycles` fires — that means VICE is working correctly).

### 4. Folder Scaffolding
- **Task:** Ensure the following subdirectories exist:
    - `/src`: For assembly source code.
    - `/build`: For compiled .prg files.
    - `/assets`: For sprites, SID, and map data.

### 5. Hello World Test
- **Task:** Generate a basic `src/main.asm` file:
```kickasm
// Basic Upstart for C64
:BasicUpstart2(main)
main:
    lda #$00
    sta $d020 // Set border black
    sta $d021 // Set background black
    rts

```

* **Action:** Compile the file using the newly installed KickAss and attempt to launch it in VICE.

## Completion Criteria

The environment is "Ready" only when a `.prg` has successfully compiled and a project folder structure is visible.
