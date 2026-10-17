# Prints the memory headroom in whole GB: the smaller of the free physical RAM and (commit limit - committed bytes).
$f = [math]::Floor((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB)
$c = (Get-Counter '\Memory\Committed Bytes', '\Memory\Commit Limit').CounterSamples
$h = [math]::Floor(($c[1].CookedValue - $c[0].CookedValue) / 1GB)
[math]::Min($f, $h)
