# repo-setup managed load-dotenv
$repoRoot = Split-Path -Parent $PSScriptRoot
$envFilePath = Join-Path $repoRoot ".env"

if (-not (Test-Path -LiteralPath $envFilePath)) {
    return
}

$lines = Get-Content -LiteralPath $envFilePath -ErrorAction Stop
foreach ($line in $lines) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
        continue
    }

    $separatorIndex = $trimmed.IndexOf("=")
    if ($separatorIndex -lt 1) {
        continue
    }

    $name = $trimmed.Substring(0, $separatorIndex).Trim()
    $value = $trimmed.Substring($separatorIndex + 1)

    if ([string]::IsNullOrWhiteSpace($name)) {
        continue
    }

    Set-Item -Path "Env:$name" -Value $value
}
