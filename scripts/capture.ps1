param(
    [string]$OutDir,
    [int]$DelayMs = 333      # ~3 fps
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$i = 0
while ($true) {
    try {
        $s   = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bmp = New-Object System.Drawing.Bitmap($s.Width, $s.Height)
        $g   = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen(0, 0, 0, 0, $s.Size)
        $path = "$OutDir\frame_$($i.ToString('D5')).png"
        $bmp.Save($path)
        $g.Dispose()
        $bmp.Dispose()
        $i++
    } catch {
        # ignore transient capture errors
    }
    Start-Sleep -Milliseconds $DelayMs
}
