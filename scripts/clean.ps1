#requires -Version 7
<#
.SYNOPSIS
  Empties the given output directories (deleting and recreating them), like Vite's --emptyOutDir.
.DESCRIPTION
  Builds run this on each package's dist before tsc, because tsc never deletes outputs whose source was renamed or
  removed, and npm pack would ship them. Paths are relative to the current directory.
  Usage: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/clean.ps1 <dir>...
#>
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

foreach ($dir in $args) {
  if (Test-Path $dir) {
    Remove-Item -Recurse -Force $dir
  }
  New-Item -ItemType Directory -Force $dir | Out-Null
}
