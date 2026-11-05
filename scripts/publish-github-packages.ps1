#requires -Version 7.4
<#
.SYNOPSIS
  Publishes a release's npm tarballs to GitHub Packages, renamed @<owner>/<name>.
.DESCRIPTION
  GitHub Packages' npm registry only takes packages scoped to the repository's owner, so each tarball attached to the
  release (which the publish job checked are byte-identical to its own build) is unpacked and its package.json given
  the scoped name and GitHub Packages as its registry (no npm provenance there). noda-js-zod's code and peer
  dependency still name "noda-js", so a GitHub Packages user installs the core under that name with an alias:
  "noda-js": "npm:@<owner>/noda-js@^<version>". npm authenticates with the .npmrc that setup-node writes. Needs the
  .NET SDK that tools/global.json pins (for tools/NodaJs.Package).
  -WhatIf prepares the packages and shows what it would publish.
  Usage: pwsh -NoProfile -File scripts/publish-github-packages.ps1 -Tag v0.2.0 -Owner jeremy-morren [-WhatIf]
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [Parameter(Mandatory)] [string] $Tag,
  [Parameter(Mandatory)] [string] $Owner
)
. (Join-Path $PSScriptRoot ci-helpers.ps1)

$scope = $Owner.ToLowerInvariant()
$work = Join-Path ([IO.Path]::GetTempPath()) "noda-js-github-packages-$PID"
Push-Location $repo
try {
  gh release download $Tag --pattern '*.tgz' --dir (Join-Path $work released)
  foreach ($tgz in Get-ChildItem (Join-Path $work released) -Filter *.tgz)
  {
    # Unpacked with tools/NodaJs.Package rather than tar, which differs between machines.
    $dir = Join-Path $work $tgz.BaseName
    Invoke-NodaJsPackage extract-tar-gzip $tgz.FullName --directory $dir
    $package = Join-Path $dir package
    $name = (Get-Content -Raw (Join-Path $package package.json) | ConvertFrom-Json).name
    Push-Location $package
    try {
      npm pkg set "name=@$scope/$name"
      npm pkg delete publishConfig
      npm pkg set "publishConfig.registry=https://npm.pkg.github.com"
      if ($PSCmdlet.ShouldProcess("@$scope/$name", 'Publish to GitHub Packages'))
      {
        # --ignore-scripts: the package's prepack copies files from the repo; the tarball already has them.
        npm publish --ignore-scripts
      }
    } finally {
      Pop-Location
    }
  }
} finally {
  Pop-Location
  Remove-Item -Recurse -Force $work -ErrorAction Ignore -WhatIf:$false
}
