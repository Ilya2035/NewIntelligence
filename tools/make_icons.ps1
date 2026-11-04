# Generates the New Intelligence: Battle icons as uncompressed 32-bit BGRA DDS files with mipmaps.
# Usage (PowerShell, from the repo root):  powershell -ExecutionPolicy Bypass -File tools\make_icons.ps1
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..\mods\new_intelligence_battle\main_menu\gfx\interface\icons'

function Write-Dds([System.Drawing.Bitmap]$bmp, [string]$path) {
    $levels = New-Object System.Collections.Generic.List[byte[]]
    $w = $bmp.Width; $h = $bmp.Height; $cur = $bmp
    while ($true) {
        $rect = New-Object System.Drawing.Rectangle 0, 0, $cur.Width, $cur.Height
        $data = $cur.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $bytes = New-Object byte[] ($cur.Width * $cur.Height * 4)
        for ($y = 0; $y -lt $cur.Height; $y++) {
            [System.Runtime.InteropServices.Marshal]::Copy([IntPtr]($data.Scan0.ToInt64() + $y * $data.Stride), $bytes, $y * $cur.Width * 4, $cur.Width * 4)
        }
        $cur.UnlockBits($data)
        $levels.Add($bytes)
        if ($cur.Width -le 1 -and $cur.Height -le 1) { break }
        $nw = [Math]::Max(1, [int]($cur.Width / 2)); $nh = [Math]::Max(1, [int]($cur.Height / 2))
        $next = New-Object System.Drawing.Bitmap $nw, $nh, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($next)
        $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'; $g.CompositingMode = 'SourceCopy'
        $g.DrawImage($cur, 0, 0, $nw, $nh); $g.Dispose()
        $cur = $next
    }
    $fs = [System.IO.File]::Create($path); $bw = New-Object System.IO.BinaryWriter $fs
    $bw.Write([byte[]][char[]]'DDS ')
    $bw.Write([uint32]124); $bw.Write([uint32]0x2100F); $bw.Write([uint32]$h); $bw.Write([uint32]$w)
    $bw.Write([uint32]($w * 4)); $bw.Write([uint32]0); $bw.Write([uint32]$levels.Count)
    for ($i = 0; $i -lt 11; $i++) { $bw.Write([uint32]0) }
    $bw.Write([uint32]32); $bw.Write([uint32]0x41); $bw.Write([uint32]0); $bw.Write([uint32]32)
    $bw.Write([uint32]0x00FF0000); $bw.Write([uint32]0x0000FF00); $bw.Write([uint32]0x000000FF); $bw.Write([uint32]4278190080)  # alpha mask 0xFF000000 (PowerShell 5.1 reads that literal as a negative int32)
    $bw.Write([uint32]0x401008); $bw.Write([uint32]0); $bw.Write([uint32]0); $bw.Write([uint32]0); $bw.Write([uint32]0)
    foreach ($l in $levels) { $bw.Write($l) }
    $bw.Close(); $fs.Close()
}

function New-Icon([int]$size, [scriptblock]$draw) {
    $bmp = New-Object System.Drawing.Bitmap 256, 256, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.Clear([System.Drawing.Color]::Transparent)
    & $draw $g
    $g.Dispose()
    $out = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g2 = [System.Drawing.Graphics]::FromImage($out)
    $g2.InterpolationMode = 'HighQualityBicubic'; $g2.PixelOffsetMode = 'HighQuality'; $g2.CompositingMode = 'SourceCopy'
    $g2.DrawImage($bmp, 0, 0, $size, $size); $g2.Dispose(); $bmp.Dispose()
    return $out
}

$gold = [System.Drawing.Color]::FromArgb(255, 222, 184, 92)
$goldDark = [System.Drawing.Color]::FromArgb(255, 120, 86, 30)
$red = [System.Drawing.Color]::FromArgb(255, 150, 32, 28)
$ink = [System.Drawing.Color]::FromArgb(255, 34, 24, 16)
$steel = [System.Drawing.Color]::FromArgb(255, 226, 228, 232)
function P([System.Drawing.Color]$c, [float]$w) { $p = New-Object System.Drawing.Pen $c, $w; $p.LineJoin = 'Round'; $p.StartCap = 'Round'; $p.EndCap = 'Round'; return $p }
function B([System.Drawing.Color]$c) { return New-Object System.Drawing.SolidBrush $c }
function Pts([int[]]$xy) { $l = @(); for ($i = 0; $i -lt $xy.Length; $i += 2) { $l += New-Object System.Drawing.PointF $xy[$i], $xy[$i+1] }; return [System.Drawing.PointF[]]$l }
function Star($g, [float]$cx, [float]$cy, [float]$r, $brush) {
    $p = @(); for ($i = 0; $i -lt 10; $i++) { $a = -[Math]::PI / 2 + $i * [Math]::PI / 5; $rr = if ($i % 2 -eq 0) { $r } else { $r * 0.42 }; $p += New-Object System.Drawing.PointF ($cx + $rr * [Math]::Cos($a)), ($cy + $rr * [Math]::Sin($a)) }
    $g.FillPolygon($brush, [System.Drawing.PointF[]]$p)
}

