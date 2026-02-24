// ============================================================
// sid_data.asm — SID music binary (Swamp Sollies by Banana)
// ============================================================
// Loads raw SID player + music data at $9000-$CFFF (16KB).
// Init: JSR $C000 (A=0 for song 1)
// Play: JSR $C475 (call once per frame)
// ============================================================

.filenamespace SidData

.pc = $9000 "SID Music Data"
sid_binary:
    .import binary "../assets/swamp_sollies.bin"
.assert "SID data fits before I/O", * <= $D000, true
