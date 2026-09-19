# Generate the full brand icon set from the root logo.png
# (ASCII-only on purpose: PowerShell 5.1 parses BOM-less UTF-8 as ANSI)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = "d:\openai-canvas\open-ai-canvas"
$src = Join-Path $root "logo.png"
$icons = Join-Path $root "web\public\icons"
New-Item -ItemType Directory -Force -Path $icons | Out-Null

# Brand navy sampled from the logo artwork (10,14,26)
$brandBg = [System.Drawing.Color]::FromArgb(255, 10, 14, 26)

function New-ResizedBitmap([System.Drawing.Image]$image, [int]$size, [System.Drawing.Color]$bg, [double]$scale) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.Clear($bg)
    $inner = [int][Math]::Floor($size * $scale)
    $offset = [int](($size - $inner) / 2)
    $g.DrawImage($image, $offset, $offset, $inner, $inner)
    $g.Dispose()
    return ,$bmp
}

$source = [System.Drawing.Image]::FromFile($src)

# 1) Site logo (keep the 1024 source, ~69KB)
Copy-Item $src (Join-Path $root "web\public\logo.png") -Force

# 2) Transparent square sizes
foreach ($s in @(16, 32, 48, 64, 96, 128, 256)) {
    $name = "favicon-" + $s + "x" + $s + ".png"
    $b = New-ResizedBitmap $source $s ([System.Drawing.Color]::Transparent) 1.0
    $b.Save((Join-Path $icons $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $b.Dispose()
}

# 3) apple-touch-icon: 180, opaque brand background (iOS), 92% scale
$b = New-ResizedBitmap $source 180 $brandBg 0.92
$b.Save((Join-Path $icons "apple-touch-icon.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$b.Dispose()

# 4) PWA "any" icons
foreach ($s in @(192, 512)) {
    $name = "icon-" + $s + ".png"
    $b = New-ResizedBitmap $source $s ([System.Drawing.Color]::Transparent) 1.0
    $b.Save((Join-Path $icons $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $b.Dispose()
}

# 5) PWA maskable icons: content inside the 80% safe zone
foreach ($s in @(192, 512)) {
    $name = "icon-maskable-" + $s + ".png"
    $b = New-ResizedBitmap $source $s $brandBg 0.80
    $b.Save((Join-Path $icons $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $b.Dispose()
}

$source.Dispose()

# 6) favicon.ico as PNG-in-ICO container (16/32/48)
$sizes = @(16, 32, 48)
$entries = @()
foreach ($s in $sizes) {
    $name = "favicon-" + $s + "x" + $s + ".png"
    $entries += , @([System.IO.File]::ReadAllBytes((Join-Path $icons $name)), $s)
}
$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)
$bw.Write([UInt16]0)
$bw.Write([UInt16]1)
$bw.Write([UInt16]$entries.Count)
$offset = 6 + 16 * $entries.Count
foreach ($e in $entries) {
    $bytes = $e[0]
    $dim = $e[1]
    $dimByte = [byte]$dim
    if ($dim -ge 256) { $dimByte = [byte]0 }
    $bw.Write($dimByte)
    $bw.Write($dimByte)
    $bw.Write([byte]0)
    $bw.Write([byte]0)
    $bw.Write([UInt16]1)
    $bw.Write([UInt16]32)
    $bw.Write([UInt32]$bytes.Length)
    $bw.Write([UInt32]$offset)
    $offset += $bytes.Length
}
foreach ($e in $entries) {
    $bw.Write($e[0])
}
$bw.Flush()
[System.IO.File]::WriteAllBytes((Join-Path $icons "favicon.ico"), $ms.ToArray())
$bw.Dispose()
$ms.Dispose()

Get-ChildItem $icons | Select-Object Name, Length | Format-Table -AutoSize
Write-Output "DONE"
