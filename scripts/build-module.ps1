#requires -Version 7.4
<#
.SYNOPSIS
  Builds the single-file ES module and its release archives (npm run build:module).
.DESCRIPTION
  standalone/build.ts writes artifacts/module/noda-js.js and noda-js.js.map; tools/NodaJs.Package then archives them
  as artifacts/noda-js-module.zip and artifacts/noda-js-module.tar.gz (the release assets), at maximum compression.
  The archives are reproducible, so the release workflow can rebuild them byte for byte: every entry is dated HEAD's
  commit time, and nothing comes from the machine (see tools/NodaJs.Package/Archive.cs). Needs the .NET SDK that
  tools/global.json pins.
#>
. (Join-Path $PSScriptRoot ci-helpers.ps1)

$artifacts = Join-Path $repo artifacts
$moduleDir = Join-Path $artifacts module
$files = 'noda-js.js', 'noda-js.js.map'

node (Join-Path $repo standalone/build.ts)

$commitTime = git -C $repo log -1 --format=%cI HEAD
Invoke-NodaJsPackage zip (Join-Path $artifacts noda-js-module.zip) @files --directory $moduleDir --time $commitTime
Invoke-NodaJsPackage tar-gzip (Join-Path $artifacts noda-js-module.tar.gz) @files --directory $moduleDir --time $commitTime
