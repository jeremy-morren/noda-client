#requires -Version 7.4
<#
.SYNOPSIS
  Fails if HEAD is tagged with a release version other than the given one (a commit is released as one version).
  Usage: pwsh -NoProfile -File scripts/check-head-tag.ps1 -Version 0.2.0
#>
param(
  [Parameter(Mandatory)] [string] $Version
)
. (Join-Path $PSScriptRoot ci-helpers.ps1)

$others = @(git -C $repo tag --points-at HEAD | Where-Object { $_ -cmatch '^v[0-9]+\.[0-9]+\.[0-9]+$' -and $_ -cne "v$Version" })
if ($others.Count -gt 0)
{
  Stop-WithError "HEAD is tagged $($others -join ', '), so it can't be released as v$Version."
}
Write-Host "HEAD isn't tagged with another version."
