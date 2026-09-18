[CmdletBinding()]
param([string]$OutputDirectory = '_site')
$ErrorActionPreference = 'Stop'; $repoRoot = Split-Path -Parent $PSScriptRoot; $outputRoot = Join-Path $repoRoot $OutputDirectory
foreach ($file in @('index.html','styles.css','site.js','search-index.json','.nojekyll')) { if (-not (Test-Path (Join-Path $outputRoot $file) -PathType Leaf)) { throw "Generated site is missing $file" } }
$manifest = Get-Content (Join-Path $repoRoot 'docs-manifest.json') -Raw | ConvertFrom-Json; $documents = @($manifest.documents | Where-Object { $_ -match '(?i)\.md$' }); foreach ($document in $documents) { $page = Join-Path $outputRoot (([IO.Path]::ChangeExtension($document,'.html')).Replace('/','\')); if (-not (Test-Path $page -PathType Leaf)) { throw "Generated page is missing for $document" } }
$index = Get-Content (Join-Path $outputRoot 'index.html') -Raw; if ($index -notmatch '<title>Home · FortiGate Virtual Firewall</title>') { throw 'Generated index has an unexpected title' }; if ($index -match '\{\{[A-Z_]+\}\}') { throw 'Generated index contains an unresolved template token' }; Write-Host "FortiGate documentation site validation passed for $($documents.Count) Markdown documents."
