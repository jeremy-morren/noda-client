#requires -Version 7
<#
.SYNOPSIS
  Stamps a release version (MAJOR.MINOR.PATCH) into the packages before they're built and packed.
.DESCRIPTION
  In the repo, the packages' versions are the placeholder 0.0.0-development (as is noda-js-zod's peer dependency on
  noda-js, so npm links the workspace); a release sets the real version, and noda-js-zod's peer dependency to
  ^<version>. Uses `npm pkg set`, which keeps package.json's formatting. Run it in a CI checkout; don't commit the
  result.
#>
param(
  [Parameter(Mandatory)]
  [string] $Version
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
  throw "Expected a MAJOR.MINOR.PATCH version, not '$Version'."
}
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
  npm pkg set "version=$Version" --workspace src/noda-js --workspace src/noda-js-zod
  if ($LASTEXITCODE -ne 0) { throw 'npm pkg set version failed' }
  npm pkg set "peerDependencies.noda-js=^$Version" --workspace src/noda-js-zod
  if ($LASTEXITCODE -ne 0) { throw 'npm pkg set peerDependencies failed' }
} finally {
  Pop-Location
}