# Headquarters: a staff banner on a pole with a gold star, over a dark disc
$hq = {
    param($g)
    $g.FillEllipse((B ([System.Drawing.Color]::FromArgb(200, 28, 20, 14))), 14, 14, 228, 228)
    $g.DrawEllipse((P $gold 8), 14, 14, 228, 228)
    $g.DrawLine((P $ink 18), 84, 40, 84, 222)
    $g.DrawLine((P $gold 10), 84, 40, 84, 222)
    $flag = Pts @(90,48, 206,62, 178,100, 206,138, 90,128)
    $g.FillPolygon((B $red), $flag); $g.DrawPolygon((P $gold 6), $flag)
    Star $g 138 92 26 (B $gold)
    $g.FillEllipse((B $gold), 72, 26, 24, 24)
}
# Order: stay with the main army - two shields side by side under a banner
$escort = {
    param($g)
    $g.FillEllipse((B ([System.Drawing.Color]::FromArgb(200, 28, 20, 14))), 14, 14, 228, 228)
    $g.DrawEllipse((P $gold 8), 14, 14, 228, 228)
    foreach ($dx in @(-38, 38)) {
        $s = Pts @((128+$dx-34),92, (128+$dx+34),92, (128+$dx+30),150, (128+$dx),186, (128+$dx-30),150)
        $g.FillPolygon((B $red), $s); $g.DrawPolygon((P $gold 6), $s)
    }
    $g.DrawLine((P $gold 8), 128, 40, 128, 92)
    $g.FillPolygon((B $gold), (Pts @(132,42, 176,54, 132,68)))
}
# Order: harass - a dagger striking diagonally
$harass = {
    param($g)
    $g.FillEllipse((B ([System.Drawing.Color]::FromArgb(200, 28, 20, 14))), 14, 14, 228, 228)
    $g.DrawEllipse((P $gold 8), 14, 14, 228, 228)
    $blade = Pts @(70,186, 176,64, 190,50, 184,80, 86,198)
    $g.FillPolygon((B $steel), $blade); $g.DrawPolygon((P $ink 4), $blade)
    $g.DrawLine((P $gold 14), 56, 156, 104, 204)
    $g.DrawLine((P $goldDark 16), 74, 186, 46, 214)
    $g.FillEllipse((B $gold), 34, 202, 22, 22)
}
# Order: own sector - a map pin with a flag
$theater = {
    param($g)
    $g.FillEllipse((B ([System.Drawing.Color]::FromArgb(200, 28, 20, 14))), 14, 14, 228, 228)
    $g.DrawEllipse((P $gold 8), 14, 14, 228, 228)
    $g.DrawEllipse((P $goldDark 6), 54, 150, 148, 50)
    $pin = Pts @(128,198, 92,118, 100,92, 128,78, 156,92, 164,118)
    $g.FillPolygon((B $red), $pin); $g.DrawPolygon((P $gold 6), $pin)
    $g.FillEllipse((B $gold), 114, 100, 28, 28)
}
# Order: defend own land - a shield with a castle tower
$defend = {
    param($g)
    $g.FillEllipse((B ([System.Drawing.Color]::FromArgb(200, 28, 20, 14))), 14, 14, 228, 228)
    $g.DrawEllipse((P $gold 8), 14, 14, 228, 228)
    $s = Pts @(64,52, 192,52, 186,140, 128,208, 70,140)
    $g.FillPolygon((B $red), $s); $g.DrawPolygon((P $gold 7), $s)
    $tower = Pts @(98,150, 98,96, 108,96, 108,84, 120,84, 120,96, 136,96, 136,84, 148,84, 148,96, 158,96, 158,150)
    $g.FillPolygon((B $gold), $tower)
    $g.FillRectangle((B $ink), 120, 124, 16, 26)
}

$targets = @(
    @{ draw = $hq;      size = 128; path = 'unit_category\army_headquarters.dds' },
    @{ draw = $hq;      size = 128; path = 'unit_battle_category\army_headquarters.dds' },
    @{ draw = $hq;      size = 64;  path = 'text_icons\army_headquarters.dds' },
    @{ draw = $hq;      size = 128; path = 'cw\cw_hq.dds' },
    @{ draw = $escort;  size = 128; path = 'military_stances\cw_escort_military_stance.dds' },
    @{ draw = $harass;  size = 128; path = 'military_stances\cw_harass_military_stance.dds' },
    @{ draw = $theater; size = 128; path = 'military_stances\cw_own_theater_military_stance.dds' },
    @{ draw = $defend;  size = 128; path = 'military_stances\cw_defend_home_military_stance.dds' }
)
foreach ($t in $targets) {
    $p = Join-Path $root $t.path
    New-Item -ItemType Directory -Force -Path (Split-Path $p) | Out-Null
    $bmp = New-Icon $t.size $t.draw
    Write-Dds $bmp $p
    # PNG previews for review (not loaded by the game)
    $prev = Join-Path $PSScriptRoot ('cache\icons_preview\' + ($t.path -replace '[\\/]', '_') -replace '\.dds$', '.png')
    New-Item -ItemType Directory -Force -Path (Split-Path $prev) | Out-Null
    $bmp.Save($prev, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    Write-Output ("{0,-55} {1,7} bytes" -f $t.path, (Get-Item $p).Length)
}
