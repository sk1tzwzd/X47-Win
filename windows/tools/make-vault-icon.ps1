# Draws the Vault icon (steel vault door, cyan accent) into tools\assets\vault.ico (16-256px, PNG-in-ICO).
[CmdletBinding()]
param([string]$Out = (Join-Path $PSScriptRoot 'assets\vault.ico'))
Add-Type -AssemblyName System.Drawing
$D = [System.Drawing.Drawing2D.LinearGradientBrush]

function New-VaultBitmap([int]$S) {
    $bmp = New-Object System.Drawing.Bitmap $S, $S
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'
    $k = $S / 256.0
    function Rect([double]$x, [double]$y, [double]$w, [double]$h) { New-Object System.Drawing.RectangleF ([float]($x * $k)), ([float]($y * $k)), ([float]($w * $k)), ([float]($h * $k)) }
    function Hex([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }

    # tile: dark rounded square
    $tile = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = 48 * $k; $e = 8 * $k; $w = $S - 2 * $e
    $tile.AddArc($e, $e, $r, $r, 180, 90); $tile.AddArc($e + $w - $r, $e, $r, $r, 270, 90)
    $tile.AddArc($e + $w - $r, $e + $w - $r, $r, $r, 0, 90); $tile.AddArc($e, $e + $w - $r, $r, $r, 90, 90); $tile.CloseFigure()
    $g.FillPath((New-Object $D (Rect 0 0 256 256), (Hex '#1f2530'), (Hex '#0a0d12'), 90), $tile)

    # hinges
    $hinge = New-Object System.Drawing.SolidBrush (Hex '#4b5563')
    $g.FillRectangle($hinge, (Rect 30 78 22 26)); $g.FillRectangle($hinge, (Rect 30 152 22 26))

    # door: steel ring
    $g.FillEllipse((New-Object $D (Rect 40 40 176 176), (Hex '#e5e9ef'), (Hex '#5b6472'), 45), (Rect 40 40 176 176))
    $g.FillEllipse((New-Object $D (Rect 54 54 148 148), (Hex '#3a4250'), (Hex '#9aa3b0'), 45), (Rect 54 54 148 148))
    # bolts
    $bolt = New-Object System.Drawing.SolidBrush (Hex '#2b313b')
    for ($i = 0; $i -lt 8; $i++) {
        $a = $i * [Math]::PI / 4
        $g.FillEllipse($bolt, (Rect (128 + 80 * [Math]::Cos($a) - 5) (128 + 80 * [Math]::Sin($a) - 5) 10 10))
    }
    # inner face + cyan glow ring
    $g.FillEllipse((New-Object $D (Rect 66 66 124 124), (Hex '#1a1f27'), (Hex '#2c3440'), 90), (Rect 66 66 124 124))
    $g.DrawEllipse((New-Object System.Drawing.Pen (Hex '#22d3ee'), ([float](6 * $k))), (Rect 72 72 112 112))

    # wheel handle: 3 spokes with knobs
    $spoke = New-Object System.Drawing.Pen (Hex '#d1d7df'), ([float](9 * $k)); $spoke.StartCap = 'Round'; $spoke.EndCap = 'Round'
    $knob = New-Object System.Drawing.SolidBrush (Hex '#e5e9ef')
    for ($i = 0; $i -lt 3; $i++) {
        $a = $i * [Math]::PI / 3 + [Math]::PI / 6
        $dx = 42 * [Math]::Cos($a); $dy = 42 * [Math]::Sin($a)
        $g.DrawLine($spoke, [float]((128 - $dx) * $k), [float]((128 - $dy) * $k), [float]((128 + $dx) * $k), [float]((128 + $dy) * $k))
        $g.FillEllipse($knob, (Rect (128 + $dx - 8) (128 + $dy - 8) 16 16)); $g.FillEllipse($knob, (Rect (128 - $dx - 8) (128 - $dy - 8) 16 16))
    }
    # hub
    $g.FillEllipse((New-Object $D (Rect 108 108 40 40), (Hex '#f3f6f9'), (Hex '#7c8693'), 45), (Rect 108 108 40 40))
    $g.FillEllipse((New-Object System.Drawing.SolidBrush (Hex '#22d3ee')), (Rect 121 121 14 14))
    $g.Dispose()
    $bmp
}

$sizes = 256, 64, 48, 32, 24, 16
$pngs = foreach ($s in $sizes) {
    $b = New-VaultBitmap $s; $ms = New-Object IO.MemoryStream
    $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose(); , $ms.ToArray()
}
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$fs = [IO.File]::Create($Out); $bw = New-Object IO.BinaryWriter $fs
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]; $dim = if ($s -ge 256) { 0 } else { $s }
    $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$pngs[$i].Length); $bw.Write([uint32]$offset)
    $offset += $pngs[$i].Length
}
foreach ($p in $pngs) { $bw.Write($p) }
$bw.Close()
# preview PNG for checking the design
$b = New-VaultBitmap 256; $b.Save([IO.Path]::ChangeExtension($Out, '.png'), [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
Write-Host "wrote $Out"
