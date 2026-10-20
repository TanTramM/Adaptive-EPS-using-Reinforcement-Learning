# Internal worker used by start_mappid_laptop.ps1. Do not launch directly.
param(
    [ValidateSet('S1','S2')][string]$Stage,
    [ValidateRange(1,7)][int]$WorkerId,
    [ValidateRange(1,7)][int]$Workers,
    [string]$MatlabExe,
    [int]$MinHeadroomGB = 3
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$state = Join-Path $repo 'scratch\jobs\mappid_laptop'
New-Item -ItemType Directory -Path $state -Force | Out-Null
$lockPath = Join-Path $state "${Stage}_w${WorkerId}_of${Workers}.lock"
try { $lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') }
catch { throw "MapPID $Stage worker $WorkerId/$Workers is already active." }

$tempDir = Join-Path ([IO.Path]::GetTempPath()) "AdaptiveEPS_MapPID_w${WorkerId}"
$prefDir = Join-Path $tempDir 'MATLAB_R2023a_prefs'
New-Item -ItemType Directory -Path $prefDir -Force | Out-Null
$env:TEMP = $tempDir
$env:TMP = $tempDir
$env:MATLAB_PREFDIR = $prefDir
$repoMatlab = $repo.Replace('\','/').Replace("'", "''")

function Get-MemoryHeadroomGB {
    if (-not ('NativeMemoryStatus' -as [type])) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class NativeMemoryStatus {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    public class MEMORYSTATUSEX {
        public uint dwLength = (uint)Marshal.SizeOf(typeof(MEMORYSTATUSEX));
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
    }
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GlobalMemoryStatusEx([In, Out] MEMORYSTATUSEX buffer);
}
'@
    }
    $memory = New-Object NativeMemoryStatus+MEMORYSTATUSEX
    if (-not [NativeMemoryStatus]::GlobalMemoryStatusEx($memory)) { throw 'GlobalMemoryStatusEx failed.' }
    [math]::Min($memory.ullAvailPhys, $memory.ullAvailPageFile) / 1GB
}

try {
    $done = Join-Path $state "${Stage}_w${WorkerId}_of${Workers}.done"
    if (Test-Path -LiteralPath $done) { Write-Output "$Stage worker $WorkerId/$Workers already complete"; exit 0 }
    $attempt = 0
    $realErrors = 0
    while ($true) {
        while ((Get-MemoryHeadroomGB) -lt $MinHeadroomGB) {
            Set-Content -LiteralPath (Join-Path $state "status_${Stage}_w${WorkerId}.txt") -Value "$Stage worker $WorkerId/$Workers waiting for $MinHeadroomGB GB headroom"
            Start-Sleep -Seconds 30
        }
        $attempt++
        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
        $stdout = Join-Path $state "${Stage}_w${WorkerId}_${stamp}.out.log"
        $stderr = Join-Path $state "${Stage}_w${WorkerId}_${stamp}.err.log"
        $marker = "MAPPID_LAPTOP_${Stage}_W${WorkerId}_DONE"
        $expr = "run('$repoMatlab/Model/setup_paths.m'); run_mappid_grid('$Stage',$WorkerId,$Workers); disp('$marker')"
        Set-Content -LiteralPath (Join-Path $state "status_${Stage}_w${WorkerId}.txt") -Value "$Stage worker $WorkerId/$Workers attempt=$attempt running at $(Get-Date -Format s)"
        $launchTime = Get-Date
        $process = Start-Process -FilePath $MatlabExe -ArgumentList @('-softwareopengl','-batch',('"' + $expr + '"')) -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
        while (-not $process.HasExited) { Start-Sleep -Seconds 15; $process.Refresh() }
        $process.WaitForExit()
        $process.Refresh()
        $log = (Get-Content -LiteralPath $stdout,$stderr -Raw -ErrorAction SilentlyContinue) -join "`n"
        if ($log.Contains($marker)) {
            Set-Content -LiteralPath $done -Value "Verified marker in $stdout / $stderr"
            Set-Content -LiteralPath (Join-Path $state "status_${Stage}_w${WorkerId}.txt") -Value "$Stage worker $WorkerId/$Workers complete"
            exit 0
        }
        # Workers are staggered. Only processes born with this launch are its engine.
        Get-Process -Name MATLAB -ErrorAction SilentlyContinue | Where-Object {
            $_.StartTime -ge $launchTime.AddSeconds(-2) -and $_.StartTime -le $launchTime.AddSeconds(5)
        } | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
        $crash = $log -match '0xc0000374|0xffffffff|0xc0000005|out of memory|OutOfMemory'
        if (-not $crash -and $process.ExitCode -ne 0) { $realErrors++ }
        Set-Content -LiteralPath (Join-Path $state "status_${Stage}_w${WorkerId}.txt") -Value "$Stage worker $WorkerId/$Workers interrupted exit=$($process.ExitCode), realErrors=$realErrors"
        if ($realErrors -ge 3) { throw "$Stage worker $WorkerId/$Workers failed three times; inspect $stdout and $stderr." }
        Start-Sleep -Seconds 60
    }
}
finally { $lock.Dispose() }
