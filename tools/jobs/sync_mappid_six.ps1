# Poll remote every 15 minutes, fast-forward only when local work is preserved.
param([int]$PeriodSeconds=900,[switch]$Once)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$state=Join-Path $repo 'scratch\jobs\mappid_six'
New-Item -ItemType Directory -Path $state -Force | Out-Null
$git=Join-Path $env:ProgramFiles 'Git\cmd\git.exe'
try { $lock=[IO.File]::Open((Join-Path $state 'sync.lock'),'OpenOrCreate','ReadWrite','None') }
catch { throw 'Six-variable remote timer already running.' }
function Log([string]$message) {
    Add-Content -LiteralPath (Join-Path $state 'sync.log') -Value "$(Get-Date -Format s) $message"
}
function Git-Command([string[]]$Arguments) {
    # Windows PowerShell treats native progress on stderr as an error record.
    # Git uses stderr on success too; decide by its exit code, not the stream.
    $previous=$ErrorActionPreference
    try { $ErrorActionPreference='Continue'; $lines=& $git -C $repo @Arguments 2>&1; $code=$LASTEXITCODE }
    finally { $ErrorActionPreference=$previous }
    if($code -ne 0) { throw "git $($Arguments -join ' ') exit=$code : $lines" }
    return @($lines | ForEach-Object { "$_" })
}
try {
    do {
        try {
            $fetch=Git-Command -Arguments @('fetch','origin','main')
            $incoming=@(Git-Command -Arguments @('diff','--name-only','HEAD..origin/main'))
            $local=@(Git-Command -Arguments @('diff','--name-only','HEAD'))
            $local+=@(Git-Command -Arguments @('ls-files','--others','--exclude-standard'))
            $overlap=@($incoming | Where-Object { $_ -in $local })
            if($overlap.Count -gt 0) {
                Log "FETCHED; merge deferred to preserve local changes: $($overlap -join ', ')"
            } else {
                $merge=Git-Command -Arguments @('merge','--ff-only','origin/main')
                Log "SYNC OK: $merge"
            }
        } catch { Log "SYNC ERROR: $($_.Exception.Message)" }
        if($Once) { break }
        # Timer is interruptible and does not hold a shell command open.
        for($elapsed=0;$elapsed -lt $PeriodSeconds;$elapsed+=30) { Start-Sleep -Seconds ([math]::Min(30,$PeriodSeconds-$elapsed)) }
    } while($true)
} finally { $lock.Dispose() }
