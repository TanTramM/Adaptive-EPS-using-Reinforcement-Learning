# Shared Git and validation helpers; no MATLAB is launched here.
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
$gitExe = if ($gitCommand) { $gitCommand.Source } else { Join-Path $env:ProgramFiles 'Git\cmd\git.exe' }
if (-not (Test-Path -LiteralPath $gitExe)) { throw 'git.exe not found.' }
$env:GIT_TERMINAL_PROMPT = '0'
$handoffBranch = 'automation/map-s2-ready'
$manifestPath = 'tools/jobs/map_s2_ready.json'
$mapJsonPath = 'Model/data/map.json'
$mapPickPath = 'Result/Controllers/Map/Calib_v2/Map_CALIB_pick_s00000.csv'
function Git-Text {
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $gitExe -C $repo -c credential.interactive=never -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=30 @args 2>&1
        $exitCode = $LASTEXITCODE
    } finally { $ErrorActionPreference = $savedPreference }
    if ($exitCode -ne 0) { throw "git $($args -join ' '): $($output -join ' ')" }
    ($output -join "`n").Trim()
}
function Write-State([string]$Message) {
    $line = "$(Get-Date -Format s) $Message"
    [IO.File]::WriteAllText((Join-Path $state 'status.txt'), $line)
    [IO.File]::AppendAllText((Join-Path $state 'events.log'), "$line`r`n")
    Write-Output $line
}
function Read-GitBlob([string]$Object, [string]$Destination) {
    # Stream bytes directly: PowerShell 5 text redirection corrupts MAT/PNG files.
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $gitExe
    $info.WorkingDirectory = $repo
    $info.Arguments = "cat-file blob $Object"
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $proc = [Diagnostics.Process]::Start($info)
    $stream = [IO.File]::Create($Destination)
    try { $proc.StandardOutput.BaseStream.CopyTo($stream) } finally { $stream.Dispose() }
    $errorText = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) { throw "Cannot export blob ${Object}: $errorText" }
    $proc.Dispose()
}
function Test-MapPair([string]$JsonFile, [string]$PickFile) {
    $design = (Get-Content -LiteralPath $JsonFile -Raw -Encoding UTF8 | ConvertFrom-Json).design
    $rows = @(Import-Csv -LiteralPath $PickFile | Where-Object { [double]$_.chosen -eq 1 })
    if ($rows.Count -ne 1) { throw 'Map pick must contain exactly one chosen row.' }
    $row = $rows[0]
    foreach ($field in @('K','z','p_over_z','z1','p1_over_z1','Jv','erel_pct')) {
        if ($null -eq $row.$field -or $row.$field -eq '') { throw "Map pick is missing $field" }
    }
    if ([double]$row.erel_pct -gt 10) { throw 'Map pick exceeds the CALIB accuracy gate.' }
    if ($design.rule -notmatch 'deterministic coarse-to-fine grid') { throw 'map.json is not a grid-selector result.' }
    foreach ($field in @('margin_ratio_gain','margin_ratio_delay')) {
        if ($null -eq $design.$field -or [double]::IsNaN([double]$design.$field) -or [double]$design.$field -le 0 -or [double]$design.$field -gt 2) { throw "Map margin gate failed: $field" }
    }
    $pairs = @(
        @([double]$row.K, [double]$design.Kmax),
        @([double]$row.z, [double]$design.lead.z),
        @([double]$row.p_over_z, ([double]$design.lead.p / [double]$design.lead.z)),
        @([double]$row.z1, [double]$design.lag.z1),
        @([double]$row.p1_over_z1, ([double]$design.lag.p1 / [double]$design.lag.z1)),
        @([double]$row.Jv, [double]$design.CALIB_J)
    )
    foreach ($pair in $pairs) {
        if ([double]::IsNaN($pair[0]) -or [double]::IsInfinity($pair[0]) -or [double]::IsNaN($pair[1]) -or [double]::IsInfinity($pair[1]) -or [math]::Abs($pair[0]-$pair[1]) -gt 1e-7 * [math]::Max(1,[math]::Abs($pair[0]))) { throw 'Map pick and map.json disagree.' }
    }
    $design
}
function Open-HandoffLock([string]$Directory) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
    try { [IO.File]::Open((Join-Path $Directory 'watcher.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { throw "A handoff watcher already owns $Directory" }
}
