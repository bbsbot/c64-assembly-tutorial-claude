# ============================================================
# vice-interact.ps1  -- Integration test driver for Phase 2
#
# Launches VICE and injects C64 keyboard events via:
#   1. SetCursorPos + mouse_event  -- clicks the VICE title bar
#      so the window gains REAL foreground focus (bypasses
#      Windows focus-stealing restrictions that block
#      SetForegroundWindow from piped/non-interactive processes)
#   2. PostMessage(WM_KEYDOWN/WM_KEYUP) -- delivers the VK code
#      to SDL2's message queue; SDL2 processes it because VICE
#      now has genuine keyboard focus.
#
# Key mapping:
#   VK_SPACE (0x20) -> SDL SDLK_SPACE -> C64 SPACE -> PETSCII $20
#   VK_F1    (0x70) -> SDL SDLK_F1    -> C64 F1    -> PETSCII $85
#   VK_T     (0x54) -> SDL SDLK_t (unshifted) -> C64 T -> PETSCII $54
#
# Outputs (all under $OutDir):
#   screenshot-block-view.png  initial state (before any keys)
#   screenshot-asm-view.png    after SPACE + F1 + T sequence
#   screenshot-return.png      after second T (back to block view)
#   window-bounds.txt          "CliX CliY CliW CliH" of VICE client area
#   interaction-log.txt        timestamps for video trim
# ============================================================
param(
    [Parameter(Mandatory)][string]$VicePath,
    [Parameter(Mandatory)][string]$PrgPath,
    [Parameter(Mandatory)][string]$OutDir,
    [switch]$SkipRecord
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ── Win32 helpers ─────────────────────────────────────────────
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32Wnd {
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint uCode, uint uMapType);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, int dx, int dy, uint cButtons, UIntPtr dwExtraInfo);
    [StructLayout(LayoutKind.Sequential)] public struct RECT  { public int L,T,R,B; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X,Y; }
}
"@ -ErrorAction SilentlyContinue

$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$log = "$OutDir\interaction-log.txt"
"[$(Get-Date -Format 'HH:mm:ss')] Integration test started" | Out-File $log

function Log($msg) {
    $ts = Get-Date -Format 'HH:mm:ss.fff'
    "$ts  $msg" | Tee-Object -FilePath $log -Append | Write-Host
}

function Take-Screenshot($path) {
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp    = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
    $g      = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen(0, 0, 0, 0, $screen.Size)
    $bmp.Save($path)
    $g.Dispose(); $bmp.Dispose()
}

function Get-WindowBounds($proc) {
    $rect = New-Object Win32Wnd+RECT
    [Win32Wnd]::GetWindowRect($proc.MainWindowHandle, [ref]$rect) | Out-Null
    $cr   = New-Object Win32Wnd+RECT
    [Win32Wnd]::GetClientRect($proc.MainWindowHandle, [ref]$cr)  | Out-Null
    $pt   = New-Object Win32Wnd+POINT
    [Win32Wnd]::ClientToScreen($proc.MainWindowHandle, [ref]$pt) | Out-Null
    return @{
        WinX = $rect.L; WinY = $rect.T
        WinW = $rect.R - $rect.L; WinH = $rect.B - $rect.T
        CliX = $pt.X;  CliY = $pt.Y
        CliW = $cr.R;  CliH = $cr.B
    }
}

# ── Click VICE title bar to acquire genuine foreground focus ───
# Windows focus-stealing prevention blocks SetForegroundWindow
# when called from a non-interactive (piped) process. A real
# mouse click on the title bar is always honored because Windows
# interprets it as a direct user action.
# $bounds must be set before calling this function.
function Focus-ViceWindow {
    # Title bar center: (WinX + WinW/2, WinY + 10)
    # 10px into the title bar is safe: above the SDL client area,
    # so C64 does not receive a joystick/paddle mouse event.
    $cx = $bounds.WinX + [int]($bounds.WinW / 2)
    $cy = $bounds.WinY + 10
    Log "  Clicking title bar at ($cx,$cy) for focus..."
    [Win32Wnd]::SetCursorPos($cx, $cy) | Out-Null
    Start-Sleep -Milliseconds 200
    # MOUSEEVENTF_LEFTDOWN = 0x0002, MOUSEEVENTF_LEFTUP = 0x0004
    [Win32Wnd]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)  # click down
    Start-Sleep -Milliseconds 80
    [Win32Wnd]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)  # click up
    Start-Sleep -Milliseconds 500  # Let SDL2 receive and process WM_SETFOCUS
}

