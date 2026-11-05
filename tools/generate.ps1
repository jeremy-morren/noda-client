#!/usr/bin/env pwsh
# Regenerates every *.generated.ts file in the repo from .NET / NodaTime.
#
#   tools/generate.ps1                     # everything
#   tools/generate.ps1 -Only data          # one command: data | cldr | scenarios
#   tools/generate.ps1 -Tzdb latest        # bundle nodatime.org's published NZD instead of compiling one
#   tools/generate.ps1 -Tzdb embedded      # bundle the NZD embedded in the pinned NodaTime (offline)
#   tools/generate.ps1 -Tzdata <url|path>  # compile from a specific IANA tzdata tarball (default: tzdata-latest)
#
# Steps: publish tools/NodaJs.Tools to tools/publish (which clones NodaTime at NodaTimeVersion, in
# tools/Directory.Packages.props, and builds against it), then run its command (`NodaJs.Tools --help` lists them):
#   data       enums, constants, TextErrorMessages, cultures (tools/cultures.txt), tzdb (compiled by NodaTime's
#              TzdbCompiler from the latest IANA release + latest CLDR windowsZones.xml; the tzdata tarball is kept
#              as test/fixtures/tzdb/tzdata<version>.tar.gz), public API listing, golden formatting/compare vectors
#   cldr       CLDR windowsZones.xml (Windows ↔ tzdb zone IDs)
#   scenarios  every NUnit test case in NodaTime.Test and NodaTime.TzdbCompiler.Test → test/scenarios
#   all        all three
[CmdletBinding()]
param(
    [ValidateSet('all', 'data', 'cldr', 'scenarios')]
    [string] $Only = 'all',
    [ValidateSet('compile', 'latest', 'embedded')]
    [string] $Tzdb = 'compile',
    # IANA tzdata tarball (URL or path) for -Tzdb compile; default: the latest IANA release.
    [string] $Tzdata,
    # A CLDR release tag (e.g. release-48) or a local windowsZones.xml; default: latest CLDR release.
    [string] $Cldr
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

$publish = Join-Path $PSScriptRoot 'publish'

# From tools/, so dotnet uses the SDK that tools/global.json pins. Building NodaJs.Tools clones NodaTime first (its
# PrepareNodaTime target).
Push-Location $PSScriptRoot
try {
    dotnet publish NodaJs.Tools -c Release -o $publish -nologo -v quiet
    if ($LASTEXITCODE -ne 0) { throw 'Publish of NodaJs.Tools failed' }

    $toolArgs = @($Only, '--repo', $root)
    if ($Only -in 'all', 'data') {
        $toolArgs += @('--tzdb', $Tzdb)
        if ($Tzdata) { $toolArgs += @('--tzdata', $Tzdata) }
    }
    if (($Only -in 'all', 'data', 'cldr') -and $Cldr) { $toolArgs += @('--cldr', $Cldr) }
    dotnet (Join-Path $publish 'NodaJs.Tools.dll') @toolArgs
    if ($LASTEXITCODE -ne 0) { throw "NodaJs.Tools $Only failed" }
} finally {
    Pop-Location
}
