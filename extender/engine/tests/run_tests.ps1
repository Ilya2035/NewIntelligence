<#
.SYNOPSIS
    Проверка загрузчика без игры: тестовая программа импортирует VERSION.dll, как eu5.exe,
    и лежит рядом с нашим version.dll. Три прогона: чужая сборка, «своя» сборка, выключатель.
#>
param(
    [string]$Gcc = (Join-Path $env:USERPROFILE 'Tools\w64devkit\bin\gcc.exe'),
    [string]$Work = (Join-Path $env:TEMP 'ni_engine_test')
)
$ErrorActionPreference = 'Stop'
$sac = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' -ErrorAction SilentlyContinue).VerifiedAndReputablePolicyState
if ($sac -eq 1) {
    Write-Host 'Включён «Интеллектуальный контроль приложений» Windows: он не даёт запустить свежесобранные неподписанные программы и DLL, тест невозможен.' -ForegroundColor Yellow
    exit 2
}
$here = $PSScriptRoot
$engine = Split-Path -Parent $here
if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force }
New-Item -ItemType Directory -Force -Path "$Work\app", "$Work\home" | Out-Null

& $Gcc -O2 -Wall -o "$Work\app\test_host.exe" (Join-Path $here 'test_host.c') -lversion
if ($LASTEXITCODE -ne 0) { throw 'test_host не собрался' }
$hostSha = (Get-FileHash "$Work\app\test_host.exe" -Algorithm SHA256).Hash
$fails = 0
function Check([bool]$Cond, [string]$What) {
    if ($Cond) { Write-Host "  [ok] $What" -ForegroundColor Green } else { Write-Host "  [!!] $What" -ForegroundColor Red; $script:fails++ }
}
function RunHost {
    $env:NI_ENGINE_HOME = "$Work\home"
    try { $o = & "$Work\app\test_host.exe" | Out-String; $code = $LASTEXITCODE } finally { Remove-Item Env:\NI_ENGINE_HOME }
    $log = if (Test-Path "$Work\home\engine.log") { [IO.File]::ReadAllText("$Work\home\engine.log") } else { '' }
    return [pscustomobject]@{ Out = $o; Code = $code; Log = $log }
}
$want = 'versions match'   # test_host сравнивает ответ через наш version.dll с прямым вызовом системного

Write-Host 'Прогон 1: загрузчик собран под другую сборку (как после обновления игры)' -ForegroundColor Cyan
& (Join-Path $engine 'build.ps1') -Gcc $Gcc -ExeSha256 ('0' * 64) -OutDir "$Work\build_other" | Out-Null
Copy-Item "$Work\build_other\version.dll" "$Work\app\version.dll"
$r = RunHost
Check ($r.Code -eq 0) 'тестовая программа отработала'
Check ($r.Out -match $want) "ответ через наш version.dll совпал с системным: $(($r.Out -split "`n")[0].Trim())"
Check ($r.Out -match [regex]::Escape("$Work\app\version.dll")) 'вызовы шли через наш version.dll'
Check ($r.Log -match 'forwarding: system version.dll loaded, 17 of 17') 'все 17 функций переданы системному version.dll'
Check ($r.Log -match 'other build .*inactive') 'на чужой сборке загрузчик ничего не делает'

Write-Host 'Прогон 2: загрузчик собран под эту программу (как под нужную сборку eu5.exe)' -ForegroundColor Cyan
& (Join-Path $engine 'build.ps1') -Gcc $Gcc -ExeSha256 $hostSha -OutDir "$Work\build_match" | Out-Null
Copy-Item "$Work\build_match\version.dll" "$Work\app\version.dll" -Force
Remove-Item "$Work\home\engine.log"
$r = RunHost
Check ($r.Code -eq 0) 'тестовая программа отработала'
Check ($r.Log -match "build matches \($hostSha\): active") 'своя сборка узнана'

Write-Host 'Прогон 3: выключатель engine_off' -ForegroundColor Cyan
New-Item -ItemType File -Path "$Work\home\engine_off" | Out-Null
Remove-Item "$Work\home\engine.log"
$r = RunHost
Check ($r.Code -eq 0 -and $r.Out -match $want) 'с выключателем вызовы всё равно передаются'
Check ($r.Log -match 'engine_off found' -and $r.Log -notmatch 'build matches') 'с выключателем ничего, кроме передачи, не запускается'

Write-Host ''
Write-Host "Журнал последнего прогона:`n$($r.Log)"
if ($fails) { Write-Host "Провалено проверок: $fails" -ForegroundColor Red; exit 1 }
Write-Host 'Все проверки пройдены' -ForegroundColor Green
