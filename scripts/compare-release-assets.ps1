#requires -Version 7.4
<#
.SYNOPSIS
  Checks that every asset attached to a release is byte-identical to the one this build makes.
.DESCRIPTION
  The npm tarballs and the noda-js-module archives are reproducible, so rebuilding at the release's commit must give
  the same bytes: what was reviewed in the draft is what's published. Downloads the release's assets and compares
  them with the files directly in -Built (npm pack and npm run build:module output). Needs gh (signed in, or
  GH_TOKEN).
  Usage: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/compare-release-assets.ps1 -Tag v0.2.0 -Built artifacts
#>
param(
  [Parameter(Mandatory)] [string] $Tag,
  [Parameter(Mandatory)] [string] $Built
)
. (Join-Path $PSScriptRoot ci-helpers.ps1)

$released = Join-Path ([IO.Path]::GetTempPath()) "noda-js-released-$PID"
Push-Location $repo
try {
  gh release download $Tag --dir $released
  $builtFiles = @(Get-ChildItem -File $Built | Sort-Object Name)
  $releasedFiles = @(Get-ChildItem -File $released | Sort-Object Name)
  $builtNames = $builtFiles.Name -join ', '
  $releasedNames = $releasedFiles.Name -join ', '
  if ($builtNames -cne $releasedNames)
  {
    Stop-WithError "The release's assets ($releasedNames) aren't the ones this build makes ($builtNames)."
  }
  foreach ($file in $builtFiles)
  {
    $a = (Get-FileHash -Algorithm SHA256 $file.FullName).Hash
    $b = (Get-FileHash -Algorithm SHA256 (Join-Path $released $file.Name)).Hash
    Write-Host "$($file.Name): built $a, released $b"
    if ($a -cne $b)
    {
      Stop-WithError "$($file.Name) built here differs from the one attached to the release."
    }
  }
  Write-Host "All $($builtFiles.Count) assets of $Tag match this build."
} finally {
  Pop-Location
  Remove-Item -Recurse -Force $released -ErrorAction Ignore
}
