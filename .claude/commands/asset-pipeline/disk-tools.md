# Skill: Disk Management & .d64 Mastering

## Purpose
To provide Claude with the ability to manage virtual disk images. This skill is used to bundle programs, data files, and GEOS resources into a single `.d64` or `.d81` file for distribution or hardware loading.

## Tooling: c1541 (VICE)
Claude should prefer the `c1541` utility included with VICE for command-line disk manipulation.

### Common Operations
- **Create Disk:** `c1541 -format "diskname,id" d64 disk.d64`
- **Attach/Add File:** `c1541 -attach disk.d64 -write program.prg "program"`
- **List Directory:** `c1541 -attach disk.d64 -list`

## Custom Directory Art
Claude should assist the user in creating "BBS-style" or "Scene-style" directories using PETSCII characters:
- **Spacers:** Adding dummy files with names like `----------` or `* MY PROJECT *`.
- **Hidden Files:** Using non-printing characters to create clean-looking directories.

## GEOS Disk Formatting
When working on GEOS projects, the disk must be "GEOS-formatted" to include the Off-page directory and the `BorderBlock`.
- **Logic:** Claude should advise using `GEOS-Disk-Gate` or specialized scripts to inject the `Off-Page` metadata required for the GEOS DeskTop to recognize the files.

## Automated Build Chain
Claude should suggest a "One-Command Build" in `.claude/CLAUDE.md`:
1. Compile `.asm` to `.prg` via KickAss.
2. Create a new `.d64`.
3. Inject the `.prg` and any necessary assets (SID, levels).
4. Launch VICE with the `.d64` attached.

## Example Pattern: Makefile-style Build
```bash
# Claude's recommended shell command for a full disk build
java -jar bin/KickAss.jar src/main.asm -o build/main.prg && \
c1541 -format "myswarm,01" d64 build/disk.d64 && \
c1541 -attach build/disk.d64 -write build/main.prg "auto-run"

```

## Hardware Note

If the user is using an **Ultimate 64**, Claude can use the MCP protocol to "Mount" the generated `.d64` directly onto the real hardware via the network.
