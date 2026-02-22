# Skill: GEOS VLIR File Management

## Purpose
To enable Claude to create and manipulate GEOS VLIR (Variable Length Index Record) files. This is essential for professional GEOS applications that require modular code loading (overlays) or database-style record management.

## VLIR Fundamentals
- **The Index Record:** A VLIR file starts with a table of up to 127 records. Each entry points to a chain of sectors on the disk.
- **Random Access:** Unlike a standard sequential file, a VLIR file allows the application to say "Load Record 5" without reading Records 1-4.
- **The Header:** Every VLIR file must have a GEOS header that identifies it as `FILE_TYPE_VLIR`.

## Critical Kernal Routines
Claude must use these routines to manage VLIR data:
- `OpenRecordFile` ($C2D8): Opens the file and loads the VLIR index into memory.
- `ReadRecord` ($C2E1): Loads a specific record from the VLIR file into a memory buffer.
- `WriteRecord` ($C2E4): Saves data from memory into a specific record slot.
- `CloseRecordFile` ($C2DD): Properly flushes the index to disk.

## Application Architecture: Overlays
For large GEOS applications, Claude should suggest the "Overlay" pattern:
1. **Record 0:** The "Main" application logic that stays in memory.
2. **Record 1-N:** Specific modules (e.g., a "Print" module or a "Search" module).
3. **Action:** When a feature is needed, the Main logic calls `ReadRecord` to swap the required module into a designated "Overlay Area" in RAM.

## VLIR Header Definition (KickAss)
```kickasm
// Example VLIR Header snippet
.byte $03, $15         // Pointer to next directory track/sector
.byte 'A'              // GEOS File Structure (VLIR)
.byte $82              // File Type (Application)
// ... (Icon and Author Data) ...

```

## Expert Advice

* **Fragmentation:** Remind the user that frequently writing VLIR records can fragment a disk. Suggest "Packing" the file occasionally.
* **Record Limits:** A single record cannot exceed 64KB, and a VLIR file cannot exceed 127 records.