# ── Inject a VK key into VICE via PostMessage ──────────────────
# Requires Focus-ViceWindow to have been called recently.
# VK codes: 0x20=SPACE, 0x70=F1, 0x54=T (unshifted)
function Inject-ViceKey([int]$vk, [string]$desc) {
    Log "  Injecting VK=0x$($vk.ToString('X2')) ($desc)"
    $hwnd = $viceProc.MainWindowHandle

    # Click title bar for focus before each key so SDL2 has keyboard focus
    Focus-ViceWindow

    # Compute the scan code (needed for correct lParam)
    $scan = [Win32Wnd]::MapVirtualKey([uint32]$vk, 0)  # MAPVK_VK_TO_VSC = 0

    # WM_KEYDOWN = 0x0100 : lParam bits[0..15]=repeat(1), bits[16..23]=scan
    $lpDown = [IntPtr](($scan -shl 16) -bor 1)
    [Win32Wnd]::PostMessage($hwnd, 0x0100, [IntPtr]$vk, $lpDown) | Out-Null
    Start-Sleep -Milliseconds 80

    # WM_KEYUP = 0x0101 : bit31=1(up), bit30=1(prev-down), bits[16..23]=scan
    $lpUpVal = ([long]$scan -shl 16) -bor 0xC0000001L
    $lpUp    = [IntPtr]([long]$lpUpVal)
    [Win32Wnd]::PostMessage($hwnd, 0x0101, [IntPtr]$vk, $lpUp) | Out-Null
    Start-Sleep -Milliseconds 200
}

# ── 1. Launch VICE ─────────────────────────────────────────────
Log "Launching VICE (warp mode)"
Log "  $VicePath"
Log "  PRG: $PrgPath"

$viceProc = Start-Process -FilePath $VicePath -ArgumentList @("-warp", $PrgPath) -PassThru

# Wait for VICE window to appear (up to 20 seconds)
$deadline = (Get-Date).AddSeconds(20)
while ([string]::IsNullOrEmpty($viceProc.MainWindowTitle) -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
    $viceProc.Refresh()
}
if ([string]::IsNullOrEmpty($viceProc.MainWindowTitle)) {
    Log "ERROR: VICE window did not appear within 20s"
    exit 1
}
Log "VICE window: '$($viceProc.MainWindowTitle)'"

# Give C64 time to boot + init (warp = very fast: 5s is very conservative)
Log "Waiting 5 seconds for C64 boot + program init..."
Start-Sleep -Seconds 5

# ── 2. Baseline screenshot (block view) ───────────────────────
$blockViewShot = "$OutDir\screenshot-block-view.png"
Take-Screenshot $blockViewShot
Log "Screenshot: block-view (baseline)"

# ── 3. Get window bounds (needed by Focus-ViceWindow) ─────────
$viceProc.Refresh()
$bounds = Get-WindowBounds $viceProc
Log ("Window: Win={0},{1} {2}x{3}  Client={4},{5} {6}x{7}" -f `
    $bounds.WinX, $bounds.WinY, $bounds.WinW, $bounds.WinH,
    $bounds.CliX, $bounds.CliY, $bounds.CliW, $bounds.CliH)
"$($bounds.CliX) $($bounds.CliY) $($bounds.CliW) $($bounds.CliH)" |
    Out-File -FilePath "$OutDir\window-bounds.txt" -Encoding ASCII

$interactionStart = Get-Date

# ── 4. SPACE -> add a block ────────────────────────────────────
# In STATE_PALETTE, SPACE/FIRE selects current palette item (default=0=SET BORDER).
# After add: program enters STATE_PROGRAM.
Log "Step 4: SPACE - add block from palette..."
Inject-ViceKey 0x20 "SPACE -> add palette item (PETSCII 20)"
Start-Sleep -Seconds 1

# ── 5. F1 -> run program (triggers codegen) ───────────────────
# In STATE_PROGRAM, F1 calls codegen_run (sets zp_asm_inst_count > 0)
# then JSR $5000. In warp mode this completes in microseconds real time.
Log "Step 5: F1 - run program / codegen..."
Inject-ViceKey 0x70 "F1 -> run program (PETSCII 85)"
Start-Sleep -Seconds 2

# ── 6. T -> enter ASM view ────────────────────────────────────
# VK_T (0x54) unshifted -> SDLK_t -> C64 T key -> PETSCII $54.
# state_program T-handler checks zp_last_key==$54 && zp_asm_inst_count>0.
Log "Step 6: T - enter ASM view..."
Inject-ViceKey 0x54 "T unshifted -> STATE_ASM_VIEW (PETSCII 54)"
Start-Sleep -Seconds 3

# ── 7. Screenshot: ASM view ───────────────────────────────────
$asmViewShot = "$OutDir\screenshot-asm-view.png"
Take-Screenshot $asmViewShot
Log "Screenshot: asm-view"

Start-Sleep -Seconds 2

# ── 8. T -> return to block view ──────────────────────────────
Log "Step 8: T - return to block view..."
Inject-ViceKey 0x54 "T -> exit STATE_ASM_VIEW -> previous state"
Start-Sleep -Seconds 2

# ── 9. Screenshot: return to block view ──────────────────────
$returnShot = "$OutDir\screenshot-return.png"
Take-Screenshot $returnShot
Log "Screenshot: return-to-block-view"

Start-Sleep -Seconds 1

# ── 10. Write trim timestamps ─────────────────────────────────
$recordingEnd = Get-Date
$dur = ($recordingEnd - $interactionStart).TotalSeconds
"0.5 $([math]::Round($dur + 1.5, 1))" |
    Out-File -FilePath "$OutDir\trim-times.txt" -Encoding ASCII

# ── 11. Stop VICE ─────────────────────────────────────────────
Log "Stopping VICE..."
if (-not $viceProc.HasExited) { $viceProc.Kill() }

Log "Done. Results in: $OutDir"
Log ("Trim window: 0.5s to {0}s" -f [math]::Round($dur + 1.5, 1))
