<#
.SYNOPSIS
    New Intelligence - личная программа-расширение для Europa Universalis V.

.DESCRIPTION
    Версия 0.1 - установщик и страж игры. Ставит моды New Intelligence, делает резервные
    копии, снимает отпечаток заводских файлов движка, проверяет целостность, возвращает игру
    к заводскому состоянию и собирает наше состояние обратно, собирает отчёт из журналов.

    Никогда не делает: не трогает папку game\dlc и владение DLC, Steam, достижения,
    сохранения и мультиплеер; ничего не скачивает; ничего не прячет от игры.

    Команды:
      status    что стоит: игра, сборка, моды, чит-мод, движок, целостность
      backup    резервная копия модов, playsets.json и состояния программы
      snapshot  отпечаток заводских файлов движка (binaries) и сводка DLC для этой сборки
      verify    сверить файлы движка с отпечатком; с -Steam ещё и запустить проверку Steam
      factory   вернуть игру к заводскому состоянию (наши моды выключаются, правки движка убираются)
      apply     собрать наше состояние (моды на месте и включены, чит-мод включён, правки движка)
      report    отчёт для разбора: какие моды загрузились, ошибки наших модов, строки GP_REPORT
      menu      меню для запуска двойным щелчком (по умолчанию)

.EXAMPLE
    .\NewIntelligence.ps1 status
    .\NewIntelligence.ps1 factory -RemoveMods
    .\NewIntelligence.ps1 apply
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('menu', 'status', 'backup', 'snapshot', 'verify', 'factory', 'apply', 'report')]
    [string]$Command = 'menu',
    [switch]$Json,        # вывод status и verify в JSON
    [switch]$RemoveMods,  # factory: ещё и убрать папки модов из mod\ (у ссылки убирается только ссылка)
    [switch]$Copy,        # apply: копировать моды, а не ставить ссылку на репозиторий
    [switch]$Steam,       # verify и factory: запустить проверку файлов игры в Steam
    [switch]$DryRun,      # показать, что будет сделано, ничего не меняя
    [switch]$Force,       # snapshot: перезаписать отпечаток
    [switch]$Sandbox,     # проверка программы на поддельных папках (нужны -GameDir, -UserDir, -HomeDir)
    [string]$GameDir,
    [string]$UserDir,
    [string]$HomeDir,
    [string]$RepoDir
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object Text.UTF8Encoding($false) } catch { }
# Windows PowerShell 5.1 иногда пишет массивы в JSON как {"value":[...],"Count":n}; это убирает ошибку
Remove-TypeData -TypeName System.Array -ErrorAction SilentlyContinue

$ExtVersion = '0.1.0'
$AppId = '3450310'
$Utf8 = New-Object Text.UTF8Encoding($false)
$Warnings = New-Object Collections.ArrayList

# ---------------------------------------------------------------- вывод

function Say([string]$Text = '', [string]$Color = 'Gray') { if (-not $Json) { Write-Host $Text -ForegroundColor $Color } }
function Head([string]$Text) { Say ''; Say $Text 'Cyan' }
function Good([string]$Text) { Say "  [ok] $Text" 'Green' }
function Note([string]$Text) { Say "  [..] $Text" 'Gray' }
function Warn([string]$Text) { [void]$Warnings.Add($Text); Say "  [!!] $Text" 'Yellow' }

# ---------------------------------------------------------------- файлы

function Read-JsonFile([string]$Path) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $null }
    $text = [IO.File]::ReadAllText($Path, $Utf8)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    if (-not $text.Trim()) { return $null }
    return ($text | ConvertFrom-Json)
}

function Write-JsonFile([string]$Path, $Object) {
    Assert-Writable $Path
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [IO.File]::WriteAllText($Path, ($Object | ConvertTo-Json -Depth 30), $Utf8)
}

function Open-Shared([string]$Path) {
    # журналы игры открыты самой игрой: читаем, не мешая ей писать
    return [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]'ReadWrite, Delete')
}

function Read-Head([string]$Path, [int]$Bytes) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $fs = Open-Shared $Path
    try {
        $n = [int][Math]::Min([long]$Bytes, $fs.Length)
        $buf = New-Object byte[] $n
        $read = 0
        while ($read -lt $n) { $k = $fs.Read($buf, $read, $n - $read); if ($k -le 0) { break }; $read += $k }
        return $Utf8.GetString($buf, 0, $read)
    } finally { $fs.Dispose() }
}

function Select-SharedLines([string]$Path, [string]$Pattern) {
    $out = New-Object Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $Path)) { return ,$out }
    $rx = New-Object Text.RegularExpressions.Regex($Pattern, [Text.RegularExpressions.RegexOptions]::Compiled)
    $sr = New-Object IO.StreamReader((Open-Shared $Path), $Utf8)
    try {
        while ($null -ne ($line = $sr.ReadLine())) { if ($rx.IsMatch($line)) { $out.Add($line) } }
    } finally { $sr.Dispose() }
    return ,$out
}

function Get-Sha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

function Test-Under([string]$Path, [string]$Root) {
    $p = [IO.Path]::GetFullPath($Path).TrimEnd('\') + '\'
    $r = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    return $p.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)
}

