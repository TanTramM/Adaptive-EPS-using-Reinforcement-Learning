# Postflight verifier for the Map2-only job. It waits; it never changes a
# controller design and only reruns the idempotent finalizer if artifacts are missing.
param([int]$PollSeconds = 180)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scratch=Join-Path $repo 'scratch\jobs\map2_dense'
$out=Join-Path $repo 'Result\Controllers\Map\Calib_v2\TwoParamDense'
$matlab='C:\Program Files\MATLAB\R2023a\bin\matlab.exe'
$lock=Join-Path $scratch 'postflight_guardian.lock'
if(Test-Path $lock){throw "Map2 postflight guardian already exists: $lock"}; New-Item -ItemType File -Path $lock|Out-Null
try {
 while($true){
  $status=Get-Content (Join-Path $scratch 'status.txt') -Raw -ErrorAction SilentlyContinue
  if($status -match 'COMPLETE'){break}; Start-Sleep -Seconds $PollSeconds
 }
 $need=@('Map2_Dense_constraints.csv','Map2_Dense_violation_pareto.csv','Map2_Dense_selection_summary.json','Map2_Dense_report.md','Map2_Dense_selection_multiseed_nominal.csv')
 for($attempt=0;$attempt -lt 2;$attempt++){
  $missing=@($need|Where-Object{ -not (Test-Path (Join-Path $out $_)) })
  if($missing.Count -eq 0){ "$(Get-Date -Format s) PASS"|Set-Content (Join-Path $scratch 'postflight.status'); break }
  "$(Get-Date -Format s) missing=$($missing -join ','); finalizer retry=$($attempt+1)"|Add-Content (Join-Path $scratch 'postflight.status')
  $log=Join-Path $scratch "postflight_finalize_$($attempt+1).log"
  $expr="run('$($repo.Replace('\','/'))/Model/setup_paths.m'); finalize_map2_dense;"
  $p=Start-Process -FilePath $matlab -ArgumentList '-softwareopengl','-logfile',$log,'-batch',('"'+$expr+'"') -WindowStyle Hidden -PassThru
  $p.WaitForExit()
 }
} finally {Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue}
