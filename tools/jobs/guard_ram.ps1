# RAM guard: logs free RAM every 20 s; if free RAM < KillGB, terminates the most recently started MATLAB (checkpoints/csv are kept, the job wrappers restart it later when memory is free).
param([double]$KillGB = 3.0, [int]$Period = 20, [int]$Cooldown = 60)
$log = Join-Path $PSScriptRoot 'ram_log.csv'
if (-not (Test-Path $log)) { 'time,free_gb,n_matlab,matlab_gb,event' | Out-File $log -Encoding ascii }
$lastKill = [datetime]'2000-01-01'
while ($true) {
    $os = Get-CimInstance Win32_OperatingSystem
    $free = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $m = @(Get-Process -Name MATLAB -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*win64*' })
    $gb = [math]::Round((($m | Measure-Object WorkingSet64 -Sum).Sum) / 1GB, 2)
    $ev = ''
    if ($free -lt $KillGB -and $m.Count -gt 0 -and ((Get-Date) - $lastKill).TotalSeconds -gt $Cooldown) {
        $v = $m | Sort-Object StartTime -Descending | Select-Object -First 1
        $ev = "KILL pid $($v.Id) ($([math]::Round($v.WorkingSet64/1GB,2)) GB)"
        Stop-Process -Id $v.Id -Force
        $lastKill = Get-Date
    }
    "{0},{1},{2},{3},{4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $free, $m.Count, $gb, $ev | Out-File $log -Append -Encoding ascii
    Start-Sleep -Seconds $Period
}