# Единственный страж записи: программа пишет только в mod\, в playsets.json, в свою папку
# и в файлы движка, перечисленные в ni_profile.json. Данные игры, DLC и сохранения - никогда.
function Assert-Writable([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    if ($G -and (Test-Under $full (Join-Path $G.Dir 'game'))) { throw "Запрещено: запись в данные игры ($full)" }
    if (Test-Under $full (Join-Path $P.User 'save games')) { throw "Запрещено: сохранения ($full)" }
    if ($full -ieq (Join-Path $P.User 'dlc_signature')) { throw "Запрещено: dlc_signature" }
    $ok = (Test-Under $full $P.Home) -or (Test-Under $full $P.ModDir) -or ($full -ieq $P.Playsets)
    if (-not $ok -and $G) {
        foreach ($f in @($Prof.engine.files | Where-Object { $_ })) {
            if ($full -ieq (Join-Path $G.Dir "binaries\$($f.file)")) { $ok = $true }
        }
    }
    if (-not $ok) { throw "Запрещено: запись вне разрешённых мест ($full)" }
}

# ---------------------------------------------------------------- поиск игры и папок

function Resolve-Paths {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $u = if ($UserDir) { $UserDir } else { Join-Path $docs 'Paradox Interactive\Europa Universalis V' }
    $h = if ($HomeDir) { $HomeDir } else { Join-Path $docs 'NewIntelligence' }
    $r = if ($RepoDir) { $RepoDir } else { Split-Path -Parent $PSScriptRoot }
    $u = [IO.Path]::GetFullPath($u).TrimEnd('\')
    $h = [IO.Path]::GetFullPath($h).TrimEnd('\')
    return [pscustomobject]@{
        User      = $u
        ModDir    = Join-Path $u 'mod'
        Playsets  = Join-Path $u 'playsets.json'
        Logs      = Join-Path $u 'logs'
        Home      = $h
        Backups   = Join-Path $h 'backups'
        Baselines = Join-Path $h 'baseline'
        Originals = Join-Path $h 'originals'
        Reports   = Join-Path $h 'reports'
        State     = Join-Path $h 'state.json'
        Repo      = [IO.Path]::GetFullPath($r).TrimEnd('\')
    }
}

function Get-SteamRoot {
    foreach ($k in 'HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam') {
        $p = Get-ItemProperty -Path $k -ErrorAction SilentlyContinue
        if (-not $p) { continue }
        foreach ($n in 'SteamPath', 'InstallPath') {
            $v = $p.$n
            if ($v -and (Test-Path -LiteralPath $v)) { return [IO.Path]::GetFullPath($v) }
        }
    }
    return $null
}

function Get-SteamLibraries {
    $root = Get-SteamRoot
    if (-not $root) { return @() }
    $libs = New-Object Collections.ArrayList
    $vdf = Join-Path $root 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"')) {
            $lp = $m.Groups[1].Value.Replace('\\', '\')
            if ((Test-Path -LiteralPath $lp) -and -not ($libs -contains $lp)) { [void]$libs.Add($lp) }
        }
    }
    if (-not ($libs -contains $root)) { [void]$libs.Add($root) }
    return $libs.ToArray()
}

function Find-Game {
    $dir = $null; $lib = $null; $man = $null
    if ($GameDir) {
        $dir = [IO.Path]::GetFullPath($GameDir).TrimEnd('\')
        $cand = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $dir))
        $m = Join-Path $cand "steamapps\appmanifest_$AppId.acf"
        if (Test-Path -LiteralPath $m) { $lib = $cand; $man = $m }
    } else {
        foreach ($l in Get-SteamLibraries) {
            $m = Join-Path $l "steamapps\appmanifest_$AppId.acf"
            if (-not (Test-Path -LiteralPath $m)) { continue }
            $inst = [regex]::Match([IO.File]::ReadAllText($m), '"installdir"\s+"([^"]+)"').Groups[1].Value
            $d = Join-Path $l "steamapps\common\$inst"
            if (Test-Path -LiteralPath (Join-Path $d 'binaries\eu5.exe')) { $dir = $d; $lib = $l; $man = $m; break }
        }
    }
    if (-not $dir -or -not (Test-Path -LiteralPath (Join-Path $dir 'binaries\eu5.exe'))) {
        throw 'Игра EU5 не найдена. Укажите папку: -GameDir "...\steamapps\common\Europa Universalis V"'
    }
    $build = $null
    if ($man) { $build = [regex]::Match([IO.File]::ReadAllText($man), '"buildid"\s+"(\d+)"').Groups[1].Value }
    return [pscustomobject]@{ Dir = $dir; Library = $lib; Manifest = $man; BuildId = $build }
}

function Test-GameRunning {
    if ($Sandbox) { return $false }
    return [bool](Get-Process -Name eu5 -ErrorAction SilentlyContinue)
}

function Assert-GameClosed {
    if (Test-GameRunning) { throw 'Игра запущена. Закройте EU5 и повторите: пока игра открыта, программа ничего не меняет.' }
}

function Get-LastRunInfo {
    $log = Join-Path $P.Logs 'debug.log'
    $head = Read-Head $log 4MB
    $ver = [regex]::Match($head, 'matched game version ([0-9]+(?:\.[0-9]+)+)').Groups[1].Value
    $mods = @([regex]::Matches($head, 'Mod (.+?) \(([^()]+)\) version \S+ successfully matched') |
        ForEach-Object { [pscustomobject]@{ Name = $_.Groups[1].Value; Id = $_.Groups[2].Value } })
    $time = $null
    if (Test-Path -LiteralPath $log) { $time = (Get-Item -LiteralPath $log).LastWriteTime.ToString('yyyy-MM-dd HH:mm') }
    return [pscustomobject]@{ GameVersion = $ver; LoadedMods = $mods; LogTime = $time }
}

# ---------------------------------------------------------------- моды и сборки модов

function Get-LinkInfo([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return [pscustomobject]@{ Exists = $false; Kind = 'missing'; Target = $null } }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        return [pscustomobject]@{ Exists = $true; Kind = 'link'; Target = (@($item.Target) | Select-Object -First 1) }
    }
    return [pscustomobject]@{ Exists = $true; Kind = 'folder'; Target = $null }
}

function Get-ModEntryPath([string]$Folder) { return ((Join-Path $P.ModDir $Folder) -replace '\\', '/') + '/' }
function ConvertTo-ModKey([string]$Path) { return ($Path -replace '\\', '/').TrimEnd('/').ToLowerInvariant() }

function Get-ActivePlayset($Doc) {
    if (-not $Doc) { return $null }
    $act = @($Doc.playsets | Where-Object { $_.isActive -eq $true }) | Select-Object -First 1
    if (-not $act) { $act = @($Doc.playsets) | Select-Object -First 1 }
    return $act
}

function Get-WorkshopDir([string]$Id) {
    if (-not $G.Library) { return $null }
    return Join-Path $G.Library "steamapps\workshop\content\$AppId\$Id"
}

function Get-ModsState($Doc) {
    $act = Get-ActivePlayset $Doc
    foreach ($m in @($Prof.mods)) {
        $dir = Join-Path $P.ModDir $m.folder
        $li = Get-LinkInfo $dir
        $meta = $null
        if ($li.Exists) { $meta = Read-JsonFile (Join-Path $dir '.metadata\metadata.json') }
        $want = ConvertTo-ModKey (Get-ModEntryPath $m.folder)
        $entry = $null
        if ($act) { $entry = @($act.orderedListMods) | Where-Object { $_ -and (ConvertTo-ModKey $_.path) -eq $want } | Select-Object -First 1 }
        [pscustomobject]@{
            Folder    = $m.folder
            Name      = $(if ($meta) { $meta.name } else { $m.folder })
            Version   = $(if ($meta) { $meta.version } else { '' })
            Kind      = $li.Kind
            Target    = $li.Target
            InPlayset = [bool]$entry
            Enabled   = [bool]($entry -and $entry.isEnabled)
        }
    }
}

function Get-RequiredModsState($Doc) {
    $act = Get-ActivePlayset $Doc
    foreach ($r in @($Prof.required_mods | Where-Object { $_ })) {
        $dir = Get-WorkshopDir $r.workshop_id
        $entry = $null
        if ($act) {
            $suffix = "/content/$AppId/$($r.workshop_id)"
            $entry = @($act.orderedListMods) | Where-Object { $_ -and (ConvertTo-ModKey $_.path).EndsWith($suffix) } | Select-Object -First 1
        }
        [pscustomobject]@{
            Name       = $r.name
            WorkshopId = $r.workshop_id
            Present    = [bool]($dir -and (Test-Path -LiteralPath $dir))
            InPlayset  = [bool]$entry
            Enabled    = [bool]($entry -and $entry.isEnabled)
            Dir        = $dir
            Entry      = $entry
        }
    }
}

# ---------------------------------------------------------------- состояние программы

function Get-StateHash {
    $s = Read-JsonFile $P.State
    $h = @{ phase = 'unknown'; mods = @(); engine_files = @(); removed_entries = @(); history = @() }
    if ($s) {
        if ($s.phase) { $h.phase = $s.phase }
        $h.mods = @($s.mods | Where-Object { $_ })
        $h.engine_files = @($s.engine_files | Where-Object { $_ })
        $h.removed_entries = @($s.removed_entries | Where-Object { $_ })
        $h.history = @($s.history | Where-Object { $_ })
    }
    return $h
}

function Save-StateHash([hashtable]$S, [string]$What) {
    $S.extender = $ExtVersion
    $S.updated = (Get-Date).ToString('s')
    $S.build_id = $G.BuildId
    $S.history = @(@($S.history) + @([ordered]@{ time = $S.updated; command = $What; phase = $S.phase }) | Select-Object -Last 50)
    if ($DryRun) { return }
    Write-JsonFile $P.State $S
}

# ---------------------------------------------------------------- резервные копии

function Invoke-Backup([string]$Reason) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $dir = Join-Path $P.Backups "${stamp}_$Reason"
    if ($DryRun) { Note "резервная копия была бы в $dir"; return $dir }
    Assert-Writable $dir
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    foreach ($m in @($Prof.mods)) {
        $src = Join-Path $P.ModDir $m.folder
        if (-not (Test-Path -LiteralPath $src)) { $src = Join-Path $P.Repo $m.source }
        if (Test-Path -LiteralPath $src) {
            [IO.Compression.ZipFile]::CreateFromDirectory($src, (Join-Path $dir "$($m.folder).zip"), [IO.Compression.CompressionLevel]::Optimal, $true)
        }
    }
    foreach ($f in $P.Playsets, $P.State) {
        if (Test-Path -LiteralPath $f) { Copy-Item -LiteralPath $f -Destination (Join-Path $dir (Split-Path -Leaf $f)) }
    }
    Good "резервная копия: $dir"
    return $dir
}

