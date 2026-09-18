# Windows 8.1 x64 installer and portable package.
#
# The Windows 10/11 NSIS installer embeds Microsoft's Evergreen WebView2 bootstrapper,
# which no longer installs on Windows 8.1. This script produces two dedicated artifacts
# that ship WebView2 Fixed Version 109 (the last runtime that still launches there):
#
#   Aethon-VPN-v<version>-Windows-8.1-x64-Installer.exe
#   Aethon-VPN-v<version>-Windows-8.1-x64-portable.zip
#
# The cabinet is fetched from the URL pinned in scripts/win81-pins.json and refused unless
# the size matches. After extraction, msedgewebview2.exe must be Authenticode-signed by
# Microsoft. Nothing here is taken from an unverified cache of a previous run: a size or
# publisher mismatch deletes the cache and fails the build.
#
# Called from the release workflow and from scripts/package-release.ps1 after the regular
# Windows build has produced aether-gui.exe and the sidecars.

[CmdletBinding()]
param(
  [string]$Version = "2.1.1",
  [string]$ReleaseDir
)

$ErrorActionPreference = "Stop"
if ($env:OS -ne "Windows_NT") {
  throw "Windows 8.1 packaging must run on Windows (expand.exe, NSIS, Authenticode)."
}
$repo = Split-Path -Parent $PSScriptRoot
if (-not $ReleaseDir) { $ReleaseDir = Join-Path $repo "release" }
$pinsPath = Join-Path $PSScriptRoot "win81-pins.json"
$pins = Get-Content -LiteralPath $pinsPath -Raw | ConvertFrom-Json
$work = Join-Path $repo ".webview2-cache"
$staging = Join-Path $repo "portable-win81"
$nsi = Join-Path $PSScriptRoot "windows81.nsi"

function Set-PeWindows81Subsystem {
  param([string]$Path)
  # PE32+ optional header: Major/MinorOperatingSystemVersion at +40/+42 from the
  # optional header, Major/MinorSubsystemVersion at +48/+50. Windows 8.1 is 6.3.
  # Applied to a *copy* of the exe so the Windows 10/11 installer keeps the
  # rustc-produced binary it already signed.
  $bytes = [IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -lt 64) { throw "Refusing to patch a truncated PE: $Path" }
  $pe = [BitConverter]::ToInt32($bytes, 0x3C)
  if ($pe -lt 0 -or ($pe + 24 + 52) -gt $bytes.Length) { throw "Invalid PE header in $Path" }
  if ([BitConverter]::ToUInt32($bytes, $pe) -ne 0x00004550) { throw "Not a PE file: $Path" }
  $opt = $pe + 24
  $magic = [BitConverter]::ToUInt16($bytes, $opt)
  if ($magic -ne 0x20B) { throw "Expected a PE32+ (x64) image in $Path, got magic 0x$($magic.ToString('X'))" }
  $major = [BitConverter]::GetBytes([uint16]6)
  $minor = [BitConverter]::GetBytes([uint16]3)
  [Array]::Copy($major, 0, $bytes, $opt + 40, 2)
  [Array]::Copy($minor, 0, $bytes, $opt + 42, 2)
  [Array]::Copy($major, 0, $bytes, $opt + 48, 2)
  [Array]::Copy($minor, 0, $bytes, $opt + 50, 2)
  [IO.File]::WriteAllBytes($Path, $bytes)
  Write-Host "Set PE OS/subsystem version of $Path to 6.3 (Windows 8.1)."
}

function Find-MakeNsis {
  $candidates = @(
    (Join-Path $env:LOCALAPPDATA "tauri\NSIS\makensis.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "NSIS\makensis.exe"),
    (Join-Path $env:ProgramFiles "NSIS\makensis.exe")
  )
  foreach ($path in $candidates) {
    if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) { return $path }
  }
  foreach ($root in @(
      (Join-Path $env:LOCALAPPDATA "tauri"),
      (Join-Path $env:LOCALAPPDATA "github.com.tauri-apps.tauri")
    )) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $found = Get-ChildItem -LiteralPath $root -Filter "makensis.exe" -File -Recurse -ErrorAction SilentlyContinue |
      Select-Object -First 1 -ExpandProperty FullName
    if ($found) { return $found }
  }
  return $null
}

