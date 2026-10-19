param([switch]$CheckOnly, [int]$PollSeconds = 60)
. (Join-Path $PSScriptRoot 'map_handoff_common.ps1')
$state = Join-Path $repo 'scratch/jobs/map_handoff_desktop'
if ($CheckOnly) {
    Write-Output "Publisher preflight: repo=$repo; branch=$handoffBranch; git=$gitExe; no MATLAB launched"
    exit 0
}
$lock = Open-HandoffLock $state
$oldIndex = $env:GIT_INDEX_FILE
try {
    while (-not (Test-Path -LiteralPath (Join-Path $repo 'scratch/jobs/map_grid_pipeline_done.txt'))) {
        Write-State 'WAIT_MAP: waiting for the existing Map pipeline to finish'
        Start-Sleep -Seconds $PollSeconds
    }
    $null = Test-MapPair (Join-Path $repo $mapJsonPath) (Join-Path $repo $mapPickPath)
    $baseCommit = Git-Text rev-parse HEAD
    $payload = @($mapJsonPath, $mapPickPath)
    $payload += @(Get-ChildItem -LiteralPath (Join-Path $repo 'Result/Controllers/Map/Calib_v2') -File | Where-Object {
        $_.Name -match '^Map_CALIB_pareto(_s00000\.(csv|png)|_check_s00001-s00005\.csv)$'
    } | ForEach-Object { 'Result/Controllers/Map/Calib_v2/' + $_.Name })
    if ($payload.Count -lt 5) { throw 'Map Pareto CSV, PNG and five-seed report are required.' }
    # A private index snapshots only the handoff payload; the user's index/HEAD stay intact.
    $env:GIT_INDEX_FILE = Join-Path $state ('index_' + [guid]::NewGuid().ToString('N'))
    $null = Git-Text read-tree $baseCommit
    $null = Git-Text add -- @payload
    $files = @()
    foreach ($path in $payload) {
        $baseline = ''
        try { $baseline = Git-Text rev-parse "${baseCommit}:$path" } catch { }
        $files += [ordered]@{ path=$path; blob=(Git-Text rev-parse ":$path"); baseline=$baseline }
    }
    # Freeze all MATLAB sources used by the laptop; consumer rejects code drift.
    $code = @()
    foreach ($path in ((Git-Text ls-tree -r --name-only $baseCommit -- Model) -split "`n")) {
        if ($path -match '\.(m|mdl|json)$' -and $path -notin @($mapJsonPath,'Model/data/mappid.json')) {
            $code += [ordered]@{ path=$path; blob=(Git-Text rev-parse "${baseCommit}:$path") }
        }
    }
    $manifest = [ordered]@{ schema=1; ready=$true; created=(Get-Date -Format s); base_commit=$baseCommit; files=$files; code=$code; drews=$false }
    $manifestFile = Join-Path $state 'map_s2_ready.json'
    [IO.File]::WriteAllText($manifestFile, ($manifest | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
    $blob = Git-Text hash-object -w -- $manifestFile
    $null = Git-Text update-index --add --cacheinfo "100644,$blob,$manifestPath"
    $tree = Git-Text write-tree
    $parents = @('-p', $baseCommit)
    while ($true) {
        try {
            $existing = Git-Text ls-remote origin "refs/heads/$handoffBranch"
            if ($existing) {
                $null = Git-Text fetch origin "refs/heads/${handoffBranch}:refs/remotes/origin/$handoffBranch"
                $previous = Git-Text rev-parse "refs/remotes/origin/$handoffBranch"
                if ($previous -ne $baseCommit) { $parents += @('-p', $previous) }
            }
            break
        } catch { Write-State "REMOTE_RETRY: $_"; Start-Sleep -Seconds $PollSeconds }
    }
    $commit = Git-Text commit-tree $tree @parents -m 'Map: selected design ready for laptop S2'
    $null = Git-Text update-ref "refs/heads/$handoffBranch" $commit
    while ($true) {
        try {
            $null = Git-Text push origin "${commit}:refs/heads/$handoffBranch"
            $remote = Git-Text ls-remote origin "refs/heads/$handoffBranch"
            if (-not $remote.StartsWith($commit)) { throw 'Remote commit verification failed.' }
            Write-State "PUBLISHED: $commit on $handoffBranch; laptop may run S2"
            [IO.File]::WriteAllText((Join-Path $state 'published.done'), $commit)
            break
        } catch { Write-State "PUSH_RETRY: $_"; Start-Sleep -Seconds $PollSeconds }
    }
} catch { Write-State "FAILED: $_"; throw }
finally { $env:GIT_INDEX_FILE = $oldIndex; $lock.Dispose() }
