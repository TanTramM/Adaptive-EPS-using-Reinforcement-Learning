# RAM guard: preserve either an explicit reserve or 10% of physical RAM.
# If the guard must stop MATLAB, cached CSV/checkpoint work is resumed later.
param([double]$KillGB = 0, [ValidateRange(0.05,0.50)][double]$ReserveRamFraction = 0.10, [int]$Period = 20, [int]$Cooldown = 60)
$log = Join-Path $PSScriptRoot 'ram_log.csv'
if (-not (Test-Path $log)) { 'time,free_gb,n_matlab,matlab_gb,event' | Out-File $log -Encoding ascii }
$lastKill = [datetime]'2000-01-01'
while ($true) {
    # A transient CIM failure used to coerce $null to 0 GB and kill a healthy
    # MATLAB process. A missing reading is now logged but never acted on.
    $free = $null
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $free = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
        $reserveGB = if ($KillGB -gt 0) { $KillGB } else { [math]::Round(($os.TotalVisibleMemorySize / 1MB) * $ReserveRamFraction, 2) }
    } catch {
        $free = $null
    }
    $m = @(Get-Process -Name MATLAB -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*win64*' })
    $gb = [math]::Round((($m | Measure-Object WorkingSet64 -Sum).Sum) / 1GB, 2)
    $ev = ''
    if ($null -ne $free -and $free -lt $reserveGB -and $m.Count -gt 0 -and ((Get-Date) - $lastKill).TotalSeconds -gt $Cooldown) {
        $v = $m | Sort-Object StartTime -Descending | Select-Object -First 1
        $ev = "KILL pid $($v.Id) ($([math]::Round($v.WorkingSet64/1GB,2)) GB)"
        Stop-Process -Id $v.Id -Force
        $lastKill = Get-Date
    }
    $freeText = if ($null -eq $free) { 'NA' } else { [string]$free }
    "{0},{1},{2},{3},{4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $freeText, $m.Count, $gb, $ev | Out-File $log -Append -Encoding ascii
    Start-Sleep -Seconds $Period
}
