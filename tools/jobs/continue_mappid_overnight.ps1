param([switch]$CheckOnly, [int]$PollSeconds = 60, [string]$MatlabExe = '')
. (Join-Path $PSScriptRoot 'map_handoff_common.ps1')
$state = Join-Path $repo 'scratch/jobs/map_handoff_laptop'
$runnerState = Join-Path $repo 'scratch/jobs/mappid_laptop'
$runner = Join-Path $PSScriptRoot 'start_mappid_laptop.ps1'
if ($CheckOnly) {
    Write-Output "Laptop watcher preflight: repo=$repo; branch=$handoffBranch; git=$gitExe; no MATLAB launched"
    exit 0
}
$lock = Open-HandoffLock $state
New-Item -ItemType Directory -Path $runnerState -Force | Out-Null
function Run-LaptopStage([string]$Name) {
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$runner,'-Stage',$Name)
    if ($MatlabExe) { $arguments += @('-MatlabExe',$MatlabExe) }
    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "$Name runner failed; inspect scratch/jobs/mappid_laptop logs." }
}
try {
    # Leave the existing S1 supervisor in charge until it releases its exclusive lock.
    while ($true) {
        $runnerLock = $null
        try { $runnerLock = [IO.File]::Open((Join-Path $runnerState 'runner.lock'), 'OpenOrCreate', 'ReadWrite', 'None') } catch { }
        if ($runnerLock) { $runnerLock.Dispose(); break }
        Write-State 'WAIT_S1: existing laptop supervisor is still active'
        Start-Sleep -Seconds $PollSeconds
    }
    $s1Summary = Join-Path $repo 'Result/Controllers/MapPID/Calib_v2/MapPID_CALIB_S1_summary.mat'
    if (-not (Test-Path -LiteralPath $s1Summary) -or -not (Test-Path -LiteralPath (Join-Path $runnerState 'S1.done'))) {
        Write-State 'RESUME_S1: previous supervisor exited before verified completion'
        Run-LaptopStage 'S1'
    }
    if (-not (Test-Path -LiteralPath $s1Summary)) { throw 'S1 summary is missing after runner completion.' }
    $s1Hash = (Get-FileHash -LiteralPath $s1Summary).Hash
    while ($true) {
        try {
            $null = Git-Text fetch origin "refs/heads/${handoffBranch}:refs/remotes/origin/$handoffBranch"
            $source = Git-Text rev-parse "refs/remotes/origin/$handoffBranch"
            $manifest = (Git-Text show "${source}:$manifestPath") | ConvertFrom-Json
            if ($manifest.schema -ne 1 -or $manifest.ready -ne $true -or $manifest.drews -ne $false) { throw 'Remote handoff manifest is not ready.' }
            break
        } catch { Write-State "WAIT_MAP_REMOTE: $_"; Start-Sleep -Seconds $PollSeconds }
    }
    $receipt = Join-Path $state 'source_commit.txt'
    if ((Test-Path -LiteralPath $receipt) -and (Get-Content -LiteralPath $receipt -Raw).Trim() -ne $source) {
        throw 'A different Map source was already imported for S2; preserve its cache for review.'
    }
    if (Test-Path -LiteralPath (Join-Path $runnerState 'S2.done')) {
        if (-not (Test-Path -LiteralPath $receipt) -or (Get-Content -LiteralPath $receipt -Raw).Trim() -ne $source) { throw 'Existing S2 has another or unknown Map source; preserve its cache for review.' }
    }
    foreach ($entry in $manifest.code) {
        $actual = Git-Text hash-object -- $entry.path
        if ($actual -ne $entry.blob) { throw "Local MATLAB source differs from handoff: $($entry.path). Preserve local edits and reconcile before S2." }
    }
    $stageDir = Join-Path $state ('in_' + $source.Substring(0,12))
    New-Item -ItemType Directory -Path $stageDir -Force | Out-Null
    $allowed = @($mapJsonPath,$mapPickPath,
        'Result/Controllers/Map/Calib_v2/Map_CALIB_pareto_s00000.csv',
        'Result/Controllers/Map/Calib_v2/Map_CALIB_pareto_s00000.png',
        'Result/Controllers/Map/Calib_v2/Map_CALIB_pareto_check_s00001-s00005.csv')
    foreach ($entry in $manifest.files) {
        if ($entry.path -notin $allowed -or $entry.blob -notmatch '^[0-9a-f]{40}$') { throw 'Invalid manifest payload path or object.' }
        $incoming = Join-Path $stageDir ([IO.Path]::GetFileName($entry.path))
        Read-GitBlob $entry.blob $incoming
        if ((Git-Text hash-object --no-filters -- $incoming) -ne $entry.blob) { throw 'Incoming payload hash mismatch.' }
        $target = Join-Path $repo $entry.path
        if (Test-Path -LiteralPath $target) {
            $actual = Git-Text hash-object -- $entry.path
            if ($actual -ne $entry.blob -and $actual -ne $entry.baseline) { throw "Local changes conflict with incoming $($entry.path); nothing overwritten." }
        }
    }
    foreach ($path in $allowed) { if ($path -notin @($manifest.files.path)) { throw "Incomplete handoff: $path" } }
    $null = Test-MapPair (Join-Path $stageDir 'map.json') (Join-Path $stageDir 'Map_CALIB_pick_s00000.csv')
    foreach ($entry in $manifest.files) {
        $target = Join-Path $repo $entry.path
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        $backup = Join-Path $stageDir ('before_' + [IO.Path]::GetFileName($entry.path))
        if ((Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $target -Destination $backup }
        Copy-Item -LiteralPath (Join-Path $stageDir ([IO.Path]::GetFileName($entry.path))) -Destination $target -Force
    }
    [IO.File]::WriteAllText($receipt, $source)
    Write-State "MAP_RECEIVED: $source; verified pick/json, source code and preserved S1"
    Run-LaptopStage 'S2'
    if ((Get-FileHash -LiteralPath $s1Summary).Hash -ne $s1Hash) { throw 'S1 summary changed during S2.' }
    Run-LaptopStage 'Select'
    $pick = Join-Path $repo 'Result/Controllers/MapPID/Calib_v2/MapPID_CALIB_pick_s30000.csv'
    $chosen = @(Import-Csv -LiteralPath $pick | Where-Object { [double]$_.chosen -eq 1 })
    if ($chosen.Count -ne 1) { throw 'Final MapPID pick is missing or ambiguous.' }
    $d = (Get-Content -LiteralPath (Join-Path $repo 'Model/data/mappid.json') -Raw | ConvertFrom-Json).design
    if ($d.rule -notmatch 'deterministic alternating-block coarse-to-fine grid' -or $null -eq $d.CALIB_J -or [double]::IsNaN([double]$d.CALIB_J) -or [math]::Abs([double]$d.CALIB_J - [double]$chosen[0].Jv) -gt 1e-7 * [math]::Max(1,[double]$d.CALIB_J)) { throw 'Final MapPID JSON/pick mismatch.' }
    Write-State "ALL_DONE: S1 + Map $source + S2 + Pareto; legacy DREWS disabled"
    [IO.File]::WriteAllText((Join-Path $state 'all.done'), $source)
} catch { Write-State "FAILED: $_"; throw }
finally { $lock.Dispose() }
