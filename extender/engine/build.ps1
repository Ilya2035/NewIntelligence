<#
.SYNOPSIS
    Собирает загрузчик движка (version.dll) под текущую сборку eu5.exe.

.DESCRIPTION
    Хэш eu5.exe берётся из "NewIntelligence.ps1 status -Json" (или -ExeSha256) и вшивается в DLL:
    на другой сборке игры загрузчик только передаёт вызовы системному version.dll и ничего не делает.
    Рядом с DLL пишется version.dll.json - по нему расширение решает, ставить ли файл (apply).

.EXAMPLE
    .\build.ps1
#>
param(
    [string]$Gcc = (Join-Path $env:USERPROFILE 'Tools\w64devkit\bin\gcc.exe'),
    [string]$ExeSha256,
    [string]$OutDir
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
if (-not $OutDir) { $OutDir = Join-Path $here 'bin' }
if (-not (Test-Path -LiteralPath $Gcc)) {
    $g = Get-Command gcc -ErrorAction SilentlyContinue
    if ($g) { $Gcc = $g.Source } else { throw "Нет компилятора: $Gcc (w64devkit)" }
}

$build = $null; $ver = $null
if (-not $ExeSha256) {
    $ext = Join-Path (Split-Path -Parent $here) 'NewIntelligence.ps1'
    $st = (& powershell -NoProfile -ExecutionPolicy Bypass -File $ext status -Json | Out-String) | ConvertFrom-Json
    if ($st.error) { throw $st.error }
    $ExeSha256 = $st.exe_sha256; $build = $st.build_id; $ver = $st.game_version
}
if ($ExeSha256 -notmatch '^[0-9A-Fa-f]{64}$') { throw "Неверный хэш eu5.exe: $ExeSha256" }
$ExeSha256 = $ExeSha256.ToUpperInvariant()

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$cfg = Join-Path $OutDir 'ni_build_config.h'
[IO.File]::WriteAllText($cfg, "#define NI_EXPECTED_SHA256 `"$ExeSha256`"`r`n", (New-Object Text.UTF8Encoding($false)))
$dll = Join-Path $OutDir 'version.dll'
& $Gcc -O2 -s -shared -Wall -Wextra -Wno-unused-parameter -Wno-cast-function-type -include $cfg -o $dll `
    (Join-Path $here 'loader\version_proxy.c') (Join-Path $here 'loader\version.def') `
    -lbcrypt -static-libgcc '-Wl,--no-insert-timestamp'
if ($LASTEXITCODE -ne 0) { throw 'Сборка не удалась.' }
Remove-Item -LiteralPath $cfg

$meta = [ordered]@{
    file           = 'version.dll'
    stage          = 'E1'
    loader_version = '0.1.0'
    exe_sha256     = @($ExeSha256)
    build_id       = $build
    game_version   = $ver
    built          = (Get-Date).ToString('s')
    sha256         = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash
}
[IO.File]::WriteAllText("$dll.json", ($meta | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($false)))
Write-Host "собрано: $dll ($((Get-Item -LiteralPath $dll).Length) байт) для eu5.exe $($ExeSha256.Substring(0, 16))..." -ForegroundColor Green
