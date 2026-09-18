#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

/// Point WebView2 at a Fixed Version runtime shipped next to the executable.
///
/// Windows 8.1 cannot install the Evergreen runtime the Windows 10/11 installer
/// embeds. The 8.1 installer and portable therefore copy WebView2 109 into
/// `WebView2Runtime\` beside `Aethon.exe`. Setting this variable before Tauri
/// creates the window is what makes that folder take effect; a `.cmd` launcher
/// does the same thing, but launching the exe directly has to work too.
fn prepare_bundled_webview2() {
    if std::env::var_os("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER").is_some() {
        return;
    }
    let Ok(exe) = std::env::current_exe() else {
        return;
    };
    let Some(dir) = exe.parent() else {
        return;
    };
    let mut candidates = vec![dir.join("WebView2Runtime")];
    if let Ok(entries) = std::fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir()
                && path
                    .file_name()
                    .and_then(|name| name.to_str())
                    .is_some_and(|name| name.starts_with("Microsoft.WebView2.FixedVersionRuntime."))
            {
                candidates.push(path);
            }
        }
    }
    for candidate in candidates {
        if candidate.join("msedgewebview2.exe").is_file() {
            std::env::set_var("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER", &candidate);
            return;
        }
        if let Ok(entries) = std::fs::read_dir(&candidate) {
            for entry in entries.flatten() {
                let nested = entry.path();
                if nested.join("msedgewebview2.exe").is_file() {
                    std::env::set_var("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER", nested);
                    return;
                }
            }
        }
    }
}

fn main() {
    prepare_bundled_webview2();
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
    aether_gui_lib::run();
}
