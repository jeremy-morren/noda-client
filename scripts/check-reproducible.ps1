#requires -Version 7
<#
.SYNOPSIS
  Checks that the build is reproducible: building and packing twice from clean gives byte-identical tarballs.
.DESCRIPTION
  tsc output depends only on the sources and the locked compiler, and `npm pack` normalises file times and
  order, so two clean builds must produce the same tarball (and so the same integrity hash on the registry).
#>
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = Split-Path -Parent $PSScriptRoot
$work = Join-Path ([IO.Path]::GetTempPath()) "noda-js-reproducible-$PID"
New-Item -ItemType Directory -Force $work | Out-Null

function Build-Pack([string] $name) {
  Push-Location $repo
  try {
    Get-ChildItem src -Directory | ForEach-Object { Remove-Item -Recurse -Force (Join-Path $_.FullName 'dist') -ErrorAction SilentlyContinue }
    npm run build --silent
    if ($LASTEXITCODE -ne 0) { throw "build failed" }
    $out = Join-Path $work $name
    New-Item -ItemType Directory -Force $out | Out-Null
    npm pack --workspaces --silent --pack-destination $out | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "npm pack failed" }
    return Get-ChildItem $out -Filter *.tgz | Sort-Object Name
  } finally {
    Pop-Location
  }
}

try {
  $first = @(Build-Pack 'first')
  $second = @(Build-Pack 'second')
  if ($first.Count -eq 0 -or $first.Count -ne $second.Count) { throw "Expected the same tarballs from both builds." }
  for ($i = 0; $i -lt $first.Count; $i++) {
    $a = (Get-FileHash -Algorithm SHA256 $first[$i].FullName).Hash
    $b = (Get-FileHash -Algorithm SHA256 $second[$i].FullName).Hash
    Write-Host "$($first[$i].Name): $a / $b"
    if ($a -ne $b -or $first[$i].Name -ne $second[$i].Name) {
      throw "Not reproducible: two clean builds produced different $($first[$i].Name)."
    }
  }
  Write-Host "Reproducible: both clean builds produced the same $($first.Count) tarball(s)."
} finally {
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
