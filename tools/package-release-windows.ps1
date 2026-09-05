# Packages a Forgotten Client release zip: executable + runtime DLLs + init.lua + modules/ + data/
# staged at the SAME directory level (ResourceManager::discoverWorkDir requires init.lua beside the
# executable - a zip that wraps them in an extra top-level folder or drops files a level down fails
# with "Unable to find work directory, the application cannot be initialized").
#
# Usage:  powershell -File tools\package-release-windows.ps1 [-Version "7.4.0"] [-ExePath <path>]
# Output: dist\ForgottenClient-<version>-windows-x64.zip + .sha256

param(
    [string]$Version = "7.4.0",
    [string]$ExePath = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not $ExePath) {
    foreach ($candidate in @(
        (Join-Path $repoRoot "vc14\Tibia\x64\Release\Tibia.exe"),
        (Join-Path $repoRoot "Tibia.exe")
    )) {
        if (Test-Path $candidate) { $ExePath = $candidate; break }
    }
}
if (-not $ExePath -or -not (Test-Path $ExePath)) {
    throw "no executable found; build the solution first or pass -ExePath"
}

$vcpkgBin = "C:\vcpkg\installed\x64-windows\bin"
if (-not (Test-Path $vcpkgBin)) { throw "vcpkg x64-windows runtime DLL directory not found at $vcpkgBin" }

$staging = Join-Path $repoRoot "dist\staging-windows-x64"
$distDir = Join-Path $repoRoot "dist"
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
New-Item -ItemType Directory -Path $staging | Out-Null

# Executable + runtime DLLs beside each other, same level as init.lua.
Copy-Item $ExePath (Join-Path $staging "Tibia.exe")
Copy-Item (Join-Path $vcpkgBin "*.dll") $staging

# Work-directory contents must sit at the same level as the executable.
foreach ($item in @("init.lua", "modules", "data")) {
    $source = Join-Path $repoRoot $item
    if (-not (Test-Path $source)) { throw "required work-directory item missing: $source" }
    Copy-Item -Recurse -Force $source (Join-Path $staging $item)
}

$zipName = "ForgottenClient-$Version-windows-x64.zip"
$zipPath = Join-Path $distDir $zipName
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $zipPath

$hash = (Get-FileHash $zipPath -Algorithm SHA256).Hash.ToLower()
$shaPath = "$zipPath.sha256"
Set-Content -Path $shaPath -Value "$hash  $zipName" -Encoding Ascii

Remove-Item -Recurse -Force $staging
Write-Host "Packaged: $zipPath"
Write-Host "Checksum: $shaPath"
Write-Host ""
Write-Host "Verify from a clean location:"
Write-Host "  1. extract the zip into an EMPTY directory"
Write-Host "  2. launch Tibia.exe from that directory (not from the source tree)"
Write-Host "  3. expected: startup proceeds past work-directory discovery"
Write-Host "     ('Unable to find work directory' means the zip layout regressed)"
