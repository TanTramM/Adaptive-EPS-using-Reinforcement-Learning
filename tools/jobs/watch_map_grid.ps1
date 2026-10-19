# Persistent supervisor for the deterministic Map grid pipeline.
# It deliberately never kills MATLAB: worker-level recovery is handled by
# job_lib_patient.sh, which resumes from cached CSV/checkpoint data.
param(
    [int]$PollSeconds = 30,
    [int]$IdleMinutesBeforeRestart = 8
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scratch = Join-Path $repo 'scratch\jobs'
$statusFile = Join-Path $scratch 'map_grid_watchdog_status.txt'
$eventFile = Join-Path $scratch 'map_grid_watchdog_events.txt'
$doneFile = Join-Path $scratch 'map_grid_pipeline_done.txt'
$lockFile = Join-Path $scratch 'map_grid_pipeline_running.txt'
$bash = 'C:\Program Files\Git\usr\bin\bash.exe'
$idleSince = $null
$lastFault = ''
$launcher = $null

function Write-Watchdog([string]$Message) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
    Set-Content -LiteralPath $statusFile -Value $line
    Add-Content -LiteralPath $eventFile -Value $line
}

function Write-MapHistory([string]$Message) {
    # Only material recovery actions are appended; routine healthy polls stay in scratch.
    $history = Join-Path $repo 'Tracking\historychat_map.md'
    $entry = "`r`n`r`n### Watchdog Map ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))`r`n$Message`r`n"
    [System.IO.File]::AppendAllText($history, $entry, [System.Text.UTF8Encoding]::new($false))
}

function Get-ActiveMatlabCount {
    # MATLAB launcher stubs have a very small working set; exclude them.
    @(Get-Process -Name MATLAB -ErrorAction SilentlyContinue |
        Where-Object { $_.WorkingSet64 -ge 200MB }).Count
}

function Start-MapPipeline {
    if (-not (Test-Path -LiteralPath $bash)) {
        throw "Git Bash was not found: $bash"
    }
    $command = "cd '$($repo -replace '\\','/')' && bash tools/jobs/map_grid_pipeline.sh"
    $script:launcher = Start-Process -FilePath $bash -ArgumentList '-lc', $command -WindowStyle Hidden -PassThru
    Write-Watchdog "RESTARTED pipeline (bash PID $($launcher.Id)); cached Map designs/checkpoints are reused."
    Write-MapHistory "Watchdog restarted Map grid after an idle/failure condition; cached CSV/checkpoint data are retained."
}

Write-Watchdog "STARTED; polling every $PollSeconds s, idle restart threshold $IdleMinutesBeforeRestart min."
while ($true) {
    if (Test-Path -LiteralPath $doneFile) {
        Write-Watchdog 'DONE: map_grid_pipeline_done.txt found; watchdog exits.'
        exit 0
    }

    $fault = Get-ChildItem -LiteralPath $scratch -Filter 'map_grid_*_failed.txt' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($fault) {
        $signature = "$($fault.Name):$($fault.LastWriteTimeUtc.Ticks)"
        if ($signature -ne $lastFault) {
            $lastFault = $signature
            Write-Watchdog "RECOVERY: $($fault.Name) detected. A fresh pipeline attempt will reuse completed work after the idle guard."
            Write-MapHistory "Watchdog detected $($fault.Name); it will restart the Map pipeline after the idle guard and preserve completed work."
        }
    }

    $active = Get-ActiveMatlabCount
    $lockPresent = Test-Path -LiteralPath $lockFile
    if ($active -gt 0 -or $lockPresent) {
        $idleSince = $null
        Set-Content -LiteralPath $statusFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') HEALTHY: $active active MATLAB worker(s); pipeline lock=$lockPresent."
    }
    else {
        if ($null -eq $idleSince) {
            $idleSince = Get-Date
            Write-Watchdog 'IDLE: no active MATLAB worker or pipeline lock; starting grace period.'
        }
        $idleMinutes = ((Get-Date) - $idleSince).TotalMinutes
        if ($idleMinutes -ge $IdleMinutesBeforeRestart) {
            $runningLauncher = $launcher -and -not $launcher.HasExited
            if (-not $runningLauncher) {
                Start-MapPipeline
                $idleSince = $null
            }
        }
        else {
            Set-Content -LiteralPath $statusFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') IDLE: $([Math]::Round($idleMinutes,1))/$IdleMinutesBeforeRestart min grace period."
        }
    }
    Start-Sleep -Seconds $PollSeconds
}
