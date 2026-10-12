# Icon helpers for ops scripts: draw at any size with System.Drawing, save as multi-size PNG-in-ICO.
#   Save-Ico -Out x.ico -Draw { param($g, $S, $k) ... }   # $g Graphics, $S pixel size, $k = S/256 scale
Add-Type -AssemblyName System.Drawing

function New-IconRect([double]$x, [double]$y, [double]$w, [double]$h, [double]$k) {
    New-Object System.Drawing.RectangleF ([float]($x * $k)), ([float]($y * $k)), ([float]($w * $k)), ([float]($h * $k))
}
function Get-Hex([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }

# Dark rounded-square tile shared by all X47 icons.
function Add-IconTile($g, [int]$S, [double]$k) {
    $tile = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = 48 * $k; $e = 8 * $k; $w = $S - 2 * $e
    $tile.AddArc($e, $e, $r, $r, 180, 90); $tile.AddArc($e + $w - $r, $e, $r, $r, 270, 90)
    $tile.AddArc($e + $w - $r, $e + $w - $r, $r, $r, 0, 90); $tile.AddArc($e, $e + $w - $r, $r, $r, 90, 90); $tile.CloseFigure()
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-IconRect 0 0 256 256 $k), (Get-Hex '#1f2530'), (Get-Hex '#0a0d12'), 90
    $g.FillPath($br, $tile)
}

function Save-Ico([string]$Out, [scriptblock]$Draw) {
    $sizes = 256, 64, 48, 32, 24, 16
    $pngs = foreach ($s in $sizes) {
        $bmp = New-Object System.Drawing.Bitmap $s, $s
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = 'AntiAlias'; $g.PixelOffsetMode = 'HighQuality'
        & $Draw $g $s ($s / 256.0)
        $g.Dispose()
        $ms = New-Object IO.MemoryStream
        $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        if ($s -eq 256) { $bmp.Save([IO.Path]::ChangeExtension($Out, '.png'), [System.Drawing.Imaging.ImageFormat]::Png) }  # preview
        $bmp.Dispose(); , $ms.ToArray()
    }
    New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
    $fs = [IO.File]::Create($Out); $bw = New-Object IO.BinaryWriter $fs
    $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
        $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$pngs[$i].Length); $bw.Write([uint32]$offset)
        $offset += $pngs[$i].Length
    }
    foreach ($p in $pngs) { $bw.Write($p) }
    $bw.Close()
}
