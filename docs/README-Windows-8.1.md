# Aethon on Windows 8.1

Windows 8.1 x64 is supported through a **dedicated installer and a portable package**. The regular Windows 10/11 installer will refuse to continue on 8.1 because Microsoft’s current WebView2 Evergreen runtime no longer installs there.

## Which file to download

From the [GitHub Releases](https://github.com/hamvex/AetherGUI/releases) page, after the workflow has run:

| File | Use |
| --- | --- |
| `Aethon-VPN-vVERSION-Windows-8.1-x64-Installer.exe` | Recommended. Per-user install, Start Menu shortcut, bundled WebView2 109. |
| `Aethon-VPN-vVERSION-Windows-8.1-x64-portable.zip` | No installer. Extract and run `Aethon.cmd`. Same files, including WebView2 109. |

Do **not** use `Aethon-VPN-vVERSION-Windows-x64-Installer.exe` or the MSI on Windows 8.1.

## Persian / فارسی

ویندوز ۸.۱ نسخه ۶۴ بیت با **اینستالر جدا** و در صورت نیاز با **پکیج پرتابل** پشتیبانی می‌شود.

- فایل درست: `Aethon-VPN-vنسخه-Windows-8.1-x64-Installer.exe`
- اگر اینستالر را نخواستید، زیپ پرتابل را باز کنید و `Aethon.cmd` را اجرا کنید.
- اینستالر معمولی ویندوز ۱۰/۱۱ روی ۸.۱ نصب نمی‌شود؛ عمداً متوقف می‌شود چون WebView2 جدید روی ۸.۱ نصب نمی‌گردد.

پیش‌نیازها:

1. ویندوز ۸.۱ ۶۴ بیت با Update 1 (KB2919355)
2. Universal CRT (KB2999226) اگر برنامه باز نشد
3. در صورت نیاز Visual C++ Redistributable 2015–2022 x64

حالت VPN همچنان دسترسی Administrator می‌خواهد (آداپتور TUN). حالت SOCKS5 بدون ادمین کار می‌کند.

## Prerequisites

- Windows 8.1 x64 with Update 1 (KB2919355)
- Universal C Runtime update KB2999226 if the program will not start
- Visual C++ 2015–2022 x64 redistributable if `vcruntime140.dll` is missing

VPN Mode still requests Administrator permission to configure the Wintun adapter. Manual SOCKS5 does not.

## What the 8.1 package contains

- `Aethon.exe` — desktop UI
- `Aethon.cmd` — launcher that points WebView2 at the bundled runtime
- `aether.exe`, `xray.exe`, `wintun.dll` — the same pinned engines as the Windows 10 build
- `WebView2Runtime\` — Microsoft Edge WebView2 **Fixed Version 109.0.1518.78**, the last runtime that runs on Windows 8.1

`Aethon.exe` also looks next to itself for `WebView2Runtime\msedgewebview2.exe` and sets `WEBVIEW2_BROWSER_EXECUTABLE_FOLDER` before the window opens, so launching the exe directly still works.

## Building these packages

The GitHub Actions workflow `.github/workflows/release.yml` produces both 8.1 artifacts whenever it builds Windows. Locally, after a normal Windows build:

```powershell
npm run package:win81
```

That script verifies the WebView2 109 cabinet (pinned URL and size in `scripts/win81-pins.json`), requires a Microsoft Authenticode signature on `msedgewebview2.exe`, writes the portable zip, and builds the NSIS installer when `makensis.exe` is available.
