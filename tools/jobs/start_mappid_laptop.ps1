# Portable Windows runner: one MATLAB worker, cached evaluations, no DREWS.
param(
    [ValidateSet('S1','S2','Select','All')][string]$Stage = 'S1',
    [string]$MatlabExe = '',
    [int]$MinHeadroomGB = 6,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$state = Join-Path $repo 'scratch\jobs\mappid_laptop'
$required = @(
    'Model/setup_paths.m', 'Model/data/pid.json', 'Model/data/map.json',
    'Model/data/mappid.json', 'Model/Controllers/MapPID/Model_MapPID.mdl',
    'Model/Controllers/MapPID/script/run_mappid_grid.m',
    'Model/Controllers/MapPID/script/select_mappid_pareto.m',
    'Model/common/grid_search.m', 'Model/common/select_pareto.m',
    'Result/Controllers/PID/Calib_v2/PID_CALIB_pick_s10000.csv'
)
if ($Stage -in @('S2','Select','All')) {
    $required += 'Result/Controllers/Map/Calib_v2/Map_CALIB_pick_s00000.csv'
}
foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $repo $relative))) {
        throw "Missing prerequisite: $relative. See tools/jobs/MAPPID_LAPTOP.md."
    }
}
if (-not $MatlabExe) {
    $command = Get-Command matlab.exe -ErrorAction SilentlyContinue
    if ($command) { $MatlabExe = $command.Source }
    else { $MatlabExe = Join-Path $env:ProgramFiles 'MATLAB\R2023a\bin\matlab.exe' }
}
if (-not (Test-Path -LiteralPath $MatlabExe)) { throw "MATLAB not found: $MatlabExe. Pass -MatlabExe explicitly." }
$MatlabExe = (Resolve-Path -LiteralPath $MatlabExe).Path
Write-Output "Repo=$repo; MATLAB=$MatlabExe; Stage=$Stage; workers=1; DREWS=disabled"
if ($CheckOnly) { Write-Output 'Preflight PASS (file checks only; MATLAB was not launched).'; exit 0 }

New-Item -ItemType Directory -Path $state -Force | Out-Null
# FileShare.None releases automatically if this supervisor exits or crashes.
try { $lock = [IO.File]::Open((Join-Path $state 'runner.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
catch { throw 'A laptop MapPID supervisor is already active. Do not launch a second copy.' }
$tempDir = Join-Path ([IO.Path]::GetTempPath()) 'AdaptiveEPS_MapPID'
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$env:TEMP = $tempDir
$env:TMP = $tempDir
$repoMatlab = $repo.Replace('\','/').Replace("'", "''")

function Get-MemoryHeadroomGB {
    $os = Get-CimInstance Win32_OperatingSystem
    # FreeVirtualMemory includes the commit/page-file limit, unlike physical RAM alone.
    [math]::Min($os.FreePhysicalMemory, $os.FreeVirtualMemory) / 1MB
}
function Get-MatlabEngines {
    @(Get-CimInstance Win32_Process | Where-Object {
        $_.Name -ieq 'MATLAB.exe' -and $_.ExecutablePath -match '\\bin\\win64\\MATLAB\.exe$'
    })
}
function Run-CachedStage([string]$Name, [string]$Expression) {
    $done = Join-Path $state "$Name.done"
    if (Test-Path -LiteralPath $done) { Write-Output "$Name already complete"; return }
    $attempt = 0; $realErrors = 0
    while ($true) {
        while ((Get-MatlabEngines).Count -gt 0 -or (Get-MemoryHeadroomGB) -lt $MinHeadroomGB) {
            # Reserve this machine for a single grid worker: no cross-job slot race.
            Set-Content -LiteralPath (Join-Path $state 'status.txt') -Value "$Name waiting for all MATLAB engines to exit and $MinHeadroomGB GB headroom"
            Start-Sleep -Seconds 30
        }
        $attempt++
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
        $stdout = Join-Path $state "${Name}_${stamp}.out.log"
        $stderr = Join-Path $state "${Name}_${stamp}.err.log"
        $marker = "MAPPID_LAPTOP_${Name}_DONE"
        $expr = "run('$repoMatlab/Model/setup_paths.m'); $Expression; disp('$marker')"
        Set-Content -LiteralPath (Join-Path $state 'status.txt') -Value "$Name attempt=$attempt running at $(Get-Date -Format s)"
        $process = Start-Process -FilePath $MatlabExe -ArgumentList @('-softwareopengl','-batch',('"' + $expr + '"')) -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
        while (-not $process.HasExited) { Start-Sleep -Seconds 15; $process.Refresh() }
        $log = (Get-Content -LiteralPath $stdout,$stderr -Raw -ErrorAction SilentlyContinue) -join "`n"
        # A crashed launcher can leave its engine alive. Target only this exact batch.
        Get-CimInstance Win32_Process | Where-Object {
            $_.Name -ieq 'MATLAB.exe' -and $_.CommandLine -and $_.CommandLine.Contains($expr)
        } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        if ($log.Contains($marker)) {
            Set-Content -LiteralPath $done -Value "Verified marker in $stdout / $stderr"
            Write-Output "$Name complete"; return
        }
        $crash = $log -match '0xc0000374|0xffffffff|out of memory|OutOfMemory'
        if (-not $crash -and $process.ExitCode -eq 1) { $realErrors++ }
        Set-Content -LiteralPath (Join-Path $state 'status.txt') -Value "$Name interrupted exit=$($process.ExitCode), realErrors=$realErrors; logs=$stdout,$stderr"
        if ($realErrors -ge 3) { throw "$Name failed three times. Diagnose logs, fix the cause, record history, then resume; CSV cache is retained." }
        Start-Sleep -Seconds 60
    }
}
try {
    Run-CachedStage 'helpers' 'test_mappid_grid_helpers'
    if ($Stage -in @('S1','All')) { Run-CachedStage 'S1' "run_mappid_grid('S1',1,1)" }
    if ($Stage -in @('S2','All')) { Run-CachedStage 'S2' "run_mappid_grid('S2',1,1)" }
    if ($Stage -in @('Select','All')) {
        foreach ($start in @('S1','S2')) {
            $summary = Join-Path $repo "Result/Controllers/MapPID/Calib_v2/MapPID_CALIB_${start}_summary.mat"
            if (-not (Test-Path -LiteralPath $summary)) { throw "Missing completed $start summary: $summary" }
        }
        Run-CachedStage 'Select' 'select_mappid_pareto(true)'
    }
    Set-Content -LiteralPath (Join-Path $state 'status.txt') -Value "$Stage complete; legacy DREWS disabled"
}
finally { $lock.Dispose() }
