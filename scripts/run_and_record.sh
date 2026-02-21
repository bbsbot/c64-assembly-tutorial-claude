#!/usr/bin/env bash
# run_and_record.sh — Run the full test suite and record the screen with ffmpeg.
# Output: build/test_recording.mp4
#
# Usage:
#   bash scripts/run_and_record.sh

set -euo pipefail

FFMPEG="/c/Users/Admin/AppData/Local/Microsoft/WinGet/Packages/Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe/ffmpeg-8.0.1-full_build/bin/ffmpeg.exe"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_UNIX="$ROOT/build/test_recording.mp4"
OUT_WIN="$(cygpath -w "$OUT_UNIX")"

# Remove previous recording if present
rm -f "$OUT_UNIX"

echo "Starting ffmpeg screen capture → build/test_recording.mp4"

# Capture full desktop at 15fps, x264 fast encode.
# -movflags frag_keyframe+empty_moov writes a fragmented MP4 (fMP4):
# each keyframe fragment is self-contained, so the file is playable even
# if ffmpeg is terminated without a clean shutdown (no moov-at-end needed).
"$FFMPEG" \
    -f gdigrab -framerate 15 -i desktop \
    -c:v libx264 -preset fast -crf 23 \
    -movflags frag_keyframe+empty_moov \
    -y "$OUT_WIN" \
    </dev/null &>/tmp/ffmpeg_record.log &

FFMPEG_PID=$!
sleep 2     # give ffmpeg time to initialise

echo "Running test suite (real-speed — no warp, so VICE is visible)..."
echo ""
python "$ROOT/test_interactive.py" --no-warp
TEST_EXIT=$?

sleep 1     # capture final state for a moment

echo ""
echo "Stopping ffmpeg (taskkill — fMP4 fragments are already on disk)..."
# On Windows, kill -INT doesn't reliably reach a native .exe from Git Bash.
# taskkill terminates the process; because we use frag_keyframe+empty_moov
# the fragmented MP4 written so far is fully playable without a final moov.
taskkill //PID $FFMPEG_PID //F 2>/dev/null || true
sleep 1   # let the OS flush file buffers

echo ""
if [ -f "$OUT_UNIX" ]; then
    SIZE=$(du -h "$OUT_UNIX" | cut -f1)
    echo "Recording saved:  build/test_recording.mp4  ($SIZE)"
else
    echo "WARNING: recording file not found — check /tmp/ffmpeg_record.log"
fi

exit $TEST_EXIT
