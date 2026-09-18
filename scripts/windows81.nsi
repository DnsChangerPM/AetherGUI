; Aethon installer for Windows 8.1 x64.
;
; The Windows 10/11 NSIS installer embeds the Evergreen WebView2 bootstrapper, which
; Microsoft no longer serves for Windows 8.1. This script installs the same application
; files plus the last WebView2 Fixed Version that still runs on 8.1 (109.0.1518.78) and
; never talks to the Evergreen CDN.
;
; Required defines (passed by scripts/package-windows81.ps1):
;   APP_VERSION   e.g. 2.1.1
;   SOURCE_DIR    staging directory that already contains Aethon.exe, sidecars, WebView2Runtime
;   OUT_FILE      full path of the installer to write

!ifndef APP_VERSION
  !error "APP_VERSION is required"
!endif
!ifndef SOURCE_DIR
  !error "SOURCE_DIR is required"
!endif
!ifndef OUT_FILE
  !error "OUT_FILE is required"
!endif

Unicode True
Name "Aethon ${APP_VERSION} (Windows 8.1)"
OutFile "${OUT_FILE}"
InstallDir "$LOCALAPPDATA\Aethon"
RequestExecutionLevel user
SetCompressor zlib
ShowInstDetails show
ShowUninstDetails show

!include "MUI2.nsh"
!include "WinVer.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"

!define MUI_ABORTWARNING
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\AethonWin81"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\Aethon.cmd"
!define MUI_FINISHPAGE_RUN_TEXT "Launch Aethon"
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "Aethon requires 64-bit Windows 8.1."
    Abort
  ${EndIf}
  ${If} ${AtLeastWin10}
    MessageBox MB_OK|MB_ICONINFORMATION "This installer is only for Windows 8.1. Windows 10 and 11 users should use Aethon-VPN-v${APP_VERSION}-Windows-x64-Installer.exe."
    Abort
  ${EndIf}
  ${IfNot} ${AtLeastWin8.1}
    MessageBox MB_OK|MB_ICONSTOP "Aethon for Windows 8.1 requires Windows 8.1 x64 (version 6.3) or later. Windows 10/11 users should use the standard installer."
    Abort
  ${EndIf}
  SetRegView 64
FunctionEnd

Section "Install"
  SetOutPath "$INSTDIR"

  File "${SOURCE_DIR}\Aethon.exe"
  File "${SOURCE_DIR}\Aethon.cmd"
  File "${SOURCE_DIR}\aether.exe"
  File "${SOURCE_DIR}\xray.exe"
  File "${SOURCE_DIR}\wintun.dll"
  File "${SOURCE_DIR}\LICENSE"
  File "${SOURCE_DIR}\NOTICE.md"
  File "${SOURCE_DIR}\TRADEMARK.md"
  File "${SOURCE_DIR}\xray-LICENSE.txt"
  File "${SOURCE_DIR}\wintun-LICENSE.txt"
  File "${SOURCE_DIR}\README-Windows-8.1.txt"

  ; Fixed Version 109 lives next to the executable. Aethon.exe (and Aethon.cmd) point
  ; WEBVIEW2_BROWSER_EXECUTABLE_FOLDER at this folder, so the GUI never needs Evergreen.
  SetOutPath "$INSTDIR\WebView2Runtime"
  File /r "${SOURCE_DIR}\WebView2Runtime\*.*"

  SetOutPath "$INSTDIR"
  CreateDirectory "$SMPROGRAMS"
  CreateShortCut "$SMPROGRAMS\Aethon.lnk" "$INSTDIR\Aethon.cmd" "" "$INSTDIR\Aethon.exe" 0

  IfSilent skip_desktop
  MessageBox MB_YESNO|MB_ICONQUESTION "Create an Aethon shortcut on the Desktop?" IDNO skip_desktop
  CreateShortCut "$DESKTOP\Aethon.lnk" "$INSTDIR\Aethon.cmd" "" "$INSTDIR\Aethon.exe" 0
  skip_desktop:

  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "Aethon ${APP_VERSION} (Windows 8.1)"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "hamvex"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" "$INSTDIR\Uninstall.exe /S"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\Aethon.exe"
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "EstimatedSize" "$0"
SectionEnd

Section "Uninstall"
  IfFileExists "$INSTDIR\Aethon.exe" 0 skip_repair
  ExecWait '"$INSTDIR\Aethon.exe" --repair-network'
  Sleep 3000
  skip_repair:

  RMDir /r "$INSTDIR\WebView2Runtime"
  Delete "$INSTDIR\Aethon.exe"
  Delete "$INSTDIR\Aethon.cmd"
  Delete "$INSTDIR\aether.exe"
  Delete "$INSTDIR\xray.exe"
  Delete "$INSTDIR\wintun.dll"
  Delete "$INSTDIR\LICENSE"
  Delete "$INSTDIR\NOTICE.md"
  Delete "$INSTDIR\TRADEMARK.md"
  Delete "$INSTDIR\xray-LICENSE.txt"
  Delete "$INSTDIR\wintun-LICENSE.txt"
  Delete "$INSTDIR\README-Windows-8.1.txt"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"

  Delete "$SMPROGRAMS\Aethon.lnk"
  Delete "$DESKTOP\Aethon.lnk"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
SectionEnd
