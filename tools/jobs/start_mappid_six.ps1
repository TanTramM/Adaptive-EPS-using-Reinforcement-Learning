# Independent Map(2) and MapPID(6) profile; no legacy results/markers reused.
param(
    [ValidateSet('All','Check','Map','S1','S2','Select')][string]$Stage='All',
    [ValidateRange(1,5)][int]$MaxWorkers=5,
    [ValidateRange(.05,.5)][double]$ReserveRamFraction=.10,
    [string]$MatlabExe='C:\Program Files\MATLAB\R2023a\bin\matlab.exe'
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$state=Join-Path $repo 'scratch\jobs\mappid_six'
New-Item -ItemType Directory -Path $state -Force | Out-Null
try { $lock=[IO.File]::Open((Join-Path $state 'runner.lock'),'OpenOrCreate','ReadWrite','None') }
catch { throw 'The independent six-variable supervisor is already running.' }
$matlabRoot=$repo.Replace('\','/').Replace("'","''")
$tempDir=Join-Path ([IO.Path]::GetTempPath()) 'AdaptiveEPS_MapPID6'
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$env:TEMP=$tempDir; $env:TMP=$tempDir
function Status([string]$message) {
    $line="$(Get-Date -Format s) $message"
    Set-Content -LiteralPath (Join-Path $state 'status.txt') -Value $line
    Add-Content -LiteralPath (Join-Path $state 'events.log') -Value $line
    Write-Host $line
}
function Memory {
    $os=Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    return @{Free=[math]::Min($os.FreePhysicalMemory,$os.FreeVirtualMemory)/1MB;
        Reserve=$os.TotalVisibleMemorySize/1MB*$ReserveRamFraction;
        Total=$os.TotalVisibleMemorySize/1MB}
}
function Stop-Owned($jobs) {
    foreach($job in $jobs) {
        $job.Process.Refresh()
        if(-not $job.Process.HasExited) {
            # These roots were created by this supervisor; never target by name.
            & "$env:SystemRoot\System32\taskkill.exe" /PID $job.Process.Id /T /F | Out-Null
        }
    }
    # A MATLAB launcher may exit before its engine. Identify surviving engines
    # by this supervisor's unique batch expression before retrying the layer.
    $engines=@(Get-CimInstance Win32_Process -Filter "Name='MATLAB.exe'" -ErrorAction SilentlyContinue)
    foreach($job in $jobs) {
        foreach($engine in $engines) {
            if($engine.CommandLine -and $engine.CommandLine.Contains($job.Marker)) {
                & "$env:SystemRoot\System32\taskkill.exe" /PID $engine.ProcessId /T /F | Out-Null
            }
        }
    }
}
function Run-Stage([string]$name,[string]$action,[bool]$parallel) {
    $done=Join-Path $state "$name.done"
    if(Test-Path -LiteralPath $done) { Status "$name already complete"; return $true }
    $attempt=0; $errors=0; $cap=$MaxWorkers; $requested=0
    while($true) {
        $memory=Memory
        while($memory.Free -lt ($memory.Reserve+2.0)) {
            Status "$name waiting for RAM reserve + 2 GB worker startup"
            Start-Sleep -Seconds 15; $memory=Memory
        }
        $count=1
        if($parallel) {
            $count=[math]::Max(1,[math]::Min($cap,[math]::Floor(($memory.Free-$memory.Reserve)/1.6)))
            if($requested -gt 0) { $count=[math]::Min($cap,$requested); $requested=0 }
        }
        $attempt++; $stamp=Get-Date -Format 'yyyyMMdd_HHmmss_fff'; $jobs=@()
        Status "$name attempt=$attempt workers=$count reserveGB=$($memory.Reserve)"
        try {
            for($worker=1;$worker -le $count;$worker++) {
                $stdout=Join-Path $state "${name}_${stamp}_w${worker}.out.log"
                $stderr=Join-Path $state "${name}_${stamp}_w${worker}.err.log"
                $marker="MAPPID_SIX_${name}_W${worker}_DONE"
                $expr="run('$matlabRoot/Model/setup_paths.m'); run_mappid_six('$action',$worker,$count); disp('$marker')"
                $process=Start-Process -FilePath $MatlabExe -ArgumentList @('-softwareopengl','-batch',('"'+$expr+'"')) -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
                $jobs+=@{Process=$process;Out=$stdout;Err=$stderr;Marker=$marker}
                Start-Sleep -Seconds 2
            }
            $ramStop=$false; $workerError=$false; $expand=$false; $lowSince=$null
            while($true) {
                $running=0
                foreach($job in $jobs) {
                    $job.Process.Refresh()
                    if(-not $job.Process.HasExited) { $running++ }
                    else {
                        $log=(Get-Content -LiteralPath $job.Out,$job.Err -Raw -ErrorAction SilentlyContinue)-join "`n"
                        if(-not $log.Contains($job.Marker)) { $workerError=$true }
                    }
                }
                if($running -eq 0 -or $workerError) { break }
                $memory=Memory
                if($memory.Free -lt $memory.Reserve) { $ramStop=$true; break }
                if($parallel -and $count -lt $cap -and $running -eq $count -and $memory.Free -gt .20*$memory.Total) {
                    if($null -eq $lowSince) { $lowSince=Get-Date }
                    if(((Get-Date)-$lowSince).TotalSeconds -ge 180) { $expand=$true; break }
                } else { $lowSince=$null }
                Start-Sleep -Seconds 10
            }
            if($ramStop -or $workerError -or $expand) { Stop-Owned $jobs }
            $allLogs=($jobs | ForEach-Object { (Get-Content -LiteralPath $_.Out,$_.Err -Raw -ErrorAction SilentlyContinue)-join "`n" })-join "`n"
            $success=-not $ramStop -and -not $workerError -and -not $expand
            foreach($job in $jobs) { if(-not $allLogs.Contains($job.Marker)) { $success=$false } }
            if($success) {
                Set-Content -LiteralPath $done -Value "Verified all $count worker markers; $stamp"
                Status "$name complete"; return $true
            }
            if($expand) {
                $requested=$count+1
                Status "$name below 80 percent RAM for 180 s; resuming cached grid with $requested workers"
            } elseif($ramStop) {
                $cap=[math]::Max(1,$count-1)
                Status "$name RAM reserve reached; cached rows retained; retry cap=$cap"
            } elseif($allLogs -match 'select_pareto:noMargin|No feasible design passes calib_margin|No grid point passes all gates') {
                Status "$name BLOCKED: no design passes unchanged gates; cache retained"
                return $false
            } else {
                if($allLogs -notmatch '0xc0000374|0xffffffff|OutOfMemory|out of memory') { $errors++ }
                Status "$name execution failed; errors=$errors; logs=${name}_${stamp}"
                if($errors -ge 3) { throw "$name failed three times; inspect logs and repair before resume." }
            }
        } catch { Stop-Owned $jobs; throw }
        if($expand) { Start-Sleep -Seconds 5 } else { Start-Sleep -Seconds 60 }
    }
}
try {
    if(-not (Run-Stage 'check' 'check' $false)) { throw 'Checks failed.' }
    if($Stage -eq 'Check') { exit 0 }
    if(-not (Run-Stage 'smoke' 'smoke' $false)) { throw 'Simulation smoke check failed.' }
    $mapReady=Test-Path -LiteralPath (Join-Path $repo 'Result\Controllers\Map\Calib_v2\TwoParam\selected.json')
    if($Stage -in @('All','Map')) {
        if(-not (Run-Stage 'map' 'map' $true)) { throw 'Map search failed.' }
        $mapReady=Run-Stage 'mapselect' 'mapselect' $false
    }
    if($Stage -eq 'S1') {
        if(-not (Run-Stage 'S1' 'S1' $true)) { throw 'S1 failed.' }
    }
    if($Stage -in @('All','S2')) {
        if(-not $mapReady) { Status 'BLOCKED: Map(2) has no selected design; S1 cache retained, S2 cannot start.'; exit 2 }
        if(-not (Run-Stage 'S2' 'S2' $true)) { throw 'S2 failed.' }
    }
    if($Stage -in @('All','Select')) {
        $s1=Join-Path $repo 'Result\Controllers\MapPID\Calib_v2\SixParam\S1_summary.mat'
        while(-not (Test-Path -LiteralPath $s1)) {
            Status 'S2 finished; waiting for laptop SixParam/S1_summary.mat and S1 CSVs; remote timer checks every 15 minutes.'
            Start-Sleep -Seconds 30
        }
        if(-not (Run-Stage 'select' 'select' $false)) { exit 2 }
    }
    Status "$Stage DONE; legacy DREWS disabled"
} catch { Status "FAILED: $($_.Exception.Message)"; throw }
finally { $lock.Dispose() }
