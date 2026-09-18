# Shared SHA-256 helper for the build scripts. Dot-source it:
#
#   . (Join-Path $PSScriptRoot "sha256.ps1")
#   $digest = Get-Sha256Hex -Path $file
#
# Why this exists instead of using Get-FileHash:
#
# Get-FileHash is a cmdlet in the Microsoft.PowerShell.Utility module, so calling it depends
# on command discovery finding and loading that module first. On the hosted Windows runner
# that lookup has failed in the middle of fetch-aether.ps1 with
#
#   Get-FileHash : The term 'Get-FileHash' is not recognized as the name of a cmdlet,
#   function, script file, or operable program.
#
# and because the script runs with $ErrorActionPreference = "Stop", the release build died at
# the one step whose whole job is to verify what it downloaded. Every digest computed by these
# scripts is a security control: src-tauri/src/process.rs and src-tauri/src/routing.rs refuse
# to launch a binary whose digest differs from the pin, so the build has to be able to compute
# one under every condition the runner can present.
#
# The implementation below therefore calls into the .NET BCL directly, exactly as
# fetch-aether.ps1 already did for the archive digest, and uses no cmdlets at all - not
# Resolve-Path, not Test-Path, not Write-Error. There is no module for it to fail to find.
# It returns the lowercase hex digest, matching what the pins in scripts/*.json,
# scripts/*.ps1 and the Rust sources are written as, so comparisons stay plain -ne.
function Get-Sha256Hex {
  param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path
  )

  # Relative paths are resolved against PowerShell's location, not [Environment]::CurrentDirectory:
  # Set-Location does not update the latter, so handing a relative path straight to
  # [System.IO.File]::OpenRead would resolve it against the directory the process started in.
  $target = $Path
  if (-not [System.IO.Path]::IsPathRooted($target)) {
    $target = [System.IO.Path]::Combine($PWD.Path, $target)
  }
  if (-not [System.IO.File]::Exists($target)) {
    throw "Cannot compute a SHA-256 digest for '$Path': the file does not exist (resolved to '$target')."
  }

  $stream = [System.IO.File]::OpenRead($target)
  $hasher = [System.Security.Cryptography.SHA256]::Create()
  try {
    # Streaming, not ReadAllBytes: the Xray and Aether archives are tens of megabytes and the
    # runner does not need two more copies of one in the large object heap to hash it.
    return [System.BitConverter]::ToString($hasher.ComputeHash($stream)).Replace("-", "").ToLowerInvariant()
  }
  finally {
    $stream.Dispose()
    $hasher.Dispose()
  }
}
