# Plan: Text Splash Screen with SID Music — Verified by Screenshot + Audio

## Context
The bitmap splash screen was committed but never visually confirmed working. The user wants:
1. A **visible** splash/credit screen at startup — verified by screenshot
2. **SID music** (Swamp Sollies by Banana) playing — verified by audio recording
3. Credit displayed: "CHRISTOF MUHLAN (BANANA) / 1987 THE ELECTRONIC KNIGHTS"

### Memory Conflict
The SID file (`$9000-$CFFF`, 16KB) overlaps the bitmap splash data (`$8000-$BFFF`). KickAss will refuse overlapping segments. Rather than fight the bitmap approach (which was never confirmed working), we replace it with a **text-mode splash** that uses no extra memory and is dead-simple to verify.

## Approach: Text-Mode Splash + SID

### Step 1: Strip PSID header, create `assets/swamp_sollies.bin`
### Step 2: New `src/sid_data.asm`
### Step 3: Add SID constants to `src/constants.asm`
### Step 4: Rewrite `src/splash.asm` — text-mode credit screen
### Step 5: Remove `src/splash_data.asm`
### Step 6: Update `src/main.asm`
### Step 7: Update `test.sh` — no changes needed
### Step 8: Verification — screenshot + audio + golden test
