# Start MapPID S2 on this machine as soon as the Map grid selection is valid.
# S1 is intentionally owned by the laptop.  This watcher never runs Select,
# because Select must wait for the laptop's S1 summary to be pushed back.
param(
    [int]$PollSeconds = 15,
    [double]$MinHeadroomGB = 0,
    [ValidateRange(0.05,0.50)][double]$ReserveRamFraction = 0.10,
    [string]$MatlabExe = ''
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scratch = Join-Path $repo 'scratch\jobs'
$state = Join-Path $scratch 'mappid_s2_handoff'
$statusFile = Join-Path $state 'status.txt'
$mapPick = Join-Path $repo 'Result\Controllers\Map\Calib_v2\Map_CALIB_pick_s00000.csv'
$mapJson = Join-Path $repo 'Model\data\map.json'
$mapSelectDone = Join-Path $scratch 'map_grid_select_done.txt'
$s2Summary = Join-Path $repo 'Result\Controllers\MapPID\Calib_v2\MapPID_CALIB_S2_summary.mat'
$runner = Join-Path $PSScriptRoot 'start_mappid_laptop.ps1'

New-Item -ItemType Directory -Path $state -Force | Out-Null
try { $lock = [IO.File]::Open((Join-Path $state 'watcher.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
catch { throw 'A Map-to-MapPID S2 handoff watcher is already active.' }

function Set-HandoffStatus([string]$Message) {
    Set-Content -LiteralPath $statusFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
}

function Test-SelectedMap {
    if (-not (Test-Path -LiteralPath $mapPick)) { return @{ Ready = $false; Why = 'waiting: Map_CALIB_pick_s00000.csv is missing' } }
    if (-not (Test-Path -LiteralPath $mapSelectDone)) { return @{ Ready = $false; Why = 'waiting: Map pick exists but Map selector has not completed its five-seed report' } }
    try {
        $json = Get-Content -LiteralPath $mapJson -Raw | ConvertFrom-Json
        $d = $json.design
        $count = [int]$d.n_grid_evaluations
        if ($count -le 0 -or "$($d.rule)" -notmatch 'grid') {
            return @{ Ready = $false; Why = 'waiting: map.json is not the selected grid design' }
        }
    }
    catch {
        return @{ Ready = $false; Why = "waiting: cannot validate selected map.json ($($_.Exception.Message))" }
    }
    return @{ Ready = $true; Why = 'Map selection verified' }
}

try {
    if (Test-Path -LiteralPath $s2Summary) {
        Set-HandoffStatus 'S2 summary already exists; watcher exits without launching a duplicate.'
        exit 0
    }
    Set-HandoffStatus "STARTED: polling every $PollSeconds s for a verified Map selection; laptop owns S1."
    while ($true) {
        $gate = Test-SelectedMap
        if ($gate.Ready) { break }
        Set-HandoffStatus $gate.Why
        Start-Sleep -Seconds $PollSeconds
    }

    Set-HandoffStatus 'Map selection verified; launching local MapPID S2 runner.'
    $arguments = @{ Stage = 'S2'; MinHeadroomGB = $MinHeadroomGB; ReserveRamFraction = $ReserveRamFraction }
    if ($MatlabExe) { $arguments.MatlabExe = $MatlabExe }
    & $runner @arguments
    if (-not (Test-Path -LiteralPath $s2Summary)) {
        throw 'S2 runner returned without MapPID_CALIB_S2_summary.mat.'
    }
    Set-HandoffStatus 'S2 complete. Commit/push S2 artifacts; then one machine pulls S1 + S2 and runs Select.'
}
catch {
    Set-HandoffStatus "FAILED: $($_.Exception.Message)"
    throw
}
finally {
    $lock.Dispose()
}
