import Cocoa
import SwiftUI

struct ZapWindow {
    let appName: String
    let title: String
    let windowID: CGWindowID
    let pid: pid_t
    let icon: NSImage?
    let thumbnail: NSImage?
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
        let icon = NSRunningApplication(processIdentifier: pid)?.icon

        return ZapWindow(appName: appName, title: title, windowID: windowID, pid: pid, icon: icon, thumbnail: nil)
    }
}

func captureThumbnail(for window: ZapWindow) -> NSImage? {
    guard let cgImage = CGWindowListCreateImage(
        .null, .optionIncludingWindow, window.windowID, [.boundsIgnoreFraming, .bestResolution]
    ) else { return nil }
    return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
}

// MARK: - App Delegate

class ZapAppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeyService = HotkeyService()
    private let switcherState = SwitcherState()
    private var panel: SwitcherPanel?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var thumbnailCache: [CGWindowID: NSImage] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkAccessibility()
        setupPanel()
        setupMenuBar()

        hotkeyService.onAltTab = { [weak self] in
            DispatchQueue.main.async { self?.cycle(forward: true) }
        }
        hotkeyService.onAltShiftTab = { [weak self] in
            DispatchQueue.main.async { self?.cycle(forward: false) }
        }
        hotkeyService.onAltRelease = { [weak self] in
            DispatchQueue.main.async { self?.selectCurrent() }
        }
        hotkeyService.start()
        print("Zap running. \(ZapSettings.shared.modifier.label)+\(ZapSettings.shared.triggerKey.label) to switch windows.")
    }

    private func checkAccessibility() {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        if !trusted {
            print("Accessibility permission required. A system prompt should appear.")
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Zap")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Zap", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let hostingView = NSHostingView(rootView: SettingsView())
            hostingView.setFrameSize(hostingView.fittingSize)
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Zap Settings"
            window.contentView = hostingView
            window.center()
            self.settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupPanel() {
        let panel = SwitcherPanel()
        let maxWidth = (NSScreen.main?.frame.width ?? 1200) * 0.8
        let hostingView = NSHostingView(rootView: SwitcherView(state: switcherState, maxWidth: maxWidth))
        panel.contentView = hostingView
        self.panel = panel
    }

    private func showPanel() {
        guard let panel = panel, let screen = NSScreen.main else { return }

        panel.orderFrontRegardless()

        DispatchQueue.main.async {
            guard let contentView = panel.contentView else { return }
            let contentSize = contentView.fittingSize
            let screenFrame = screen.frame
            let origin = CGPoint(
                x: screenFrame.midX - contentSize.width / 2,
                y: screenFrame.midY - contentSize.height / 2
            )
            panel.setFrame(NSRect(origin: origin, size: contentSize), display: true)
        }
    }

    private func hidePanel() {
        panel?.orderOut(nil)
    }

    private func cycle(forward: Bool) {
        if switcherState.windows.isEmpty {
            var windows = fetchWindows()
            // Apply cached thumbnails so the panel opens with content immediately
            for i in windows.indices {
                if let cached = thumbnailCache[windows[i].windowID] {
                    windows[i] = ZapWindow(
                        appName: windows[i].appName, title: windows[i].title,
                        windowID: windows[i].windowID, pid: windows[i].pid,
                        icon: windows[i].icon, thumbnail: cached
                    )
                }
            }
            switcherState.windows = windows
            switcherState.selectedIndex = windows.count > 1 ? 1 : 0
            showPanel()
            loadThumbnails()
        } else {
            let count = switcherState.windows.count
            if forward {
                switcherState.selectedIndex = (switcherState.selectedIndex + 1) % count
            } else {
                switcherState.selectedIndex = (switcherState.selectedIndex - 1 + count) % count
            }
        }
    }

    private func loadThumbnails() {
        let windows = switcherState.windows
        DispatchQueue.global(qos: .userInitiated).async {
            for (i, window) in windows.enumerated() {
                let thumb = captureThumbnail(for: window)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.switcherState.windows.count > i else { return }
                    if let thumb {
                        self.thumbnailCache[window.windowID] = thumb
                    }
                    self.switcherState.windows[i] = ZapWindow(
                        appName: window.appName, title: window.title,
                        windowID: window.windowID, pid: window.pid,
                        icon: window.icon, thumbnail: thumb
                    )
                }
            }
        }
    }

    private func selectCurrent() {
        guard !switcherState.windows.isEmpty else { return }
        let w = switcherState.windows[switcherState.selectedIndex]
        focusWindow(w)
        hidePanel()
        switcherState.windows = []
        switcherState.selectedIndex = 0
    }
}

// MARK: - Start

let app = NSApplication.shared
let delegate = ZapAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
