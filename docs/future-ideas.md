# Future Ideas — Assembly View Toggle

Brainstormed 2026-02-24 during Phase 5 planning.

---

## 1. Live Memory Visualizer (Heatmap)

Real-time 256-byte heatmap of zero page or the generated code region. Each byte is a colored cell that "pulses" when written during step-through — like a thermal camera for RAM.

**Technical challenges:**
- 16x16 grid using custom characters (requires charset at $3800 or similar)
- Color RAM manipulation to show value intensity (0=black, FF=white, gradient between)
- "Pulse" effect: recently-written cells glow bright then fade over N frames
- Compact enough to fit alongside ASM view or as its own screen mode

**Why it's cool:** Demoscene-grade visualization. Makes the invisible (memory) visible. Enthusiasts love seeing the machine's guts in real time.

---

## 2. Raster-Timed Split Screen

Show Block View and ASM View simultaneously using a raster interrupt to split the screen mid-frame. Top half = blocks, bottom half = assembly. Cursor line in ASM highlights the corresponding block above.

**Technical challenges:**
- Stable raster interrupt at exact scanline (cycle-counted NOP sled or double-IRQ)
- Two different screen layouts sharing one screen RAM (or bank-switch mid-frame)
- Scroll register manipulation to position the split cleanly
- Color RAM shared between both halves

**Why it's cool:** This is quintessential C64 demo technique. Showing two "screens" at once with zero flicker is the kind of thing that made the C64 legendary.

---

## 3. "Matrix Rain" Disassembly Transition

When pressing T to enter ASM view, the assembly code rains down character by character like the Matrix. SID provides a descending cascade tone synchronized to the animation.

**Technical challenges:**
- Per-column rain with randomized start delays and speeds
- Pre-render the target screen in a buffer, then "reveal" it column by column top-to-bottom
- Random intermediate characters before settling on the final character (decode effect)
- SID cascade: descending frequency sweep synced to the rain wavefront
- Must complete in ~2-3 seconds to feel snappy, not sluggish

**Why it's cool:** Pure demoscene eye candy. Transforms a mundane screen swap into a moment of drama. The SID sync makes it feel alive.

---

## 4. Animated Dataflow Arrows

During step-through, show ASCII arrows that visually trace where values flow: `A ──► $D020` on STA, `#$06 ──► A` on LDA. Custom character set with box-drawing/arrow glyphs.

**Technical challenges:**
- Custom charset with arrow/box-drawing characters (←→↑↓ corners, etc.)
- Layout engine to position arrows between register display and operand columns
- Animation: arrow "draws" from source to destination over 3-4 frames
- Must not obscure the disassembly — overlay or use a dedicated row

**Why it's cool:** Actually teaches assembly better than anything else. You SEE the data moving. This is what every assembly tutorial wishes it could show.

---

## 5. Phase 5 "Deluxe" — Animated Block Annotations

Block annotations with visual flair: when stepping, the relevant block flashes/pulses in the annotation row. A mini-preview sprite overlay in the corner shows "this is what SET BORDER CYAN actually does" — picture-in-picture style.

**Technical challenges:**
- Sprite overlay for mini-preview (need free sprite slots)
- Sprite positioning synced to annotation row
- Block effect preview requires partial re-execution or cached result
- Pulse animation on annotation text via Color RAM cycling

**Why it's cool:** Bridges the gap between abstract code and concrete visual effect. The PIP preview is a "wow" moment.

---

## Implementation Priority

| # | Idea | Priority | Depends On |
|---|------|----------|------------|
| 3 | Matrix Rain Transition | **NEXT** | — |
| 1 | Live Memory Visualizer | After #3 | Custom charset |
| 4 | Dataflow Arrows | Future | Custom charset (share with #1) |
| 2 | Raster Split Screen | Future | Stable raster IRQ (already have border-cycle IRQ) |
| 5 | Deluxe Annotations | Future | Phase 5 base, free sprite slots |
