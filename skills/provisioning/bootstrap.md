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
- **Task:** Check if `x64sc` is in the PATH.
- **Logic:** If not found, ask the user where their VICE installation is located or provide the download link (https://vice-emu.sourceforge.io/). Store the path in the local `.claude/CLAUDE.md` for future sessions.

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
