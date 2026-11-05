# Clones NodaTime at the tag pinned in tools/nodatime-version.txt into .nodatime/<tag>,
# and builds NodaTime.Test (which the scenario extractor loads).
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$root = Split-Path $here -Parent
$tag = (Get-Content (Join-Path $here 'nodatime-version.txt') -Raw).Trim()
$dest = Join-Path $root ".nodatime/$tag"
if (-not (Test-Path (Join-Path $dest '.git'))) {
    New-Item -ItemType Directory -Force (Join-Path $root '.nodatime') | Out-Null
    git -c advice.detachedHead=false clone --quiet --depth 1 --branch $tag https://github.com/nodatime/nodatime.git $dest
    if ($LASTEXITCODE -ne 0) { throw "git clone failed" }
}
Copy-Item (Join-Path $here 'nuget.config') (Join-Path $dest 'nuget.config') -Force
dotnet build (Join-Path $dest 'src/NodaTime.Test/NodaTime.Test.csproj') -f net10.0 -c Release -v quiet -nologo
if ($LASTEXITCODE -ne 0) { throw "NodaTime.Test build failed" }
$dest
