# Bounded heartbeat recovery for the disjoint Map2 Dense remainder batches.
param([int]$Workers=5,[int]$PollSeconds=120,[int]$StaleMinutes=20)
$ErrorActionPreference='Stop'; $repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scratch=Join-Path $repo 'scratch\jobs\map2_dense'; $out=Join-Path $repo 'Result\Controllers\Map\Calib_v2\TwoParamDense'; $matlab='C:\Program Files\MATLAB\R2023a\bin\matlab.exe'
$lock=Join-Path $scratch 'resume_batches_guardian.lock'; if(Test-Path $lock){throw 'resume batches guardian already exists'}; New-Item -ItemType File -Path $lock|Out-Null
try { while($true) {
 $m=Import-Csv (Join-Path $out 'Map2_Dense_resume_manifest.csv'); $allDone=$true
 foreach($i in 1..$Workers){
  $want=0; for($j=0;$j -lt @($m).Count;$j++){ if(($j % $Workers) -eq ($i-1)){$want++} }
  $csv=Join-Path $out "Map2_Dense_measurements_resume_w$i.csv"; $have=if(Test-Path $csv){@(Import-Csv $csv).Count}else{0}
  if($have -ge $want){continue}; $allDone=$false
  $log=Join-Path $scratch "resume_batch_w$i.log"; $age=if(Test-Path $log){((Get-Date)-(Get-Item $log).LastWriteTime).TotalMinutes}else{1e6}
  if($age -ge $StaleMinutes){
   "$(Get-Date -Format s) RESUME worker=$i have=$have/$want launch"|Add-Content (Join-Path $scratch 'resume_batches_events.log')
   $expr="run('$($repo.Replace('\','/'))/Model/setup_paths.m'); run_map2_dense($i,$Workers,'$($out.Replace('\','/'))/Map2_Dense_resume_manifest.csv','resume');"
   Start-Process -FilePath $matlab -ArgumentList '-softwareopengl','-logfile',$log,'-batch',('"'+$expr+'"') -WindowStyle Hidden|Out-Null
  }
 }
 if($allDone){break}; Start-Sleep -Seconds $PollSeconds
} } finally {Remove-Item -LiteralPath $lock -Force -ErrorAction SilentlyContinue}