# ---------------------------------------------------------------- отпечаток и целостность

function Get-BinFiles {
    $bin = Join-Path $G.Dir 'binaries'
    foreach ($f in (Get-ChildItem -LiteralPath $bin -Recurse -File -Force)) {
        [pscustomobject]@{ Rel = ($f.FullName.Substring($G.Dir.Length).TrimStart('\') -replace '\\', '/'); Full = $f.FullName }
    }
}

function Get-DlcSummary {
    $d = Join-Path $G.Dir 'game\dlc'
    if (-not (Test-Path -LiteralPath $d)) { return [pscustomobject]@{ files = 0; bytes = 0 } }
    $f = @(Get-ChildItem -LiteralPath $d -Recurse -File -Force)
    $sum = ($f | Measure-Object -Property Length -Sum).Sum
    return [pscustomobject]@{ files = $f.Count; bytes = [long]$(if ($sum) { $sum } else { 0 }) }
}

function Get-BaselinePath {
    $b = if ($G.BuildId) { $G.BuildId } else { 'unknown' }
    return Join-Path $P.Baselines "build_$b.json"
}

function Invoke-Snapshot {
    Head 'Отпечаток заводских файлов движка'
    $path = Get-BaselinePath
    if ((Test-Path -LiteralPath $path) -and -not $Force) { Good "отпечаток этой сборки уже есть: $path"; return }
    $S = Get-StateHash
    if (@($S.engine_files).Count -gt 0) { throw 'Сейчас стоят наши правки движка. Отпечаток снимают только с заводской игры: сначала factory.' }
    Note 'считаю контрольные суммы файлов движка...'
    $files = [ordered]@{}
    foreach ($f in (Get-BinFiles | Sort-Object Rel)) { $files[$f.Rel] = Get-Sha $f.Full }
    $base = [ordered]@{
        build_id     = $G.BuildId
        game_version = (Get-LastRunInfo).GameVersion
        created      = (Get-Date).ToString('s')
        note         = 'Снят в предположении, что игра заводская. Если есть сомнения, сначала verify -Steam.'
        files        = $files
        dlc          = Get-DlcSummary
    }
    if ($DryRun) { Note "отпечаток был бы записан: $path"; return }
    Write-JsonFile $path $base
    Good "отпечаток записан: $path (файлов: $($files.Count))"
}

function Get-Integrity {
    $path = Get-BaselinePath
    $res = [ordered]@{ result = 'no-baseline'; build_id = $G.BuildId; baseline = $path; changed = @(); missing = @(); ours = @(); foreign = @(); dlc_ok = $null }
    if (-not (Test-Path -LiteralPath $path)) { return [pscustomobject]$res }
    $base = Read-JsonFile $path
    $baseFiles = @{}
    foreach ($pr in $base.files.PSObject.Properties) { $baseFiles[$pr.Name.ToLowerInvariant()] = $pr.Value }
    $oursMap = @{}
    foreach ($e in (Get-StateHash).engine_files) { $oursMap["binaries/$($e.file)".ToLowerInvariant()] = $e.sha256 }
    $seen = @{}
    $changed = New-Object Collections.ArrayList; $ours = New-Object Collections.ArrayList; $foreign = New-Object Collections.ArrayList; $missing = New-Object Collections.ArrayList
    foreach ($f in Get-BinFiles) {
        $k = $f.Rel.ToLowerInvariant()
        $seen[$k] = $true
        $h = Get-Sha $f.Full
        $isOurs = $oursMap.ContainsKey($k) -and $oursMap[$k] -eq $h
        if ($baseFiles.ContainsKey($k)) {
            if ($h -ne $baseFiles[$k]) { if ($isOurs) { [void]$ours.Add($f.Rel) } else { [void]$changed.Add($f.Rel) } }
        } elseif ($isOurs) { [void]$ours.Add($f.Rel) } else { [void]$foreign.Add($f.Rel) }
    }
    foreach ($k in $baseFiles.Keys) { if (-not $seen.ContainsKey($k)) { [void]$missing.Add($k) } }
    if ($base.dlc) { $d = Get-DlcSummary; $res.dlc_ok = ($d.files -eq $base.dlc.files -and $d.bytes -eq $base.dlc.bytes) }
    $res.changed = $changed.ToArray(); $res.missing = $missing.ToArray(); $res.ours = $ours.ToArray(); $res.foreign = $foreign.ToArray()
    if ($changed.Count + $missing.Count + $foreign.Count -gt 0) { $res.result = 'changed' }
    elseif ($ours.Count -gt 0) { $res.result = 'ours' }
    else { $res.result = 'factory' }
    return [pscustomobject]$res
}

function Show-Integrity($I) {
    switch ($I.result) {
        'factory'     { Good "файлы движка заводские (сверено с отпечатком сборки $($I.build_id))" }
        'ours'        { Good ('заводские файлы на месте, плюс наши правки: ' + ($I.ours -join ', ')) }
        'no-baseline' { Warn "нет отпечатка для сборки $($I.build_id): игра обновилась или отпечаток ещё не снят. Сделайте verify -Steam, потом snapshot." }
        default {
            if (@($I.changed).Count) { Warn ('изменены заводские файлы: ' + ($I.changed -join ', ')) }
            if (@($I.missing).Count) { Warn ('пропали заводские файлы: ' + ($I.missing -join ', ')) }
            if (@($I.foreign).Count) { Warn ('чужие файлы в binaries (не наши, не трогаю): ' + ($I.foreign -join ', ')) }
            Note 'вернуть заводские файлы: verify -Steam (Steam сам перекачает изменённое)'
        }
    }
    if ($I.dlc_ok -eq $false) { Warn 'папка DLC изменилась после отпечатка (обновление Steam?). Программа её не трогает.' }
    elseif ($I.dlc_ok -eq $true) { Good 'папка DLC такая же, как при отпечатке' }
}

function Start-SteamVerify {
    if ($Sandbox -or $DryRun) { Note 'проверка Steam была бы запущена'; return }
    if (Test-GameRunning) { Warn 'игра запущена: проверку Steam запустите после выхода'; return }
    Start-Process "steam://validate/$AppId"
    Note 'Steam начал проверку файлов игры: дождитесь конца в окне Steam, потом снова verify.'
}

function Invoke-Verify {
    $i = Get-Integrity
    if ($Json) { $i | ConvertTo-Json -Depth 6; return }
    Head 'Целостность игры'
    Show-Integrity $i
    if ($Steam) { Start-SteamVerify }
}

# ---------------------------------------------------------------- движок

# Каждая правка движка из ni_profile.json: собрана ли, под какую сборку eu5.exe (файл <dll>.json рядом), стоит ли.
function Get-EngineFiles([string]$ExeSha) {
    $S = Get-StateHash
    foreach ($f in @($Prof.engine.files | Where-Object { $_ })) {
        $src = Join-Path $P.Repo $f.source
        $meta = Read-JsonFile "$src.json"
        $for = @()
        if ($meta -and $meta.exe_sha256) { $for = @($meta.exe_sha256) } elseif ($f.exe_sha256) { $for = @($f.exe_sha256) }
        $inst = @($S.engine_files | Where-Object { $_.file -ieq $f.file }) | Select-Object -First 1
        [pscustomobject]@{
            File      = $f.file
            Source    = $src
            Built     = (Test-Path -LiteralPath $src)
            Stage     = $(if ($meta) { $meta.stage } else { '' })
            ForExe    = $for
            Fits      = [bool]($ExeSha -and ($for -contains $ExeSha))
            Installed = [bool]$inst
        }
    }
}

# Smart App Control (Windows 11): 0 выключен, 1 включён, 2 режим оценки
function Get-SmartAppControl {
    $ci = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' -ErrorAction SilentlyContinue
    if ($ci -and $null -ne $ci.VerifiedAndReputablePolicyState) { return [int]$ci.VerifiedAndReputablePolicyState }
    return 0
}

function Get-EngineLogTail([int]$Lines = 4) {
    $log = Join-Path $P.Home 'engine.log'
    if (-not (Test-Path -LiteralPath $log)) { return @() }
    $all = @((Read-Head $log 1MB) -split "`r?`n" | Where-Object { $_ })
    return @($all | Select-Object -Last $Lines)
}

# ---------------------------------------------------------------- статус

function Invoke-Status {
    $run = Get-LastRunInfo
    $doc = Read-JsonFile $P.Playsets
    $act = Get-ActivePlayset $doc
    $psName = if ($act) { $act.name } else { '?' }
    $sha = Get-Sha (Join-Path $G.Dir 'binaries\eu5.exe')
    $mods = @(Get-ModsState $doc)
    $req = @(Get-RequiredModsState $doc)
    $integ = Get-Integrity
    $S = Get-StateHash
    $backs = @()
    if (Test-Path -LiteralPath $P.Backups) { $backs = @(Get-ChildItem -LiteralPath $P.Backups -Directory | Sort-Object Name) }
    $running = Test-GameRunning
    $loader = Join-Path $G.Dir "binaries\$($Prof.engine.loader)"
    $eng = @(Get-EngineFiles $sha)
    $engLog = @(Get-EngineLogTail 4)
    $engOff = Test-Path -LiteralPath (Join-Path $P.Home 'engine_off')

    if ($Json) {
        [ordered]@{
            extender      = $ExtVersion
            game_dir      = $G.Dir
            build_id      = $G.BuildId
            game_version  = $run.GameVersion
            exe_sha256    = $sha
            game_running  = $running
            playset       = $psName
            phase         = $S.phase
            mods          = $mods
            required_mods = @($req | Select-Object Name, WorkshopId, Present, InPlayset, Enabled)
            last_run_mods = $run.LoadedMods
            last_run_log  = $run.LogTime
            engine_files  = $S.engine_files
            engine        = @($eng | Select-Object File, Stage, Built, Fits, Installed)
            engine_off    = $engOff
            smart_app_control = (Get-SmartAppControl)
            engine_log    = $engLog
            loader_present = (Test-Path -LiteralPath $loader)
            integrity     = $integ
            backups       = $backs.Count
            last_backup   = $(if ($backs.Count) { $backs[-1].Name } else { $null })
        } | ConvertTo-Json -Depth 8
        return
    }

    Head "New Intelligence - расширение v$ExtVersion"
    Say "  Игра:          $($G.Dir)"
    Say "  Сборка Steam:  $($G.BuildId); версия игры $($run.GameVersion) (по журналу от $($run.LogTime))"
    Say "  eu5.exe:       $($sha.Substring(0, 16))..."
    Say "  Состояние:     $(switch ($S.phase) { 'ours' { 'наше' } 'factory' { 'заводское' } default { 'не задано программой' } })"
    if ($running) { Warn 'игра сейчас запущена: программа только смотрит, менять ничего не будет' }

    Head "Наши моды (сборка модов «$psName»)"
    foreach ($m in $mods) {
        $where = switch ($m.Kind) { 'link' { "ссылка на $($m.Target)" } 'folder' { 'папка' } default { 'нет на диске' } }
        $inps = if ($m.Enabled) { 'включён' } elseif ($m.InPlayset) { 'выключен' } else { 'нет в сборке' }
        $line = "$($m.Name) v$($m.Version): $where; $inps"
        if ($m.Kind -ne 'missing' -and $m.Enabled) { Good $line } elseif ($S.phase -eq 'factory') { Note $line } else { Warn $line }
    }

    Head 'Нужные моды (чит-мод)'
    foreach ($r in $req) {
        if (-not $r.Present) { Warn "«$($r.Name)» не найден в Steam: подпишитесь в мастерской (id $($r.WorkshopId))" }
        elseif ($r.Enabled) { Good "«$($r.Name)» на месте и включён" }
        else { Warn "«$($r.Name)» на месте, но не включён в «$psName» (apply включит)" }
    }

    Head 'Движок'
    if ($eng.Count -eq 0) { Note 'правок движка в этой версии программы нет: только моды' }
    foreach ($e in $eng) {
        $what = "$($e.File) ($($e.Stage))"
        if (-not $e.Built) { Note "$what не собран: extender\engine\build.ps1" }
        elseif (-not $e.Fits) { Warn "$what собран под другую сборку eu5.exe: пересоберите (build.ps1)" }
        elseif ($e.Installed) { Good "$what стоит и подходит к этой сборке" }
        else { Note "$what собран под эту сборку, не стоит (поставит apply)" }
    }
    if ((Test-Path -LiteralPath $loader) -and -not (@($S.engine_files | Where-Object { $_.file -ieq $Prof.engine.loader }).Count)) {
        Warn "в binaries лежит чужой $($Prof.engine.loader): не наш, программа его не трогает"
    }
    if ($engOff) { Warn 'выключатель engine_off: загрузчик только передаёт вызовы, больше ничего' }
    $sac = Get-SmartAppControl
    if ($sac -eq 1) { Warn '«Интеллектуальный контроль приложений» Windows включён: неподписанные DLL не грузятся, правки движка ставиться не будут' }
    elseif ($sac -eq 2) { Note '«Интеллектуальный контроль приложений» в режиме оценки: Windows может включить его сама' }
    if ($engLog.Count) { Note 'engine.log:'; foreach ($l in $engLog) { Say "       $l" } }
    Show-Integrity $integ

    Head 'Последний запуск игры'
    if ($run.LoadedMods.Count) { foreach ($lm in $run.LoadedMods) { Note "загружен мод $($lm.Name) [$($lm.Id)]" } }
    else { Note 'в журнале нет строк о модах (игру ещё не запускали или без модов)' }

    Head 'Резервные копии'
    if ($backs.Count) { Note "$($backs.Count) шт. в $($P.Backups); последняя $($backs[-1].Name)" } else { Note 'пока нет' }
}

# ---------------------------------------------------------------- заводское состояние

function Invoke-Factory {
    if (-not $DryRun) { Assert-GameClosed }
    Head 'Возврат игры к заводскому состоянию'
    [void](Invoke-Backup 'before_factory')
    $S = Get-StateHash

    # 1. правки движка: убрать только свои файлы с совпадающей суммой, вернуть подменённые оригиналы
    $keep = New-Object Collections.ArrayList
    foreach ($e in @($S.engine_files)) {
        $path = Join-Path $G.Dir "binaries\$($e.file)"
        if (-not (Test-Path -LiteralPath $path)) { continue }
        if ((Get-Sha $path) -ne $e.sha256) { Warn "$($e.file) изменён не программой: не трогаю"; [void]$keep.Add($e); continue }
        if ($DryRun) { Note "убрал бы правку движка $($e.file)"; continue }
        Assert-Writable $path
        Remove-Item -LiteralPath $path -Force
        if ($e.original_backup -and (Test-Path -LiteralPath $e.original_backup)) {
            Copy-Item -LiteralPath $e.original_backup -Destination $path
            Good "возвращён заводской $($e.file)"
        } else { Good "убрана правка движка $($e.file)" }
    }
    if (-not $DryRun) { $S.engine_files = $keep.ToArray() }

    # 2. сборки модов: вычеркнуть наши моды, запомнив место и включение
    $doc = Read-JsonFile $P.Playsets
    if ($doc) {
        $ourKeys = @{}
        foreach ($m in @($Prof.mods)) { $ourKeys[(ConvertTo-ModKey (Get-ModEntryPath $m.folder))] = $true }
        $removed = New-Object Collections.ArrayList
        foreach ($ps in @($doc.playsets)) {
            $list = @($ps.orderedListMods | Where-Object { $_ })
            $new = New-Object Collections.ArrayList
            for ($i = 0; $i -lt $list.Count; $i++) {
                $e = $list[$i]
                if ($ourKeys.ContainsKey((ConvertTo-ModKey $e.path))) {
                    [void]$removed.Add([ordered]@{ playset = $ps.name; index = $i; path = $e.path; isEnabled = [bool]$e.isEnabled })
                } else { [void]$new.Add($e) }
            }
            $ps.orderedListMods = $new.ToArray()
        }
        if ($removed.Count) {
            if ($DryRun) { Note "вычеркнул бы наши моды из сборок модов (записей: $($removed.Count))" }
            else {
                Write-JsonFile $P.Playsets $doc
                Good "наши моды вычеркнуты из сборок модов (записей: $($removed.Count); места и включение запомнены)"
            }
            $S.removed_entries = @(@($S.removed_entries) + $removed.ToArray())
        } else { Note 'в сборках модов наших модов нет' }
    } else { Note 'playsets.json нет: сборки модов не трогаю' }

    # 3. папки модов: ссылку убрать как ссылку, папку - только если её ставила программа
    if ($RemoveMods) {
        $left = New-Object Collections.ArrayList
        foreach ($m in @($Prof.mods)) {
            $dir = Join-Path $P.ModDir $m.folder
            $li = Get-LinkInfo $dir
            $rec = @($S.mods | Where-Object { $_.folder -eq $m.folder }) | Select-Object -First 1
            if ($li.Kind -eq 'missing') { continue }
            if ($li.Kind -eq 'link') {
                if ($DryRun) { Note "убрал бы ссылку $($m.folder)"; continue }
                Assert-Writable $dir
                [IO.Directory]::Delete($dir, $false)   # удаляет саму ссылку, файлы мода не трогает
                Good "убрана ссылка $($m.folder) (сами файлы мода не тронуты)"
            } elseif ($rec -and $rec.created_by_extender -and $rec.kind -eq 'copy') {
                if ($DryRun) { Note "удалил бы копию $($m.folder)"; continue }
                Assert-Writable $dir
                Remove-Item -LiteralPath $dir -Recurse -Force
                Good "удалена копия мода $($m.folder)"
            } else {
                Warn "папку $($m.folder) ставила не программа: не удаляю"
                if ($rec) { [void]$left.Add($rec) }
            }
        }
        if (-not $DryRun) { $S.mods = $left.ToArray() }
    }

    $S.phase = 'factory'
    Save-StateHash $S 'factory'

    Head 'Проверка'
    Show-Integrity (Get-Integrity)
    if ($Steam) { Start-SteamVerify }
    if ($DryRun) { Note 'это была пробная прогонка (-DryRun): ничего не изменено' }
}

# ---------------------------------------------------------------- наше состояние

function Invoke-Apply {
    if (-not $DryRun) { Assert-GameClosed }
    Head 'Сборка нашего состояния'
    [void](Invoke-Backup 'before_apply')
    $S = Get-StateHash

    # 1. моды на диске
    $recs = New-Object Collections.ArrayList
    foreach ($m in @($Prof.mods)) {
        $dir = Join-Path $P.ModDir $m.folder
        $li = Get-LinkInfo $dir
        $old = @($S.mods | Where-Object { $_.folder -eq $m.folder }) | Select-Object -First 1
        if ($li.Exists) {
            Good "мод $($m.folder) на месте ($(if ($li.Kind -eq 'link') { 'ссылка' } else { 'папка' }))"
            if ($old) { [void]$recs.Add($old) } else { [void]$recs.Add([ordered]@{ folder = $m.folder; kind = $li.Kind; created_by_extender = $false }) }
            continue
        }
        $src = Join-Path $P.Repo $m.source
        if (-not (Test-Path -LiteralPath (Join-Path $src '.metadata\metadata.json'))) { Warn "нет исходника мода $($m.folder): $src"; continue }
        $kind = if ($Copy) { 'copy' } else { 'link' }
        if ($DryRun) { Note "поставил бы $($m.folder) ($kind из $src)"; continue }
        Assert-Writable $dir
        if (-not (Test-Path -LiteralPath $P.ModDir)) { New-Item -ItemType Directory -Force -Path $P.ModDir | Out-Null }
        if ($Copy) { Copy-Item -LiteralPath $src -Destination $dir -Recurse }
        else { New-Item -ItemType Junction -Path $dir -Value $src | Out-Null }
        [void]$recs.Add([ordered]@{ folder = $m.folder; kind = $kind; created_by_extender = $true; source = $src })
        Good "поставлен мод $($m.folder) ($(if ($Copy) { 'копия' } else { 'ссылка на репозиторий' }))"
    }
    if (-not $DryRun) { $S.mods = $recs.ToArray() }

    # 2. сборки модов
    $doc = Read-JsonFile $P.Playsets
    if (-not $doc -or -not (Get-ActivePlayset $doc)) { Warn 'нет playsets.json или в нём нет сборок модов: запустите игру один раз и повторите apply' }
    else {
        $changed = $false
        # 2а. вернуть записи, вычеркнутые командой factory, на прежние места
        $restored = 0
        foreach ($grp in (@($S.removed_entries) | Group-Object -Property playset)) {
            $ps = @($doc.playsets | Where-Object { $_.name -eq $grp.Name }) | Select-Object -First 1
            if (-not $ps) { continue }
            $list = New-Object Collections.ArrayList
            foreach ($e in @($ps.orderedListMods | Where-Object { $_ })) { [void]$list.Add($e) }
            foreach ($r in ($grp.Group | Sort-Object -Property { [int]$_.index })) {
                $key = ConvertTo-ModKey $r.path
                if (@($list | Where-Object { (ConvertTo-ModKey $_.path) -eq $key }).Count) { continue }
                $list.Insert([Math]::Min([int]$r.index, $list.Count), [pscustomobject][ordered]@{ path = $r.path; isEnabled = [bool]$r.isEnabled })
                $restored++
            }
            $ps.orderedListMods = $list.ToArray()
        }
        if ($restored) { $changed = $true; Good "в сборки модов возвращено записей: $restored (на прежние места)" }
        $S.removed_entries = @()

        # 2б. в активной сборке наши моды есть и включены
        $act = Get-ActivePlayset $doc
        $list = New-Object Collections.ArrayList
        foreach ($e in @($act.orderedListMods | Where-Object { $_ })) { [void]$list.Add($e) }
        foreach ($m in @($Prof.mods)) {
            $want = Get-ModEntryPath $m.folder
            $e = @($list | Where-Object { (ConvertTo-ModKey $_.path) -eq (ConvertTo-ModKey $want) }) | Select-Object -First 1
            if (-not $e) { [void]$list.Add([pscustomobject][ordered]@{ path = $want; isEnabled = $true }); $changed = $true; Good "мод $($m.folder) добавлен в сборку «$($act.name)»" }
            elseif (-not $e.isEnabled) { $e.isEnabled = $true; $changed = $true; Good "мод $($m.folder) включён в сборке «$($act.name)»" }
        }
        $act.orderedListMods = $list.ToArray()

        # 2в. чит-мод и другие нужные моды: включить, если есть; скачивать - никогда
        foreach ($r in @(Get-RequiredModsState $doc)) {
            if (-not $r.Present) { Warn "«$($r.Name)» не найден в Steam: подпишитесь в мастерской (id $($r.WorkshopId))"; continue }
            if (-not $r.InPlayset) {
                $l2 = New-Object Collections.ArrayList
                [void]$l2.Add([pscustomobject][ordered]@{ path = (($r.Dir -replace '\\', '/') + '/'); isEnabled = $true })
                foreach ($e in @($act.orderedListMods)) { [void]$l2.Add($e) }
                $act.orderedListMods = $l2.ToArray()
                $changed = $true
                Good "«$($r.Name)» добавлен первым в сборку «$($act.name)»"
            } elseif (-not $r.Enabled) { $r.Entry.isEnabled = $true; $changed = $true; Good "«$($r.Name)» включён" }
            else { Good "«$($r.Name)» на месте и включён" }
        }

        if ($changed) {
            if ($DryRun) { Note 'playsets.json был бы записан' } else { Write-JsonFile $P.Playsets $doc; Good 'playsets.json записан' }
        } else { Note 'сборки модов уже в нашем состоянии' }
    }

    # 3. правки движка (каждая ставится только на свою сборку eu5.exe)
    $eng = @(Get-EngineFiles (Get-Sha (Join-Path $G.Dir 'binaries\eu5.exe')))
    if ($eng.Count -eq 0) { Note 'правок движка в этой версии программы нет: только моды' }
    elseif ((Get-SmartAppControl) -eq 1 -and -not $Sandbox) {
        # Smart App Control не даёт загрузить неподписанную DLL; eu5.exe импортирует VERSION.dll,
        # и с заблокированным version.dll рядом игра просто не запустится
        Warn 'включён «Интеллектуальный контроль приложений» Windows: он не пускает нашу неподписанную DLL, и игра с ней не запустится. Правки движка не ставлю.'
    }
    else {
        $baseline = Read-JsonFile (Get-BaselinePath)
        $engine = New-Object Collections.ArrayList
        foreach ($e in @($S.engine_files)) { [void]$engine.Add($e) }
        foreach ($f in $eng) {
            $dst = Join-Path $G.Dir "binaries\$($f.File)"
            $mine = @($engine | Where-Object { $_.file -ieq $f.File }) | Select-Object -First 1
            if (-not $f.Built -or -not $f.Fits) {
                if (-not $f.Built) { Warn "$($f.File) не собран: запустите extender\engine\build.ps1" }
                else { Warn "$($f.File) собран под другую сборку eu5.exe (игра обновилась?): не ставлю, пересоберите build.ps1" }
                if ($mine -and (Test-Path -LiteralPath $dst) -and (Get-Sha $dst) -eq $mine.sha256) {
                    if ($DryRun) { Note "убрал бы старую правку $($f.File)" }
                    else {
                        Assert-Writable $dst
                        Remove-Item -LiteralPath $dst -Force
                        if ($mine.original_backup -and (Test-Path -LiteralPath $mine.original_backup)) { Copy-Item -LiteralPath $mine.original_backup -Destination $dst }
                        [void]$engine.Remove($mine)
                        Good "старая правка $($f.File) убрана"
                    }
                }
                continue
            }
            $orig = $null
            if ((Test-Path -LiteralPath $dst) -and -not $mine) {
                # на месте чужой файл: заводской (есть в отпечатке) сохраняем и подменяем, посторонний не трогаем
                $rel = "binaries/$($f.File)"
                $isVanilla = $baseline -and ($baseline.files.PSObject.Properties.Name -contains $rel)
                if (-not $isVanilla) { Warn "в binaries уже лежит чужой $($f.File) (не заводской и не наш): не трогаю, правку не ставлю"; continue }
                $orig = Join-Path $P.Originals "build_$($G.BuildId)\$($f.File)"
                if (-not $DryRun) {
                    Assert-Writable $orig
                    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $orig) | Out-Null
                    Copy-Item -LiteralPath $dst -Destination $orig -Force
                }
            } elseif ($mine) { $orig = $mine.original_backup }
            if ($DryRun) { Note "поставил бы правку движка $($f.File) ($($f.Stage))"; continue }
            Assert-Writable $dst
            Copy-Item -LiteralPath $f.Source -Destination $dst -Force
            if ($mine) { [void]$engine.Remove($mine) }
            [void]$engine.Add([ordered]@{ file = $f.File; sha256 = (Get-Sha $dst); original_backup = $orig })
            Good "поставлена правка движка $($f.File) ($($f.Stage))"
        }
        if (-not $DryRun) { $S.engine_files = $engine.ToArray() }
    }

    $S.phase = 'ours'
    Save-StateHash $S 'apply'
    Head 'Проверка'
    Show-Integrity (Get-Integrity)
    if ($DryRun) { Note 'это была пробная прогонка (-DryRun): ничего не изменено' }
}

# ---------------------------------------------------------------- отчёт

function Invoke-Report {
    Head 'Отчёт для разбора'
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $file = Join-Path $P.Reports "report_$stamp.txt"
    $run = Get-LastRunInfo
    $out = New-Object Collections.Generic.List[string]
    $out.Add("New Intelligence - отчёт $stamp (расширение v$ExtVersion)")
    $out.Add("Игра: сборка $($G.BuildId), версия $($run.GameVersion); журнал от $($run.LogTime)")
    $out.Add('Загруженные моды: ' + (($run.LoadedMods | ForEach-Object { "$($_.Name) [$($_.Id)]" }) -join '; '))
    $out.Add('')
    Note 'читаю error*.log...'
    $counts = @{}
    $order = New-Object Collections.Generic.List[string]
    foreach ($n in 'error.5.log', 'error.4.log', 'error.3.log', 'error.2.log', 'error.1.log', 'error.log') {
        foreach ($line in (Select-SharedLines (Join-Path $P.Logs $n) '(?i)gp_|cw_|new_intelligence')) {
            $msg = $line -replace '^\[[^\]]*\]\[[^\]]*\]:\s*', ''
            if ($counts.ContainsKey($msg)) { $counts[$msg]++ } else { $counts[$msg] = 1; $order.Add($msg) }
        }
    }
    $out.Add("== Ошибки с упоминанием наших модов (error*.log): разных $($order.Count)")
    foreach ($msg in $order) { $out.Add(('{0,5}x  {1}' -f $counts[$msg], $msg)) }
    $out.Add('')
    Note 'читаю debug.log...'
    $gp = Select-SharedLines (Join-Path $P.Logs 'debug.log') 'GP_REPORT|CW_REPORT'
    $out.Add("== Строки отчёта модов (debug.log): $($gp.Count), последние 400")
    for ($i = [Math]::Max(0, $gp.Count - 400); $i -lt $gp.Count; $i++) { $out.Add($gp[$i]) }
    $out.Add('')
    $out.Add('== engine.log (последние 40 строк)')
    foreach ($l in (Get-EngineLogTail 40)) { $out.Add($l) }
    Assert-Writable $file
    if (-not (Test-Path -LiteralPath $P.Reports)) { New-Item -ItemType Directory -Force -Path $P.Reports | Out-Null }
    [IO.File]::WriteAllLines($file, $out, $Utf8)
    Good "ошибок наших модов: $($order.Count) разных; строк отчёта мода: $($gp.Count)"
    Good "отчёт: $file"
}

# ---------------------------------------------------------------- меню

function Invoke-Menu {
    while ($true) {
        Write-Host ''
        Write-Host "New Intelligence - расширение для EU5 (v$ExtVersion)" -ForegroundColor Cyan
        Write-Host '  1  Что стоит (статус)'
        Write-Host '  2  Резервная копия модов'
        Write-Host '  3  Проверить целостность игры'
        Write-Host '  4  Вернуть игру к заводскому состоянию'
        Write-Host '  5  Собрать наше состояние'
        Write-Host '  6  Отчёт для Claude'
        Write-Host '  7  Проверить файлы игры через Steam'
        Write-Host '  0  Выход'
        $c = Read-Host 'Выберите'
        try {
            switch ($c) {
                '1' { Invoke-Status }
                '2' { [void](Invoke-Backup 'manual') }
                '3' { Invoke-Verify }
                '4' { if ((Read-Host 'Выключить наши моды и убрать правки движка? (да/нет)') -match '^(д|y)') { Invoke-Factory } }
                '5' { Invoke-Apply }
                '6' { Invoke-Report }
                '7' { Start-SteamVerify }
                '0' { return }
            }
        } catch { Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor Red }
    }
}

# ---------------------------------------------------------------- запуск

try {
    if ($Sandbox) {
        if (-not ($GameDir -and $UserDir -and $HomeDir)) { throw 'Песочнице нужны -GameDir, -UserDir и -HomeDir.' }
        $exe = Join-Path $GameDir 'binaries\eu5.exe'
        if ((Test-Path -LiteralPath $exe) -and (Get-Item -LiteralPath $exe).Length -gt 10MB) { throw 'Песочница не может указывать на настоящую игру.' }
        $realUser = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Paradox Interactive\Europa Universalis V'
        if ([IO.Path]::GetFullPath($UserDir).TrimEnd('\') -ieq $realUser) { throw 'Песочница не может указывать на настоящую папку игры в Документах.' }
    }
    $P = Resolve-Paths
    $Prof = Read-JsonFile (Join-Path $PSScriptRoot 'ni_profile.json')
    if (-not $Prof) { throw 'Нет ni_profile.json рядом с программой.' }
    $G = Find-Game
    switch ($Command) {
        'status'   { Invoke-Status }
        'backup'   { [void](Invoke-Backup 'manual') }
        'snapshot' { Invoke-Snapshot }
        'verify'   { Invoke-Verify }
        'factory'  { Invoke-Factory }
        'apply'    { Invoke-Apply }
        'report'   { Invoke-Report }
        'menu'     { Invoke-Menu }
    }
} catch {
    if ($Json) { [ordered]@{ error = $_.Exception.Message } | ConvertTo-Json }
    else { Write-Host "Ошибка: $($_.Exception.Message)" -ForegroundColor Red }
    exit 1
}
if ($Warnings.Count -and -not $Json) { Say ''; Say "Предупреждений: $($Warnings.Count)" 'Yellow' }
