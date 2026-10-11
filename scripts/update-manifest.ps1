[CmdletBinding()]
param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
& (Join-Path $PSScriptRoot 'validate-repository.ps1') -Root $Root -SkipManifest
$entries = @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File | Where-Object { $_.Name -ne 'repository-manifest.json' } | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = $_.FullName.Substring($Root.TrimEnd([char[]]'\/').Length + 1).Replace('\','/'); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
})
$json = [ordered]@{ schema = 1; files = $entries } | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $Root 'repository-manifest.json'), $json + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
Write-Host 'Manifest regenerated. Review the complete preview before publishing.'
