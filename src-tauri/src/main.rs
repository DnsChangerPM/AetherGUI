#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

/// Explain, in both UI languages, and exit when the GUI is launched on a Windows older
/// than Windows 10.
///
/// The desktop UI is rendered by the Microsoft Edge WebView2 runtime, which Microsoft
/// only ships for Windows 10 (1903+) and Windows 11, so on Windows 8.1 and earlier the
/// application cannot run in any build. The installers deliberately still work on those
/// systems, so instead of failing deep inside WebView2 initialization with a technical
/// error, the GUI states the requirement itself and exits cleanly.
///
/// `RtlGetVersion` is used because it reports the true OS version regardless of the
/// compatibility shims that distort `GetVersionEx`; CLI helper invocations (routing
/// repair, routing helper) return before this check and do not need the webview.
#[cfg(windows)]
fn require_supported_windows_for_gui() {
    use windows_sys::Win32::System::SystemInformation::OSVERSIONINFOW;
    use windows_sys::Win32::System::SystemServices::RtlGetVersion;
    use windows_sys::Win32::UI::WindowsAndMessaging::{MessageBoxW, MB_ICONWARNING, MB_OK};

    unsafe {
        let mut version: OSVERSIONINFOW = std::mem::zeroed();
        version.dwOSVersionInfoSize = std::mem::size_of::<OSVERSIONINFOW>() as u32;
        // Fail open: if the version cannot be read, continue and let normal startup
        // report whatever goes wrong there.
        if RtlGetVersion(&mut version) != 0 || version.dwMajorVersion >= 10 {
            return;
        }
        let message: Vec<u16> = concat!(
            "This version of Aethon VPN requires Windows 10 (version 1903 or later) or Windows 11.\n",
            "This computer is running an older Windows, so the app cannot start.\n",
            "To use Aethon VPN, upgrade this PC to Windows 10 or Windows 11.\n",
            "\n",
            "Aethon VPN به Windows 10 (نسخه 1903 یا جدیدتر) یا Windows 11 نیاز دارد.\n",
            "این سیستم نسخه‌ای قدیمی‌تری از ویندوز دارد و برنامه نمی‌تواند اجرا شود.\n",
            "برای استفاده از Aethon VPN، ویندوز این رایانه را به Windows 10 یا 11 ارتقا دهید."
        )
        .encode_utf16()
        .chain(std::iter::once(0))
        .collect();
        let title: Vec<u16> = "Aethon VPN — Windows 10 required\0".encode_utf16().collect();
        MessageBoxW(
            std::ptr::null_mut(),
            message.as_ptr(),
            title.as_ptr(),
            MB_OK | MB_ICONWARNING,
        );
        std::process::exit(1);
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() == 2 && args[1] == "--repair-network" {
        if let Err(error) = aether_gui_lib::routing::repair_cli() {
            eprintln!("{error}");
            std::process::exit(3);
        }
        return;
    }
    if args.len() == 3 && args[1] == "--routing-helper" {
        if let Err(error) = aether_gui_lib::routing::helper_main(std::path::Path::new(&args[2])) {
            eprintln!("{error}");
            std::process::exit(2);
        }
        return;
    }
    if args.len() == 3 && args[1] == "--repair-network" {
        if let Err(error) = aether_gui_lib::routing::repair_main(std::path::Path::new(&args[2])) {
            eprintln!("{error}");
            std::process::exit(3);
        }
        return;
    }
    #[cfg(windows)]
    require_supported_windows_for_gui();
    aether_gui_lib::run();
}
