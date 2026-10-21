# Recovery supervisor for Map2 Dense.  It does not own or stop existing MATLAB
# workers; instead it verifies global manifest coverage, leaving heartbeat
# recovery to watch_map2_dense_heartbeat.ps1, then runs the idempotent finalizer.
param([int]$PollSeconds = 120)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scratch = Join-Path $repo 'scratch\jobs\map2_dense'
$out = Join-Path $repo 'Result\Controllers\Map\Calib_v2\TwoParamDense'
$matlab = 'C:\Program Files\MATLAB\R2023a\bin\matlab.exe'
$lock = Join-Path $scratch 'resume_supervisor.lock'
if (Test-Path $lock) { throw "Map2 resume supervisor lock exists: $lock" }
New-Item -ItemType File -Path $lock | Out-Null
try {
  $manifest = Import-Csv (Join-Path $out 'Map2_Dense_manifest.csv')
  $expected = @($manifest | ForEach-Object key | Sort-Object -Unique)
  while ($true) {
    $seen = @()
    Get-ChildItem -LiteralPath $out -Filter 'Map2_Dense_measurements*.csv' -ErrorAction SilentlyContinue | ForEach-Object {
      $seen += @(Import-Csv -LiteralPath $_.FullName | ForEach-Object key)
    }
    $unique = @($seen | Where-Object { $_ } | Sort-Object -Unique)
    $missing = @($expected | Where-Object { $_ -notin $unique })
    "$(Get-Date -Format s) RUN verified=$($unique.Count)/$($expected.Count) missing=$($missing.Count)" | Set-Content (Join-Path $scratch 'status.txt')
    if ($missing.Count -eq 0) { break }
    Start-Sleep -Seconds $PollSeconds
  }
  "$(Get-Date -Format s) FINALIZING verified=$($expected.Count)" | Set-Content (Join-Path $scratch 'status.txt')
  $log = Join-Path $scratch 'finalize.log'
  $expr = "run('$($repo.Replace('\','/'))/Model/setup_paths.m'); finalize_map2_dense;"
  $p = Start-Process -FilePath $matlab -ArgumentList '-softwareopengl','-logfile',$log,'-batch',('"'+$expr+'"') -WindowStyle Hidden -PassThru
  $p.WaitForExit()
  $text = if (Test-Path $log) { Get-Content $log -Raw } else { '' }
  if ($text -notmatch 'MAP2_DENSE_FINAL_DONE') { throw 'Map2 finalizer exited without completion marker; see finalize.log.' }
  "$(Get-Date -Format s) COMPLETE verified=$($expected.Count)" | Set-Content (Join-Path $scratch 'status.txt')
} finally { Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue }
