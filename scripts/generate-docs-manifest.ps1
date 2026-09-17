$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$documents = git -C $repoRoot ls-files |
    Where-Object { $_ -match '\.md$' } |
    Sort-Object |
    ForEach-Object { $_ -replace '\\', '/' }

$manifest = @{
    generatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    documents   = @($documents)
}

$json = $manifest | ConvertTo-Json -Depth 3
[System.IO.File]::WriteAllText(
    (Join-Path $repoRoot "docs-manifest.json"),
    ($json -replace "`r`n", "`n") + "`n",
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Wrote docs-manifest.json with $($documents.Count) documentation files."
