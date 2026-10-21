# Map2 Dense heartbeat guardian.  It never kills MATLAB; a stale partition is
# resumed only after a conservative timeout, so a long Simulink run is not
# mistaken for a crash.  Checkpoints make reruns idempotent at candidate level.
param([int]$Workers = 5, [int]$StaleMinutes = 20, [int]$PollSeconds = 120)
$ErrorActionPreference = 'Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scratch=Join-Path $repo 'scratch\jobs\map2_dense'
$out=Join-Path $repo 'Result\Controllers\Map\Calib_v2\TwoParamDense'
$matlab='C:\Program Files\MATLAB\R2023a\bin\matlab.exe'
$guardian=Join-Path $scratch 'heartbeat_guardian.lock'
if(Test-Path $guardian){ throw "Map2 heartbeat guardian already exists: $guardian" }
New-Item -ItemType File -Path $guardian | Out-Null
try {
  while($true){
    $status=Get-Content (Join-Path $scratch 'status.txt') -Raw -ErrorAction SilentlyContinue
    if($status -match 'COMPLETE'){ break }
    foreach($i in 1..$Workers){
      $log=Join-Path $scratch "worker_$i.log"
      if(!(Test-Path $log)){ continue }
      $text=Get-Content $log -Raw
      if($text -match "MAP2_DENSE_WORKER_DONE $i"){ continue }
      $age=((Get-Date)-(Get-Item $log).LastWriteTime).TotalMinutes
      if($age -lt $StaleMinutes){ continue }
      $recoveries=Get-ChildItem -LiteralPath $scratch -Filter "recovery_w${i}_*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
      if($recoveries | Where-Object { (Get-Content $_.FullName -Raw) -match "MAP2_DENSE_WORKER_DONE $i" }){ continue }
      if($recoveries.Count -ge 2){
        "$(Get-Date -Format s) UNRESOLVED worker=$i retries=2; no further automatic launch" | Add-Content (Join-Path $scratch 'heartbeat_events.log')
        continue
      }
      if($recoveries.Count -gt 0 -and ((Get-Date)-$recoveries[0].LastWriteTime).TotalMinutes -lt $StaleMinutes){ continue }
      $attempt=Join-Path $scratch ("recovery_w{0}_{1:yyyyMMdd_HHmmss}.log" -f $i,(Get-Date))
      "$(Get-Date -Format s) STALE worker=$i ageMin=$([math]::Round($age,1)); resume launched" | Add-Content (Join-Path $scratch 'heartbeat_events.log')
      $expr="run('$($repo.Replace('\','/'))/Model/setup_paths.m'); run_map2_dense($i,$Workers);"
      Start-Process -FilePath $matlab -ArgumentList '-softwareopengl','-logfile',$attempt,'-batch',('"'+$expr+'"') -WindowStyle Hidden | Out-Null
      # Give the resumed MATLAB time to create its first log before another poll.
      Start-Sleep -Seconds $PollSeconds
    }
    Start-Sleep -Seconds $PollSeconds
  }
} finally { Remove-Item -LiteralPath $guardian -Force -ErrorAction SilentlyContinue }
