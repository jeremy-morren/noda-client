#requires -Version 7.4
<#
.SYNOPSIS
  Works out the version the next release gets, as the step output "version".
.DESCRIPTION
  Major.minor from the root package.json; the patch is one more than the highest published (non-draft) release
  vMAJOR.MINOR.PATCH, or 0. Drafts don't count, so until a draft is published, each push to main replaces it with the
  same version. Needs gh (signed in, or GH_TOKEN).
  Usage: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/next-version.ps1
#>
. (Join-Path $PSScriptRoot ci-helpers.ps1)

Push-Location $repo
try {
  $majorMinor = Get-MajorMinor
  $prefix = "v$majorMinor."
  $patches = @(Get-Releases |
    Where-Object { -not $_.isDraft -and $_.tagName.StartsWith($prefix, [StringComparison]::Ordinal) } |
    ForEach-Object { $_.tagName.Substring($prefix.Length) } |
    Where-Object { $_ -cmatch '^[0-9]+$' } |
    ForEach-Object { [int] $_ })
  $patch = if ($patches.Count -eq 0) { 0 } else { ($patches | Measure-Object -Maximum).Maximum + 1 }
  Set-ActionOutput version "$majorMinor.$patch"
} finally {
  Pop-Location
}
