param(
  [string]$ModulesRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) "modules"),

  [string]$TestFile = "tests\live.tftest.hcl",

  [string[]]$Module,

  [switch]$SkipInit,

  [switch]$NoColor,

  [int]$TerraformTimeoutSeconds = 900,

  [int]$HeartbeatSeconds = 30
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
  throw "terraform was not found in PATH."
}

function Invoke-TerraformCommand {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments,

    [Parameter(Mandatory = $true)]
    [string]$WorkingDirectory,

    [Parameter(Mandatory = $true)]
    [int]$TimeoutSeconds,

    [Parameter(Mandatory = $true)]
    [int]$HeartbeatSeconds
  )

  $stdoutFile = [System.IO.Path]::GetTempFileName()
  $stderrFile = [System.IO.Path]::GetTempFileName()

  try {
    $process = Start-Process `
      -FilePath "terraform" `
      -ArgumentList $Arguments `
      -WorkingDirectory $WorkingDirectory `
      -NoNewWindow `
      -PassThru `
      -RedirectStandardOutput $stdoutFile `
      -RedirectStandardError $stderrFile

    $startedAt = Get-Date
    $lastHeartbeatAt = $startedAt
    $timedOut = $false

    while (-not $process.HasExited) {
      Start-Sleep -Seconds 1

      $elapsedSeconds = ((Get-Date) - $startedAt).TotalSeconds
      if ($TimeoutSeconds -gt 0 -and $elapsedSeconds -ge $TimeoutSeconds) {
        $timedOut = $true
        try {
          try {
            $process.Kill($true)
          }
          catch [System.Management.Automation.MethodException] {
            $process.Kill()
          }
        }
        catch {
          Write-Warning ("Failed to stop stale terraform process {0}: {1}" -f $process.Id, $_.Exception.Message)
        }
        $process.WaitForExit()
        break
      }

      if ($HeartbeatSeconds -gt 0 -and ((Get-Date) - $lastHeartbeatAt).TotalSeconds -ge $HeartbeatSeconds) {
        Write-Host ("Still running terraform {0} ({1:n0}s elapsed)..." -f ($Arguments -join " "), $elapsedSeconds) -ForegroundColor DarkGray
        $lastHeartbeatAt = Get-Date
      }
    }

    $stdout = @(Get-Content -LiteralPath $stdoutFile -ErrorAction SilentlyContinue)
    $stderr = @(Get-Content -LiteralPath $stderrFile -ErrorAction SilentlyContinue)
    $output = @($stdout + $stderr)

    if ($timedOut) {
      $output += "Terraform command timed out after $TimeoutSeconds seconds."
    }

    [pscustomobject]@{
      ExitCode = if ($timedOut) { 124 } else { $process.ExitCode }
      TimedOut = $timedOut
      Output   = $output
    }
  }
  finally {
    Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
  }
}

$resolvedModulesRoot = (Resolve-Path -LiteralPath $ModulesRoot).Path
$terraformTestFilter = $TestFile -replace "/", "\"

if ($Module -and $Module.Count -gt 0) {
  $modules = @(
    $Module |
      ForEach-Object { Get-Item -LiteralPath (Join-Path $resolvedModulesRoot $_) } |
      Where-Object { $_.PSIsContainer }
  )
}
else {
  $modules = @(Get-ChildItem -LiteralPath $resolvedModulesRoot -Directory | Sort-Object Name)
}

$modulesWithTests = @(
  $modules |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName $TestFile) } |
    Sort-Object Name
)

if ($modulesWithTests.Count -eq 0) {
  Write-Host "No modules found with $TestFile under $resolvedModulesRoot."
  exit 0
}

$results = New-Object System.Collections.Generic.List[object]
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($moduleInfo in $modulesWithTests) {
  $moduleTimer = [System.Diagnostics.Stopwatch]::StartNew()
  Write-Host ""
  Write-Host "============================================================" -ForegroundColor Cyan
  Write-Host "terraform test :: $($moduleInfo.Name)" -ForegroundColor Cyan
  Write-Host "Path: $($moduleInfo.FullName)"

  Push-Location -LiteralPath $moduleInfo.FullName
  try {
    $initExitCode = 0

    if (-not $SkipInit) {
      $initArgs = @("init", "-backend=false", "-input=false")
      if ($NoColor) {
        $initArgs += "-no-color"
      }

      $initResult = Invoke-TerraformCommand -Arguments $initArgs -WorkingDirectory $moduleInfo.FullName -TimeoutSeconds $TerraformTimeoutSeconds -HeartbeatSeconds 0
      $initExitCode = $initResult.ExitCode
    }

    if ($initExitCode -ne 0) {
      Write-Host "terraform init failed:" -ForegroundColor Red
      $initResult.Output | ForEach-Object { Write-Host $_ }

      $results.Add([pscustomobject]@{
        Module     = $moduleInfo.Name
        Status     = if ($initResult.TimedOut) { "InitTimedOut" } else { "InitFailed" }
        PassedRuns = 0
        FailedRuns = 0
        ExitCode   = $initExitCode
        Seconds    = [math]::Round($moduleTimer.Elapsed.TotalSeconds, 2)
      })
      continue
    }

    $testArgs = @("test", "-filter=$terraformTestFilter")
    if ($NoColor) {
      $testArgs += "-no-color"
    }

    $testResult = Invoke-TerraformCommand -Arguments $testArgs -WorkingDirectory $moduleInfo.FullName -TimeoutSeconds $TerraformTimeoutSeconds -HeartbeatSeconds $HeartbeatSeconds
    $testOutput = @($testResult.Output)
    $testExitCode = $testResult.ExitCode
    $testOutput | ForEach-Object { Write-Host $_ }

    $passedRuns = 0
    $failedRuns = 0
    $testSummaryLine = @($testOutput | Where-Object { $_ -match "(Success|Failure)! \d+ passed, \d+ failed" } | Select-Object -Last 1)
    if ($testSummaryLine.Count -gt 0 -and $testSummaryLine[0] -match "(\d+) passed, (\d+) failed") {
      $passedRuns = [int]$matches[1]
      $failedRuns = [int]$matches[2]
    }

    $results.Add([pscustomobject]@{
      Module     = $moduleInfo.Name
      Status     = if ($testResult.TimedOut) { "TimedOut" } elseif ($testExitCode -eq 0) { "Passed" } else { "Failed" }
      PassedRuns = $passedRuns
      FailedRuns = $failedRuns
      ExitCode   = $testExitCode
      Seconds    = [math]::Round($moduleTimer.Elapsed.TotalSeconds, 2)
    })
  }
  finally {
    Pop-Location
  }
}

$stopwatch.Stop()
$failures = @($results | Where-Object { $_.ExitCode -ne 0 })
$passedModules = @($results | Where-Object { $_.Status -eq "Passed" })
$failedModules = @($results | Where-Object { $_.Status -eq "Failed" })
$initFailedModules = @($results | Where-Object { $_.Status -in @("InitFailed", "InitTimedOut") })
$timedOutModules = @($results | Where-Object { $_.Status -in @("InitTimedOut", "TimedOut") })
$totalPassedRuns = ($results | Measure-Object -Property PassedRuns -Sum).Sum
$totalFailedRuns = ($results | Measure-Object -Property FailedRuns -Sum).Sum

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Terraform module test summary" -ForegroundColor Cyan
$results | Format-Table -AutoSize
Write-Host ("Modules discovered: {0}" -f $modulesWithTests.Count)
Write-Host ("Modules passed:     {0}" -f $passedModules.Count)
Write-Host ("Modules failed:     {0}" -f $failedModules.Count)
Write-Host ("Init failed:        {0}" -f $initFailedModules.Count)
Write-Host ("Timed out:          {0}" -f $timedOutModules.Count)
Write-Host ("Test runs passed:   {0}" -f $totalPassedRuns)
Write-Host ("Test runs failed:   {0}" -f $totalFailedRuns)
Write-Host ("Total duration: {0:n2}s" -f $stopwatch.Elapsed.TotalSeconds)

if ($failures.Count -gt 0) {
  Write-Host ""
  Write-Host ("Failed modules: {0}" -f (($failures | Select-Object -ExpandProperty Module) -join ", ")) -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "All module tests passed." -ForegroundColor Green
