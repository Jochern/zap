import Cocoa

struct ZapWindow {
    let appName: String
    let title: String
    let windowID: CGWindowID
    let pid: pid_t
}

func fetchWindows() -> [ZapWindow] {
    guard let list = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
    ) as? [[String: Any]] else { return [] }

    return list.compactMap { info in
        guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
              let pid = info[kCGWindowOwnerPID as String] as? Int32,
              let appName = info[kCGWindowOwnerName as String] as? String
        else { return nil }

        let title = info[kCGWindowName as String] as? String ?? "(untitled)"
        let windowID = info[kCGWindowNumber as String] as? CGWindowID ?? 0

        return ZapWindow(appName: appName, title: title, windowID: windowID, pid: pid)
    }
}

// MARK: - App Delegate

class ZapAppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeyService = HotkeyService()
    private var windows: [ZapWindow] = []
    private var currentIndex = -1
    private var isSwitching = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        windows = fetchWindows()
        print("=== Zap: found \(windows.count) windows ===")
        for (i, w) in windows.enumerated() {
            print("  [\(i)] [\(w.appName)] \(w.title)")
        }

        hotkeyService.onAltTab = { [weak self] in
            self?.cycleNext()
        }
        hotkeyService.onAltRelease = { [weak self] in
            self?.selectCurrent()
        }
        hotkeyService.start()
        print("\nOpt+Tab to switch windows. Ctrl+C to quit.")
    }

    private func cycleNext() {
        if !isSwitching {
            windows = fetchWindows()
            isSwitching = true
            currentIndex = 0
        } else {
            guard !windows.isEmpty else { return }
            currentIndex = (currentIndex + 1) % windows.count
        }

        guard !windows.isEmpty else { return }
        let w = windows[currentIndex]
        print("  -> [\(w.appName)] \(w.title)")
    }

    private func selectCurrent() {
        guard isSwitching, !windows.isEmpty else { return }
        let w = windows[currentIndex]
        print("  => Focus: [\(w.appName)] \(w.title)")
        focusWindow(w)
        isSwitching = false
        currentIndex = -1
    }
}

// MARK: - Start

let app = NSApplication.shared
let delegate = ZapAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
