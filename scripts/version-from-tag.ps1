#requires -Version 7.4
<#
.SYNOPSIS
  The version a release tag publishes, as the step output "version": vMAJOR.MINOR.PATCH → MAJOR.MINOR.PATCH.
.DESCRIPTION
  Fails unless the tag is vMAJOR.MINOR.PATCH in the root package.json's major.minor.
  Usage: pwsh -NoProfile -File scripts/version-from-tag.ps1 -Tag v0.2.0
#>
param(
  [Parameter(Mandatory)] [string] $Tag
)
. (Join-Path $PSScriptRoot ci-helpers.ps1)

if ($Tag -cnotmatch '^v([0-9]+\.[0-9]+)\.[0-9]+$')
{
  Stop-WithError "Release tags are vMAJOR.MINOR.PATCH, not '$Tag'."
}
$tagMajorMinor = $Matches[1]
$majorMinor = Get-MajorMinor
if ($tagMajorMinor -cne $majorMinor)
{
  Stop-WithError "The tag $Tag isn't in the root package.json's major.minor ($majorMinor)."
}
Set-ActionOutput version $Tag.Substring(1)
