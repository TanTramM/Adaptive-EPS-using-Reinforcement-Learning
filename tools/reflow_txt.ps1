param([string]$Src, [string]$Dst, [int]$Limit = 195)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$lines = [System.IO.File]::ReadAllLines($Src, $utf8)
$out = New-Object System.Collections.Generic.List[string]
foreach ($ln in $lines) {
    if ($ln -eq '@@SEP=') { $out.Add('=' * 190); continue }
    if ($ln -eq '@@SEP-') { $out.Add('-' * 190); continue }
    if (-not $ln.StartsWith('@@')) { $out.Add($ln); continue }
    $t = $ln.Substring(2)
    if ($t.StartsWith('- ')) { $first = '  - '; $cont = '    '; $t = $t.Substring(2) }
    else { $first = '  '; $cont = '  ' }
    $words = $t -split ' +'
    $cur = $first
    $curHasWord = $false
    foreach ($w in $words) {
        if ($w -eq '') { continue }
        if (-not $curHasWord) { $cur = $cur + $w; $curHasWord = $true; continue }
        if (($cur.Length + 1 + $w.Length) -le $Limit) { $cur = $cur + ' ' + $w }
        else { $out.Add($cur); $cur = $cont + $w }
    }
    $out.Add($cur)
}
[System.IO.File]::WriteAllLines($Dst, $out, $utf8)
$maxLen = 0; $over = 0
foreach ($l in $out) { if ($l.Length -gt $maxLen) { $maxLen = $l.Length }; if ($l.Length -gt 200) { $over++ } }
"lines=$($out.Count) maxLen=$maxLen over200=$over"
