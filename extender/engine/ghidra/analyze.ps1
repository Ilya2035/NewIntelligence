<#
.SYNOPSIS
    Карта движка (E2): разовый разбор КОПИИ eu5.exe в Ghidra без окна.

.DESCRIPTION
    Проект Ghidra - в %USERPROFILE%\Tools\ghidra_work\eu5.gpr.
    Журналы: ghidra_work\analysis.log (ход разбора), script.log (настройки анализаторов).
    Приоритет Java всегда ниже обычного: свободные ядра она берёт целиком, но уступает всему, что
    запущено рядом (Claude, Steam), поэтому компьютер не замирает.
    Прогон 1 (2026-11-09): 4 потока, 12 ГБ - бережно, но слишком медленно.
    Прогон 2 (по просьбе автора: «все мощности, 20 % оставить нам»): 26 потоков из 32, 18 ГБ памяти
    из 31, без медленной починки кода после невозвращающих функций (NiPreAnalysis.java).

.EXAMPLE
    .\analyze.ps1 -Exe C:\Users\fyrno\Tools\ghidra_work\eu5_26377361.exe -MaxCpu 26 -MaxMem 18G
#>
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [int]$MaxCpu = 4,
    [string]$MaxMem = '12G'
)
$ErrorActionPreference = 'Stop'
$tools = Join-Path $env:USERPROFILE 'Tools'
$work = Join-Path $tools 'ghidra_work'
$env:JAVA_HOME = Join-Path $tools 'jdk-25.0.5+8'
$env:GHIDRA_HEADLESS_MAXMEM = $MaxMem
# Настройки и кэш Ghidra - вне AppData. Процессы, запущенные из упакованного (MSIX) приложения
# вроде Claude Desktop, пишут в AppData\Roaming через перенаправление в AppData\Local\Packages\...,
# и модуль сценариев Ghidra (OSGi Felix) падает: «The data file must be inside the data dir».
$env:XDG_CONFIG_HOME = Join-Path $work 'settings'
$env:XDG_CACHE_HOME = Join-Path $work 'cache'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$bat = Join-Path $tools 'ghidra_12.2_PUBLIC\support\analyzeHeadless.bat'
$argList = @($work, 'eu5', '-import', $Exe, '-overwrite', '-max-cpu', "$MaxCpu",
    '-scriptPath', $PSScriptRoot, '-preScript', 'NiPreAnalysis.java',
    '-log', (Join-Path $work 'analysis.log'), '-scriptlog', (Join-Path $work 'script.log'))
$p = Start-Process -FilePath $bat -ArgumentList $argList -PassThru -NoNewWindow `
    -RedirectStandardOutput (Join-Path $work 'console.log') -RedirectStandardError (Join-Path $work 'console.err')
try { $p.PriorityClass = 'BelowNormal' } catch { }

# Java запускается из bat-файла чуть позже: ждём её до 2 минут и тоже ставим низкий приоритет.
# Дочерние процессы (decompile.exe) унаследуют его, потому что запустятся уже от неё.
for ($i = 0; $i -lt 60 -and -not $p.HasExited; $i++) {
    $java = @(Get-CimInstance Win32_Process -Filter "Name = 'java.exe'" | Where-Object { $_.CommandLine -match 'ghidra' })
    if ($java.Count) {
        foreach ($j in $java) { try { (Get-Process -Id $j.ProcessId).PriorityClass = 'BelowNormal' } catch { } }
        Write-Host "Ghidra запущена (java pid $($java[0].ProcessId)), потоков $MaxCpu, память $MaxMem, приоритет ниже обычного"
        break
    }
    Start-Sleep -Seconds 2
}
$p.WaitForExit()
Write-Host "Разбор закончен, код $($p.ExitCode)"
exit $p.ExitCode
