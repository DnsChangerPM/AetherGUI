# Aethon

Aethon is an independent Windows and Android client for the official [CluvexStudio/Aether](https://github.com/CluvexStudio/Aether) networking core. Windows version 2.1.1 bundles the verified Aether 1.9.0 core and Xray 26.3.27 routing engine, providing system-wide VPN routing or a local SOCKS5 proxy through focused desktop and mobile interfaces.

[Releases](https://github.com/hamvex/AetherGUI/releases) · [Security policy](SECURITY.md) · [Contributing](CONTRIBUTING.md)

## Windows 2.1.1 release notes

### Windows routing and settings

- Added transactional, single-session routing-helper and Xray lifecycle management.
- Added recovery for stale Aethon-owned TUN adapters and failed routing sessions.
- Preserved sanitized Xray exit diagnostics and immediate reconnect cleanup.
- Restored Scan Mode and protocol-specific MASQUE HTTP/3 or HTTP/2 transport controls.
- Migrated obsolete MASQUE obfuscation values without confusing them with Scan Mode.
- Kept the compact Connect, Configurations, and Settings navigation.

### Android-parity interface

- Added English and Persian application translations with right-to-left layout support.
- Removed Android locale overrides, Persian resources, RTL support, and the language selector.
- Added the Windows language selector and preserved VPN features and routing behavior.

### Application updates

- Added automatic update checks at startup and every 12 hours while Aethon is running.
- Added manual **Check for Updates** controls to Android and Windows settings.
- Added current version, latest version, update status, and GitHub release notes.
- Added an **Automatically download updates** preference.
- Android automatic downloads use Wi-Fi and Android DownloadManager for resumable transfers.
- Windows downloads the official x64 setup installer and reports progress inside the application.
- Added duplicate Android notification prevention and Android download progress notifications.
- Added SHA-256 verification on both platforms.
- Android additionally verifies that the downloaded APK uses the same signing certificate as the installed application.
- Installation uses Android FileProvider/package installer APIs and the verified Windows setup executable.
- Update URLs are restricted to the official `hamvex/AetherGUI` GitHub repository.

### Versions and compatibility

- Windows version: `2.1.1`
- Android version name: `2.1.1`
- Android version code: `23`
- Windows Aether core: `1.9.0`; Android Aether core: `1.9.0`
- Xray routing engine: `26.3.27`
- Windows: Windows 10/11 x64; Windows 8.1 x64 via the dedicated 8.1 installer or portable package
- Android: Android 8.0 or newer; ARMv7, ARM64, and x86_64

Existing VPN services, state management, routing recovery, Smart Connect, and split tunneling remain in place.

## Downloads

Download the release files from [Aethon 2.1.1](https://github.com/hamvex/AetherGUI/releases/tag/v2.1.1):

- [`Aethon-VPN-v2.1.1-all-platforms.zip`](https://github.com/hamvex/AetherGUI/releases/download/v2.1.1/Aethon-VPN-v2.1.1-all-platforms.zip) — Windows and Android 2.1.1 release archive.
- [`Aethon-VPN-v2.1.1-Windows-x64-Installer.exe`](https://github.com/hamvex/AetherGUI/releases/download/v2.1.1/Aethon-VPN-v2.1.1-Windows-x64-Installer.exe) — recommended Windows 10/11 installer.
- [`Aethon-VPN-v2.1.1-Windows-x64.msi`](https://github.com/hamvex/AetherGUI/releases/download/v2.1.1/Aethon-VPN-v2.1.1-Windows-x64.msi) — Windows 10/11 MSI.
- [`Aethon-VPN-v2.1.1-Windows-x64-portable.zip`](https://github.com/hamvex/AetherGUI/releases/download/v2.1.1/Aethon-VPN-v2.1.1-Windows-x64-portable.zip) — portable Windows 10/11 package.
- [`Aethon-VPN-v2.1.1-Windows-8.1-x64-Installer.exe`](https://github.com/hamvex/AetherGUI/releases/download/v2.1.1/Aethon-VPN-v2.1.1-Windows-8.1-x64-Installer.exe) — Windows 8.1 installer with bundled WebView2 109.
- [`Aethon-VPN-v2.1.1-Windows-8.1-x64-portable.zip`](https://github.com/hamvex/AetherGUI/releases/download/v2.1.1/Aethon-VPN-v2.1.1-Windows-8.1-x64-portable.zip) — Windows 8.1 portable package with bundled WebView2 109. Extract and run `Aethon.cmd`.
- [`Aethon-VPN-v2.1.1-Android-Universal.apk`](https://github.com/hamvex/AetherGUI/releases/download/v2.1.1/Aethon-VPN-v2.1.1-Android-Universal.apk) — Android universal APK containing ARMv7, ARM64, and x86_64 libraries.
- [`Aethon-VPN-v2.1.1-Android-ARMv7.apk`](https://github.com/hamvex/AetherGUI/releases/download/v2.1.1/Aethon-VPN-v2.1.1-Android-ARMv7.apk) — 32-bit ARM APK.
- [`Aethon-VPN-v2.1.1-Android-ARM64.apk`](https://github.com/hamvex/AetherGUI/releases/download/v2.1.1/Aethon-VPN-v2.1.1-Android-ARM64.apk) — 64-bit ARM APK.
- [`Aethon-VPN-v2.1.1-Android-x86_64.apk`](https://github.com/hamvex/AetherGUI/releases/download/v2.1.1/Aethon-VPN-v2.1.1-Android-x86_64.apk) — x86_64 APK.
- [`Aethon-VPN-v2.1.1-Android-AAB.aab`](https://github.com/hamvex/AetherGUI/releases/download/v2.1.1/Aethon-VPN-v2.1.1-Android-AAB.aab) — Play App Bundle.
- [`SHA256SUMS.txt`](https://github.com/hamvex/AetherGUI/releases/download/v2.1.1/SHA256SUMS.txt) — release checksums.

Windows binaries are currently unsigned and may trigger a SmartScreen warning. Android release packages are signed with the established Aethon Android signing certificate.

## Update source configuration

Both clients use the latest GitHub Release endpoint:

```text
https://api.github.com/repos/hamvex/AetherGUI/releases/latest
```

Future releases must include:

- `Aethon-VPN-v<version>-Windows-x64-Installer.exe`
- `Aethon-VPN-v<version>-Windows-8.1-x64-Installer.exe` and/or `Aethon-VPN-v<version>-Windows-8.1-x64-portable.zip`
- `Aethon-VPN-v<version>-Android-Universal.apk`
- SHA-256 asset digests supplied by GitHub or a `SHA256SUMS.txt` asset
- Release notes in the GitHub release body
- Android APKs signed with the same established signing key

No custom update backend is required. If the Android APK is distributed through Google Play, use of `REQUEST_INSTALL_PACKAGES` and direct self-updates should be reviewed against current Play policy.

## Windows usage

1. On Windows 10/11, install the x64 setup package or extract the portable archive. On Windows 8.1, use the dedicated 8.1 installer or extract the 8.1 portable archive and run `Aethon.cmd`. See [Windows 8.1](docs/README-Windows-8.1.md).
2. Launch Aethon.
3. Keep **VPN Mode** selected for system-wide routing, or choose **Manual SOCKS5** for proxy-only use.
4. Select a protocol and scan mode, then press **Connect**.
5. Use Diagnostics for live logs, connection testing, and network recovery.

The local SOCKS5 listener defaults to `127.0.0.1:1819`. VPN mode may request administrator permission when configuring the TUN adapter and protected routes.

### Psiphon status

The Windows Psiphon second-hop integration is **experimental and suspended**
and is not included in the current release. It is awaiting official Psiphon
integration guidance and valid `SponsorId` / `PropagationChannelId`
configuration. Psiphon is not exposed in the UI, is not launched by the
production backend, and its executable is not bundled in current installers.

The completed implementation, pinned source revision, reproducible build
instructions, license, and provenance remain in the repository for a future
reactivation review. `npm run fetch:psiphon` is a developer-only source-build
command and is not required by normal builds or release packaging. No Psiphon
traffic success is claimed.

## Android usage

1. Install the universal APK or the APK matching the device architecture.
2. Approve Android VPN permission on first connection.
3. Select the desired mode and protocol.
4. Press **Connect**.
5. Optionally add the **Aethon VPN** Quick Settings tile.

The Android application ID remains `io.github.hamvex.aethergui` for update compatibility.

## Building

### Prerequisites

- Windows 10/11 x64 (Windows 8.1 packages are produced by the same workflow)
- Node.js 22
- Rust stable with the `x86_64-pc-windows-msvc` target
- Visual Studio Build Tools with MSVC
- Java 17
- Android SDK and NDK `27.2.12479018`
- WiX Toolset prerequisites used by Tauri

### Windows

```powershell
npm ci
npm run fetch:core
npm run fetch:routing
npm test
cargo test --manifest-path src-tauri/Cargo.toml --locked
npm run build
```

Windows output is written under `src-tauri/target/release`.

### Android

Release signing credentials are required for distributable Android builds:

```powershell
$env:ANDROID_KEYSTORE_PATH = ".android-signing/firstham-aethergui.jks"
$env:ANDROID_KEYSTORE_PASSWORD = "<password>"
$env:ANDROID_KEY_ALIAS = "<alias>"
$env:ANDROID_KEY_PASSWORD = "<password>"
npm run fetch:android
Set-Location android
./gradlew.bat assembleRelease bundleRelease lintRelease
```

Android output is written under `android/app/build/outputs`.

### Universal release archive

After both platform builds complete:

```powershell
npm run package:release
```

This creates Windows x64 installers, portable files, Windows 8.1 installer and portable packages (WebView2 109 bundled), architecture-specific Android packages, checksums, and `Aethon-VPN-v2.1.1-all-platforms.zip` under `release`.

Windows 8.1 artifacts can also be built on their own after a Windows build:

```powershell
npm run package:win81
```

### Release version

The application version is written down across twelve files: `src-tauri/tauri.conf.json`,
`src-tauri/Cargo.toml`, `src-tauri/Cargo.lock`, `package.json`, `package-lock.json`,
`android/app/build.gradle` (name and code), the Android `app_version` string, the Windows
drawer, About and Updates surfaces, the diagnostics user agent, and the packaging script
defaults. One script owns all of them, and `npm test` fails if any of them drift:

```powershell
node scripts/set-version.mjs 2.2.0                     # stamp 2.2.0, and versionCode 28
node scripts/set-version.mjs 2.2.0 --version-code 40   # ...with an explicit Android code
node scripts/set-version.mjs --check                   # exit 1 if any stamp disagrees
node scripts/set-version.mjs --print                   # the version this commit builds
```

`README.md` and `AETHON_SBOM.*` are deliberately left alone: both are hand-written records of
one specific release, with its notes, digests, sizes and commit, so restamping the version
string in them would make them describe a build they were not generated from.

The release workflow asks for the version when it is started by hand - Actions, *Windows and
Android release*, **Run workflow**, `app_version` - or equivalently:

```bash
gh workflow run release.yml -f app_version=2.2.0
```

- A version is stamped into the checkout before `npm ci`, so that run builds, names and
  signs `2.2.0` without a commit changing anything.
- Empty builds the version already committed.
- On a tag push there is nothing to ask. The tag has to match `src-tauri/tauri.conf.json` or
  the run fails, so a release can never be published under a tag whose artifacts are named
  after a different version.

The resolved version is an output of the build job and is what the release notes are headed
with.

## Verification

```powershell
npm test
cargo test --manifest-path src-tauri/Cargo.toml --locked
Set-Location android
./gradlew.bat testDebugUnitTest lintDebug lintRelease
```

## Project layout

- `src/` — Windows frontend.
- `src-tauri/` — Windows native process, routing, settings, and updater code.
- `android/` — native Android client.
- `scripts/` — verified dependency fetching and release packaging.
- `.github/workflows/release.yml` — Windows/Android CI and tagged release publishing.

## Attribution

Aethon is an independent frontend and is not the upstream Aether project. Aether remains the networking engine and is distributed under GPL-3.0. See [NOTICE.md](NOTICE.md), [TRADEMARK.md](TRADEMARK.md), and [LICENSE](LICENSE).
