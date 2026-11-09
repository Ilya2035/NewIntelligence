<#
.SYNOPSIS
    Запрос к готовой карте движка (E2): NiEngineMap.java по сохранённому проекту Ghidra, без нового анализа.

.DESCRIPTION
    Запускать только после того, как analyze.ps1 закончил: пока идёт анализ, проект заперт.
    Темы: control, garrison, occupation, separatism, maintenance, ai или all.
    Результат - текстовый файл в %USERPROFILE%\Tools\ghidra_work\map\<тема>.txt.

.EXAMPLE
    .\query.ps1 -Topic control
#>
param(
    [string]$Topic = 'all',
    [string]$ProgramName = 'eu5_26377361.exe',
    [string]$MaxMem = '12G'
)
$ErrorActionPreference = 'Stop'
$tools = Join-Path $env:USERPROFILE 'Tools'
$work = Join-Path $tools 'ghidra_work'
$env:JAVA_HOME = Join-Path $tools 'jdk-25.0.5+8'
$env:GHIDRA_HEADLESS_MAXMEM = $MaxMem
# как в analyze.ps1: настройки и кэш Ghidra вне AppData (перенаправление MSIX у Claude Desktop)
$env:XDG_CONFIG_HOME = Join-Path $work 'settings'
$env:XDG_CACHE_HOME = Join-Path $work 'cache'
if (-not (Test-Path (Join-Path $work 'eu5.gpr'))) { throw "Проекта Ghidra нет: сначала analyze.ps1" }
if (Get-CimInstance Win32_Process -Filter "Name = 'java.exe'" | Where-Object { $_.CommandLine -match 'ghidra' }) {
    throw 'Ghidra ещё работает (анализ не закончен или идёт другой запрос): проект заперт'
}
$mapDir = Join-Path $work 'map'
New-Item -ItemType Directory -Force -Path $mapDir | Out-Null
$outFile = Join-Path $mapDir "$Topic.txt"
$bat = Join-Path $tools 'ghidra_12.2_PUBLIC\support\analyzeHeadless.bat'
$argList = @($work, 'eu5', '-process', $ProgramName, '-noanalysis', '-readOnly',
    '-scriptPath', $PSScriptRoot, '-postScript', 'NiEngineMap.java', $Topic, $outFile,
    '-log', (Join-Path $mapDir "$Topic.log"), '-scriptlog', (Join-Path $mapDir "$Topic.script.log"))
$p = Start-Process -FilePath $bat -ArgumentList $argList -PassThru -NoNewWindow -Wait `
    -RedirectStandardOutput (Join-Path $mapDir "$Topic.console.log") -RedirectStandardError (Join-Path $mapDir "$Topic.console.err")
if ($p.ExitCode -ne 0 -or -not (Test-Path $outFile)) { throw "Запрос не удался, код $($p.ExitCode): смотри $mapDir\$Topic.console.log" }
Write-Host "Карта по теме «$Topic»: $outFile"
