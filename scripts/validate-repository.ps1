[CmdletBinding()]
param([string]$Root = (Split-Path -Parent $PSScriptRoot), [switch]$SkipManifest)
$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
function Assert-True($Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-NumberId([string]$Id) {
    Assert-True ($Id -match '^NUM-([0-9]{5})$') "Invalid synthetic identifier: $Id"
    return [int]$Matches[1]
}
$files = @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File)
Assert-True ($files.Count -gt 0) 'The repository folder is empty.'
foreach ($item in @(Get-ChildItem -LiteralPath $Root -Recurse -Force)) {
    Assert-True (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) "Linked paths are not allowed: $($item.FullName)"
    Assert-True ($item.Name -ne '.git') 'Use the clean extracted package, not an existing Git working tree.'
}
if (-not $SkipManifest) {
    $manifestPath = Join-Path $Root 'repository-manifest.json'
    Assert-True (Test-Path -LiteralPath $manifestPath) 'Missing repository-manifest.json. Obtain the complete package.'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $entries = @($manifest.files | Where-Object { $null -ne $_ })
    Assert-True ($manifest.schema -eq 1 -and $entries.Count -gt 0) 'Manifest is empty or unsupported.'
    $seen = @{}
    foreach ($entry in $entries) {
        $path = [string]$entry.path
        Assert-True ($path -match '^[A-Za-z0-9_.\-/]+$' -and $path -notmatch '(^|/)\.\.(/|$)' -and $path -notmatch '^/' -and $path -ne 'repository-manifest.json') "Unsafe manifest path: $path"
        Assert-True (-not $seen.ContainsKey($path)) "Duplicate manifest path: $path"
        $seen[$path] = $true
        $local = Join-Path $Root $path
        Assert-True (Test-Path -LiteralPath $local -PathType Leaf) "Missing package file: $path"
        Assert-True ((Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash.ToLowerInvariant() -eq $entry.sha256) "Package file changed: $path. Review it and intentionally regenerate the manifest before publishing."
    }
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($Root.TrimEnd([char[]]'\/').Length + 1).Replace('\','/')
        Assert-True ($relative -eq 'repository-manifest.json' -or $seen.ContainsKey($relative)) "Unlisted file: $relative. Remove it or intentionally review and update the manifest."
    }
}
# Findings report location only, never the potentially sensitive value.
$patterns = @('gh[pousr]_[A-Za-z0-9]{30,}', 'github_pat_[A-Za-z0-9_]{30,}', 'AKIA[A-Z0-9]{16}', '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----', '(?i)(password|api_key|client_secret)\s*[:=]\s*["''][^"'']{8,}["'']', '\+[0-9][0-9 ().-]{8,}[0-9]', '\b[0-9]{10,15}\b', '(?i)\b[A-Z0-9._%+-]+@(?!users\.noreply\.github\.com\b)[A-Z0-9.-]+\.[A-Z]{2,}\b')
foreach ($file in $files) {
    if ($file.Name -eq 'repository-manifest.json') { continue }
    Assert-True ($file.Extension -in @('.md','.csv','.ps1','.json') -or $file.Name -in @('LICENSE','.gitignore')) "Unexpected file type: $($file.Name)"
    $lineNumber = 0
    foreach ($line in @(Get-Content -LiteralPath $file.FullName)) {
        $lineNumber++
        foreach ($pattern in $patterns) { Assert-True (-not ($line -match $pattern)) "Possible sensitive content at $($file.Name):$lineNumber. Review privately; the value is not printed." }
    }
}
foreach ($file in @($files | Where-Object { $_.Extension -eq '.md' })) {
    foreach ($match in [regex]::Matches((Get-Content -LiteralPath $file.FullName -Raw), '\[[^\]]*\]\(([^)]+)\)')) {
        $link = $match.Groups[1].Value
        if ($link -match '^(https?://|#)') { continue }
        Assert-True ($link -notmatch '[#?]' -and (Test-Path -LiteralPath (Join-Path $file.DirectoryName $link) -PathType Leaf)) "Broken/unsupported local link in $($file.Name): $link"
    }
}
$inventory = @(Import-Csv -LiteralPath (Join-Path $Root 'data/inventory.csv'))
Assert-True ($inventory.Count -eq 20) 'Expected 20 synthetic sites.'
$next = 1; $total = 0
foreach ($row in $inventory) {
    $first = Get-NumberId $row.start_id; $last = Get-NumberId $row.end_id
    $sum = [int]$row.standard + [int]$row.contact_center + [int]$row.emergency_associated + [int]$row.special
    Assert-True ($first -eq $next -and $last -ge $first -and $last - $first + 1 -eq [int]$row.total -and $sum -eq [int]$row.total) "Inventory range/count error at $($row.site)"
    Assert-True ($row.standard -eq 800 -and $row.contact_center -eq 100 -and $row.emergency_associated -eq 50 -and $row.special -eq 50) 'Update the case narrative when changing category assumptions.'
    $total += $sum; $next = $last + 1
}
Assert-True ($total -eq 20000 -and $next -eq 20001) 'Inventory does not reconcile to 20,000.'
$waves = @(Import-Csv -LiteralPath (Join-Path $Root 'data/waves.csv'))
$expectedCounts = @(100,1900,4000,6000,8000); $expectedWeeks = @('7','8-9','10-11','12-13','14-15')
Assert-True ($waves.Count -eq 5) 'Expected five waves.'
$next = 1; $total = 0
for ($i = 0; $i -lt $waves.Count; $i++) {
    $row = $waves[$i]; $first = Get-NumberId $row.start_id; $last = Get-NumberId $row.end_id
    Assert-True ($first -eq $next -and $last - $first + 1 -eq [int]$row.count -and [int]$row.count -eq $expectedCounts[$i] -and $row.weeks -eq $expectedWeeks[$i]) "Wave range/count/schedule error: $($row.wave)"
    $next = $last + 1; $total += [int]$row.count
}
Assert-True ($total -eq 20000 -and $next -eq 20001) 'Wave coverage does not reconcile.'
foreach ($row in @(Import-Csv -LiteralPath (Join-Path $Root 'data/raci.csv'))) {
    $accountable = 0; $responsible = 0
    foreach ($property in $row.PSObject.Properties) {
        if ($property.Name -eq 'activity') { continue }
        Assert-True ($property.Value -in @('A','R','C','I','A/R')) "Invalid RACI value: $($row.activity)"
        if ($property.Value -in @('A','A/R')) { $accountable++ }
        if ($property.Value -in @('R','A/R')) { $responsible++ }
    }
    Assert-True ($accountable -eq 1 -and $responsible -ge 1) "RACI needs one A and at least one R: $($row.activity)"
}
$risks = @(Import-Csv -LiteralPath (Join-Path $Root 'data/risks.csv'))
Assert-True ($risks.Count -eq 12 -and @($risks.id | Select-Object -Unique).Count -eq 12) 'Risk IDs/count mismatch.'
foreach ($row in $risks) { foreach ($property in $row.PSObject.Properties) { Assert-True (-not [string]::IsNullOrWhiteSpace($property.Value)) "Missing risk field: $($row.id) / $($property.Name)" } }
$cost = @{}
foreach ($row in @(Import-Csv -LiteralPath (Join-Path $Root 'data/cost-assumptions.csv'))) {
    Assert-True (-not $cost.ContainsKey($row.key)) "Duplicate cost key: $($row.key)"
    $cost[$row.key] = [decimal]$row.value
}
Assert-True ($cost.Count -eq 5 -and $cost.billable_seats -eq 12000 -and $cost.baseline_monthly -eq 18 -and $cost.target_monthly -eq 16 -and $cost.implementation -eq 210000 -and $cost.overlap -eq 90000) 'Cost assumptions differ from the narrative.'
$monthly = $cost.billable_seats * ($cost.baseline_monthly - $cost.target_monthly)
Assert-True ($monthly * 12 -eq 288000 -and ($cost.implementation + $cost.overlap) / $monthly -eq 12.5) 'Cost/payback calculation failed.'
Write-Host 'PASS: integrity, selected sensitive patterns, local links, 20,000 IDs, wave coverage/schedule, RACI, risk fields and costs.'
