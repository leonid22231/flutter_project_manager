# Builds Flutter Windows release and packs runner/Release into a ZIP under dist/.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File tool/build_windows_zip.ps1
#   powershell -ExecutionPolicy Bypass -File tool/build_windows_zip.ps1 -SkipBuild
#
param(
  [switch]$SkipBuild,
  [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Get-PubspecField([string]$name) {
  $line = Get-Content (Join-Path $root 'pubspec.yaml') |
    Where-Object { $_ -match "^\s*$name\s*:" } |
    Select-Object -First 1
  if (-not $line) { return $null }
  return ($line -replace "^\s*$name\s*:\s*", '').Trim().Trim('"').Trim("'")
}

$appName = Get-PubspecField 'name'
if (-not $appName) { $appName = 'project_manager' }

$versionRaw = Get-PubspecField 'version'
if (-not $versionRaw) { $versionRaw = '0.0.0+0' }
$versionName = ($versionRaw -split '\+')[0]

Write-Host "==> Project: $appName  version: $versionName" -ForegroundColor Cyan

if (-not $SkipBuild) {
  Write-Host '==> flutter pub get' -ForegroundColor Cyan
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed ($LASTEXITCODE)" }

  Write-Host '==> flutter build windows --release' -ForegroundColor Cyan
  flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed ($LASTEXITCODE)" }
} else {
  Write-Host '==> SkipBuild: using existing Windows build output' -ForegroundColor Yellow
}

$candidates = @(
  (Join-Path $root "build\windows\x64\runner\$Configuration"),
  (Join-Path $root "build\windows\runner\$Configuration")
)
$releaseDir = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $releaseDir) {
  throw "Release folder not found. Tried:`n - $($candidates -join "`n - ")"
}

$exe = Get-ChildItem -Path $releaseDir -Filter '*.exe' -File |
  Where-Object { $_.Name -notmatch '(?i)flutter_windows|unins' } |
  Select-Object -First 1
if (-not $exe) {
  throw "No application .exe found in $releaseDir"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$distDir = Join-Path $root 'dist'
New-Item -ItemType Directory -Path $distDir -Force | Out-Null

$zipName = "$appName-$versionName-windows-$stamp.zip"
$zipPath = Join-Path $distDir $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Write-Host "==> Packing: $releaseDir" -ForegroundColor Cyan
Write-Host "    -> $zipPath" -ForegroundColor Cyan

# Compress-Archive follows directory junctions poorly; use .NET ZipFile.
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory(
  $releaseDir,
  $zipPath,
  [System.IO.Compression.CompressionLevel]::Optimal,
  $false
)

$sizeMb = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
Write-Host "==> Done: $zipPath ($sizeMb MB)" -ForegroundColor Green
Write-Host "    Entry exe: $($exe.Name)" -ForegroundColor Green

# Soft path for tasks / CI consumers
Write-Host "##ZIP_PATH=$zipPath"
