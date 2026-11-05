#requires -Version 7
<#
.SYNOPSIS
  Prints the next release version: major.minor from the root package.json, and the patch after the highest published
  GitHub release of that major.minor (0 if there's none).
.DESCRIPTION
  The root package.json's "version" is the major.minor being released (e.g. "0.2"); maintain it by hand. Releases are
  tagged vMAJOR.MINOR.PATCH. Draft releases don't count (an unpublished draft's version is reused), so the draft
  workflow can replace its own draft until it's published. Needs the gh CLI (GH_TOKEN in CI).
  In GitHub Actions, also writes version=<version> to $GITHUB_OUTPUT.
#>
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = Split-Path -Parent $PSScriptRoot
$majorMinor = (Get-Content (Join-Path $repo 'package.json') -Raw | ConvertFrom-Json).version
if ($majorMinor -notmatch '^\d+\.\d+$') {
  throw "The root package.json's version must be MAJOR.MINOR (e.g. 0.2), not '$majorMinor'."
}

$releases = gh release list --limit 1000 --json tagName,isDraft | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'gh release list failed' }
$pattern = '^v' + [regex]::Escape($majorMinor) + '\.(\d+)$'
$patches = @($releases | Where-Object { -not $_.isDraft -and $_.tagName -match $pattern } | ForEach-Object { [int]($_.tagName -replace $pattern, '$1') })
$patch = if ($patches.Count -eq 0) { 0 } else { ($patches | Measure-Object -Maximum).Maximum + 1 }

$version = "$majorMinor.$patch"
if ($env:GITHUB_OUTPUT) {
  "version=$version" >> $env:GITHUB_OUTPUT
}
$version
