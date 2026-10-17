# Terminates every MATLAB process (win64) whose command line contains the text in the environment variable KILLMARK (the unique -batch expression of one job).
# A finished MATLAB can stay alive with 2 GB after heap corruption at exit, which blocks the RAM gate of the next job.
$mark = $env:KILLMARK
if ([string]::IsNullOrEmpty($mark)) { exit 0 }
Get-CimInstance Win32_Process | Where-Object { ($_.Name -like 'MATLAB*') -and $_.CommandLine -and $_.CommandLine.Contains($mark) } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