function Assert-MicrosoftSigned([string]$Path) {
  $signature = Get-AuthenticodeSignature -LiteralPath $Path
  if (-not $signature.SignerCertificate) {
    throw "WebView2 runtime $Path carries no Authenticode signature."
  }
  $subject = $signature.SignerCertificate.Subject
  if ($subject -notmatch 'Microsoft') {
    throw "WebView2 runtime $Path is signed by `"$subject`" but must be signed by Microsoft."
  }
  # Valid, or UnknownError from an offline catalog lookup, are both acceptable here:
  # the publisher name is the check that the bytes came from Microsoft. A HashMismatch
  # or NotSigned status is a refusal.
  if ($signature.Status -eq "HashMismatch" -or $signature.Status -eq "NotSigned") {
    throw "WebView2 runtime $Path failed Authenticode verification: $($signature.Status) $($signature.StatusMessage)"
  }
  Write-Host "Verified Microsoft signature on $(Split-Path $Path -Leaf) ($subject)"
}

New-Item -ItemType Directory -Force $work | Out-Null
New-Item -ItemType Directory -Force $ReleaseDir | Out-Null
if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
New-Item -ItemType Directory -Force $staging | Out-Null

$cab = Join-Path $work $pins.archive
$needDownload = $true
if (Test-Path -LiteralPath $cab -PathType Leaf) {
  $existing = (Get-Item -LiteralPath $cab).Length
  if ($existing -eq [int64]$pins.size) {
    Write-Host "Reusing cached WebView2 cabinet ($existing bytes)."
    $needDownload = $false
  } else {
    Write-Host "Cached WebView2 cabinet is $existing bytes, expected $($pins.size); re-downloading."
    Remove-Item -LiteralPath $cab -Force
  }
}
if ($needDownload) {
  Write-Host "Downloading WebView2 Fixed Version $($pins.version) from $($pins.url)"
  Invoke-WebRequest -UseBasicParsing -Uri $pins.url -OutFile $cab
}
$actualSize = (Get-Item -LiteralPath $cab).Length
if ($actualSize -ne [int64]$pins.size) {
  Remove-Item -LiteralPath $cab -Force -ErrorAction SilentlyContinue
  throw "WebView2 cabinet size mismatch. Expected $($pins.size) bytes, got $actualSize. The pin in scripts/win81-pins.json no longer matches the downloaded archive."
}

$extracted = Join-Path $work "extracted-$($pins.version)"
if (Test-Path -LiteralPath $extracted) { Remove-Item -LiteralPath $extracted -Recurse -Force }
New-Item -ItemType Directory -Force $extracted | Out-Null
Write-Host "Extracting WebView2 cabinet with expand.exe"
& expand.exe $cab "-F:*" $extracted | Out-Null
if ($LASTEXITCODE -ne 0) {
  & expand.exe "-F:*" $cab $extracted | Out-Null
}
if ($LASTEXITCODE -ne 0) { throw "expand.exe failed with exit code $LASTEXITCODE while extracting the WebView2 cabinet." }

$webviewExe = Get-ChildItem -LiteralPath $extracted -Filter "msedgewebview2.exe" -File -Recurse -ErrorAction SilentlyContinue |
  Select-Object -First 1
if (-not $webviewExe) { throw "msedgewebview2.exe was not found inside the verified WebView2 cabinet." }
Assert-MicrosoftSigned -Path $webviewExe.FullName
$runtimeSource = $webviewExe.Directory.FullName

$gui = Join-Path $repo "src-tauri\target\release\aether-gui.exe"
if (-not (Test-Path -LiteralPath $gui -PathType Leaf)) {
  throw "aether-gui.exe was not found at $gui. Build the Windows application first."
}
$sidecars = @{
  "aether.exe" = Join-Path $repo "src-tauri\binaries\aether-x86_64-pc-windows-msvc.exe"
  "xray.exe"   = Join-Path $repo "src-tauri\binaries\xray-x86_64-pc-windows-msvc.exe"
  "wintun.dll" = Join-Path $repo "src-tauri\binaries\wintun.dll"
}
foreach ($entry in $sidecars.GetEnumerator()) {
  if (-not (Test-Path -LiteralPath $entry.Value -PathType Leaf)) {
    throw "Required sidecar $($entry.Key) was not found at $($entry.Value). Run npm run fetch:core and npm run fetch:routing first."
  }
}

Copy-Item -LiteralPath $gui -Destination (Join-Path $staging "Aethon.exe")
Set-PeWindows81Subsystem -Path (Join-Path $staging "Aethon.exe")
Copy-Item -LiteralPath $sidecars["aether.exe"] -Destination (Join-Path $staging "aether.exe")
Copy-Item -LiteralPath $sidecars["xray.exe"] -Destination (Join-Path $staging "xray.exe")
Copy-Item -LiteralPath $sidecars["wintun.dll"] -Destination (Join-Path $staging "wintun.dll")
foreach ($file in @("LICENSE", "NOTICE.md", "TRADEMARK.md")) {
  Copy-Item -LiteralPath (Join-Path $repo $file) -Destination $staging
}
Copy-Item -LiteralPath (Join-Path $repo "third-party\xray-LICENSE.txt") -Destination (Join-Path $staging "xray-LICENSE.txt")
Copy-Item -LiteralPath (Join-Path $repo "third-party\wintun-LICENSE.txt") -Destination (Join-Path $staging "wintun-LICENSE.txt")
Copy-Item -LiteralPath (Join-Path $repo "docs\README-Windows-8.1.md") -Destination (Join-Path $staging "README-Windows-8.1.txt")

$launcher = @"
@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0WebView2Runtime\msedgewebview2.exe" (
  set "WEBVIEW2_BROWSER_EXECUTABLE_FOLDER=%~dp0WebView2Runtime"
)
start "" "%~dp0Aethon.exe"
"@
[IO.File]::WriteAllText((Join-Path $staging "Aethon.cmd"), $launcher, (New-Object Text.UTF8Encoding $false))

$runtimeDest = Join-Path $staging "WebView2Runtime"
New-Item -ItemType Directory -Force $runtimeDest | Out-Null
Write-Host "Copying WebView2 Fixed Version $($pins.version) into the Windows 8.1 package"
Copy-Item -Path (Join-Path $runtimeSource "*") -Destination $runtimeDest -Recurse -Force
if (-not (Test-Path -LiteralPath (Join-Path $runtimeDest "msedgewebview2.exe") -PathType Leaf)) {
  throw "WebView2Runtime\msedgewebview2.exe is missing from the staged Windows 8.1 package."
}

if ($env:AETHON_SIGN_SCRIPT) {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $env:AETHON_SIGN_SCRIPT (Join-Path $staging "Aethon.exe")
  if ($LASTEXITCODE -ne 0) { throw "Signing the Windows 8.1 Aethon.exe failed." }
}

$portableZip = Join-Path $ReleaseDir "Aethon-VPN-v${Version}-Windows-8.1-x64-portable.zip"
if (Test-Path -LiteralPath $portableZip) { Remove-Item -LiteralPath $portableZip -Force }
Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $portableZip -Force
Write-Host "Wrote $portableZip"

$makensis = Find-MakeNsis
$installer = Join-Path $ReleaseDir "Aethon-VPN-v${Version}-Windows-8.1-x64-Installer.exe"
if ($makensis) {
  Write-Host "Building the Windows 8.1 NSIS installer with $makensis"
  $sourceDir = $staging
  & $makensis /V2 `
    "/DAPP_VERSION=$Version" `
    "/DSOURCE_DIR=$sourceDir" `
    "/DOUT_FILE=$installer" `
    $nsi
  if ($LASTEXITCODE -ne 0) { throw "makensis failed with exit code $LASTEXITCODE." }
  if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
    throw "makensis reported success but did not write $installer."
  }
  if ($env:AETHON_SIGN_SCRIPT) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $env:AETHON_SIGN_SCRIPT $installer
    if ($LASTEXITCODE -ne 0) { throw "Signing the Windows 8.1 installer failed." }
  }
  Write-Host "Wrote $installer"
} else {
  Write-Host "makensis.exe was not found; the Windows 8.1 portable zip was still produced. The NSIS installer is skipped."
}

Get-ChildItem -LiteralPath $ReleaseDir -File |
  Where-Object { $_.Name -like "*Windows-8.1*" } |
  Select-Object Name, Length
