#requires -Version 7
<#
.SYNOPSIS
  Fails if HEAD carries a release tag (vMAJOR.MINOR.PATCH) for a version other than the one being released.
.DESCRIPTION
  A commit that was already released as v0.2.0 mustn't be drafted or published again as v0.2.1. Needs the repo's
  tags (actions/checkout with fetch-depth: 0).
#>
param(
  [Parameter(Mandatory)]
  [string] $Version
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$tags = @(git tag --points-at HEAD | Where-Object { $_ -match '^v\d+\.\d+\.\d+$' })
if ($LASTEXITCODE -ne 0) { throw 'git tag failed' }
$others = @($tags | Where-Object { $_ -ne "v$Version" })
if ($others.Count -gt 0) {
  throw "HEAD is tagged $($others -join ', '), so it can't be released as v$Version."
}
Write-Host "HEAD's release tags: $(if ($tags.Count -gt 0) { $tags -join ', ' } else { 'none' }); releasing v$Version."
