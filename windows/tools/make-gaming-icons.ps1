# Draws the Gaming Mode icons: tools\assets\gaming-off.ico (grey pad) and gaming-on.ico (lit, green glow).
. (Join-Path $PSScriptRoot 'lib\Icon.ps1')

function Draw-Pad($g, [int]$S, [double]$k, [bool]$On) {
    Add-IconTile $g $S $k
    $body1 = if ($On) { '#e8fff4' } else { '#b9c0ca' }
    $body2 = if ($On) { '#7ee8b5' } else { '#5d6672' }
    if ($On) {
        # glow halo behind the pad
        foreach ($i in 3, 2, 1) {
            $a = 16 * (4 - $i)
            $glow = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($a, 34, 255, 140))
            $g.FillEllipse($glow, (New-IconRect (34 - $i * 6) (86 - $i * 6) (188 + $i * 12) (124 + $i * 12) $k))
        }
    }
    # controller body: centre bar + two grips
    $pad = New-Object System.Drawing.Drawing2D.GraphicsPath
    $pad.AddEllipse((New-IconRect 34 92 92 112 $k)); $pad.AddEllipse((New-IconRect 130 92 92 112 $k))
    $pad.AddRectangle((New-IconRect 76 92 104 72 $k))
    $pad.FillMode = 'Winding'
    $g.FillPath((New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-IconRect 0 80 256 140 $k), (Get-Hex $body1), (Get-Hex $body2), 90), $pad)

    # d-pad
    $dark = New-Object System.Drawing.SolidBrush (Get-Hex '#1b2028')
    $g.FillRectangle($dark, (New-IconRect 66 114 14 42 $k)); $g.FillRectangle($dark, (New-IconRect 52 128 42 14 $k))
    # face buttons
    $cols = if ($On) { '#22d3ee', '#22ff8c', '#ff4d6d', '#ffd23f' } else { '#2b313b', '#2b313b', '#2b313b', '#2b313b' }
    $pos = @(@(172, 110), @(190, 128), @(154, 128), @(172, 146))
    for ($i = 0; $i -lt 4; $i++) {
        $g.FillEllipse((New-Object System.Drawing.SolidBrush (Get-Hex $cols[$i])), (New-IconRect $pos[$i][0] $pos[$i][1] 16 16 $k))
    }
    # thumbsticks
    $g.FillEllipse($dark, (New-IconRect 92 152 24 24 $k)); $g.FillEllipse($dark, (New-IconRect 140 152 24 24 $k))
    # status LED
    $led = if ($On) { '#22ff8c' } else { '#3a4250' }
    $g.FillEllipse((New-Object System.Drawing.SolidBrush (Get-Hex $led)), (New-IconRect 121 104 14 14 $k))
}

Save-Ico (Join-Path $PSScriptRoot 'assets\gaming-off.ico') { param($g, $S, $k) Draw-Pad $g $S $k $false }
Save-Ico (Join-Path $PSScriptRoot 'assets\gaming-on.ico') { param($g, $S, $k) Draw-Pad $g $S $k $true }
Write-Host 'wrote gaming-off.ico, gaming-on.ico'
