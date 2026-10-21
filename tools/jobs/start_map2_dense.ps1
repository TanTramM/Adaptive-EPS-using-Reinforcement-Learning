# Map2_Dense_v1 supervisor.  It owns only MATLAB processes launched by this script.
param([int]$MaxWorkers = 6, [switch]$ShutdownWhenComplete)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scratch = Join-Path $repo 'scratch\jobs\map2_dense'
$out = Join-Path $repo 'Result\Controllers\Map\Calib_v2\TwoParamDense'
$matlab = 'C:\Program Files\MATLAB\R2023a\bin\matlab.exe'
New-Item -ItemType Directory -Force -Path $scratch | Out-Null
$lock = Join-Path $scratch 'supervisor.lock'
if (Test-Path $lock) { throw "Map2 Dense supervisor lock exists: $lock" }
New-Item -ItemType File -Path $lock | Out-Null
try {
  $mem = Get-CimInstance Win32_OperatingSystem
  $total = $mem.TotalVisibleMemorySize / 1MB
  $used = $total - $mem.FreePhysicalMemory / 1MB
  # A clean Map2 MATLAB worker was observed at about 2.35 GB in preflight.
  # Pick a conservative count that targets <=90% total RAM and preserves >=10%.
  $budget = 0.90 * $total - $used
  $workers = [Math]::Max(1, [Math]::Min($MaxWorkers, [Math]::Floor($budget / 2.5)))
  $workers = [Math]::Min($workers, 6)
  $status = Join-Path $scratch 'status.txt'
  "$(Get-Date -Format s) START workers=$workers totalGB=$([Math]::Round($total,2)) usedGB=$([Math]::Round($used,2))" | Set-Content $status
  $jobs = @{}
  for ($i=1; $i -le $workers; $i++) {
    $log = Join-Path $scratch "worker_$i.log"
    $expr = "run('$($repo.Replace('\','/'))/Model/setup_paths.m'); run_map2_dense($i,$workers);"
    $p = Start-Process -FilePath $matlab -ArgumentList '-softwareopengl','-logfile',$log,'-batch',('"' + $expr + '"') -WindowStyle Hidden -PassThru
    $jobs[$i] = @{ Process=$p; Retries=0; Log=$log }
  }
  while ($jobs.Count -gt 0) {
    Start-Sleep -Seconds 15
    $mem = Get-CimInstance Win32_OperatingSystem
    $freePct = 100 * $mem.FreePhysicalMemory / $mem.TotalVisibleMemorySize
    "$(Get-Date -Format s) RUN workers=$($jobs.Count) freePct=$([Math]::Round($freePct,1))" | Set-Content $status
    foreach ($i in @($jobs.Keys)) {
      $j = $jobs[$i]
      if (-not $j.Process.HasExited) { continue }
      $text = if (Test-Path $j.Log) { Get-Content $j.Log -Raw } else { '' }
      if ($text -match "MAP2_DENSE_WORKER_DONE $i") { $jobs.Remove($i); continue }
      if ($j.Retries -ge 2) { throw "worker $i failed three times; see $($j.Log)" }
      $j.Retries++
      Start-Sleep -Seconds 60
      $expr = "run('$($repo.Replace('\','/'))/Model/setup_paths.m'); run_map2_dense($i,$workers);"
      $j.Process = Start-Process -FilePath $matlab -ArgumentList '-softwareopengl','-logfile',$j.Log,'-batch',('"' + $expr + '"') -WindowStyle Hidden -PassThru
      $jobs[$i] = $j
    }
  }
  & $matlab -softwareopengl -batch "run('$($repo.Replace('\','/'))/Model/setup_paths.m'); finalize_map2_dense;" | Out-File (Join-Path $scratch 'finalize.log')
  "$(Get-Date -Format s) COMPLETE" | Set-Content $status
  if ($ShutdownWhenComplete) { Stop-Computer -Force }
} finally { Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue }
