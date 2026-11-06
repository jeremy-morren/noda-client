#requires -Version 7.4
<#
.SYNOPSIS
  Merges the CI test jobs' results (npm run test:merge): one JUnit report and one coverage report.
.DESCRIPTION
  1. `vitest --merge-reports` over every blob report in -Blobs (default test-results/blob; scripts/test-blob.ps1
     writes them): test-results/junit.xml (each suite named "<file> [<project>, <label>]", see
     test/vitest/junit-reporter.ts). Fails if any merged test failed.
  2. test/vitest/merge-coverage.ts over every coverage-final.json under -Coverage (default test-results/coverage; each
     node job's coverage/coverage-final.json): coverage/coverage-final.json and coverage-summary.json, the node
     project's coverage from every OS, moved onto this checkout's paths. (Not `vitest --merge-reports --coverage`:
     loading the custom coverage provider that way failed in CI.)
  Every extra browser project is defined (NODA_TEST_BROWSERS), so that each blob's files find their project; none is
  started. The merged run holds every blob in memory, so Node gets a larger heap.
  Usage: npm run test:merge [-- -Blobs <dir> -Coverage <dir>]
#>
param(
  [string] $Blobs = 'test-results/blob',
  [string] $Coverage = 'test-results/coverage',
  [int] $MaxOldSpaceMB = 12288
)
. (Join-Path $PSScriptRoot ci-helpers.ps1)

$env:NODA_TEST_BROWSERS = 'edge,safari,ios-safari,android-chrome'
$env:NODE_OPTIONS = "$env:NODE_OPTIONS --max-old-space-size=$MaxOldSpaceMB".Trim()

Push-Location $repo
try {
  $files = @(Get-ChildItem $Blobs -File -Filter *.json)
  Write-Host "Merging $($files.Count) blob reports: $(($files | ForEach-Object Name) -join ', ')"
  # A failed test (or a run that failed to start, such as a device session) makes this exit non-zero; the coverage is
  # merged anyway, and the script fails at the end. (Not stopping here: ci-helpers.ps1 makes a failing native command
  # throw.)
  $PSNativeCommandUseErrorActionPreference = $false
  npx vitest --merge-reports=$Blobs `
    --reporter=default --reporter=./test/vitest/junit-reporter.ts --outputFile.junit=test-results/junit.xml
  $testsFailed = $LASTEXITCODE -ne 0
  $PSNativeCommandUseErrorActionPreference = $true

  # Coverage, from each node job's coverage-final.json.
  $coverageFiles = @(Get-ChildItem $Coverage -Recurse -File -Filter coverage-final.json -ErrorAction Ignore)
  if ($coverageFiles.Count -eq 0) {
    Stop-WithError "No coverage-final.json under ${Coverage}: no coverage to merge."
  }
  Write-Host "Merging the coverage of $($coverageFiles.Count) node jobs"
  node test/vitest/merge-coverage.ts @($coverageFiles.FullName)
  if ($LASTEXITCODE -ne 0) {
    Stop-WithError 'Merging the coverage failed.'
  }
  if ($testsFailed) {
    Stop-WithError 'Some merged tests failed (or a test run had errors): see the merged report above.'
  }
} finally {
  Pop-Location
}
