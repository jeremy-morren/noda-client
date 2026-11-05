#!/usr/bin/env pwsh
# Regenerates every *.generated.ts file in the repo from .NET / NodaTime (PowerShell 7).
#
#   tools/generate.ps1                     # everything
#   tools/generate.ps1 -Only data          # one command: data | cldr | scenarios
#   tools/generate.ps1 -Tzdb latest        # bundle nodatime.org's published NZD instead of compiling one
#   tools/generate.ps1 -Tzdb embedded      # bundle the NZD embedded in the pinned NodaTime (offline)
#   tools/generate.ps1 -Tzdata <url|path>  # compile from a specific IANA tzdata tarball (default: tzdata-latest)
#
# Steps: clone/build NodaTime at the pinned tag (tools/nodatime-version.txt), build tools/NodaJs.Tools, then run
# its command (`NodaJs.Tools --help` lists them):
#   data       enums, constants, TextErrorMessages, cultures (tools/cultures.txt), tzdb (compiled by NodaTime's
#              TzdbCompiler from the latest IANA release + latest CLDR windowsZones.xml), public API listing,
#              golden formatting/compare vectors
#   cldr       CLDR windowsZones.xml (Windows ↔ tzdb zone IDs)
#   scenarios  every NUnit test case in NodaTime.Test → test/scenarios
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

& (Join-Path $PSScriptRoot 'fetch-nodatime.ps1') | Out-Null

$project = Join-Path $PSScriptRoot 'NodaJs.Tools/NodaJs.Tools.csproj'
# NuGetAudit is off because NodaTime's own build treats audit warnings as errors.
dotnet build $project -c Release -nologo -v quiet -p:NuGetAudit=false
if ($LASTEXITCODE -ne 0) { throw 'Build of NodaJs.Tools failed' }

$toolArgs = @($Only, '--repo', $root)
if ($Only -in 'all', 'data') {
    $toolArgs += @('--tzdb', $Tzdb)
    if ($Tzdata) { $toolArgs += @('--tzdata', $Tzdata) }
}
if (($Only -in 'all', 'data', 'cldr') -and $Cldr) { $toolArgs += @('--cldr', $Cldr) }
dotnet (Join-Path $PSScriptRoot 'NodaJs.Tools/bin/Release/net10.0/NodaJs.Tools.dll') @toolArgs
if ($LASTEXITCODE -ne 0) { throw "NodaJs.Tools $Only failed" }
