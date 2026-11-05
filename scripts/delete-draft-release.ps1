#requires -Version 7.4
<#
.SYNOPSIS
  Deletes the draft release for a tag, and the tag itself if it's left over, before a new draft replaces them.
.DESCRIPTION
  A tag without a published release is left over from a release that was deleted (or unpublished). Needs gh (signed
  in, or GH_TOKEN). -WhatIf shows what it would delete.
  Usage: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/delete-draft-release.ps1 -Tag v0.2.0 [-WhatIf]
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory)] [string] $Tag
)
. (Join-Path $PSScriptRoot ci-helpers.ps1)

Push-Location $repo
try {
  $drafts = @(Get-Releases | Where-Object { $_.isDraft -and $_.tagName -ceq $Tag })
  foreach ($draft in $drafts)
  {
    if ($PSCmdlet.ShouldProcess($Tag, 'Delete the draft release'))
    {
      gh release delete $Tag --yes
    }
  }
  if (git ls-remote --tags origin "refs/tags/$Tag")
  {
    if ($PSCmdlet.ShouldProcess($Tag, 'Delete the leftover tag'))
    {
      git push origin --delete "refs/tags/$Tag"
    }
  }
  Write-Host "Draft releases for ${Tag}: $($drafts.Count)."
} finally {
  Pop-Location
}
