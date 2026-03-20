import Cocoa
import SwiftUI

struct ZapWindow {
    let appName: String
    let title: String
    let windowID: CGWindowID
    let pid: pid_t
    let icon: NSImage?
    var thumbnail: NSImage?
}

func fetchWindows(iconCache: inout [pid_t: NSImage]) -> [ZapWindow] {
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
        let icon: NSImage? = iconCache[pid] ?? {
            let img = NSRunningApplication(processIdentifier: pid)?.icon
            if let img { iconCache[pid] = img }
            return img
        }()

        return ZapWindow(appName: appName, title: title, windowID: windowID, pid: pid, icon: icon, thumbnail: nil)
    }
}

func captureThumbnail(for window: ZapWindow, maxWidth: CGFloat = 296) -> NSImage? {
    guard let cgImage = CGWindowListCreateImage(
        .null, .optionIncludingWindow, window.windowID, [.boundsIgnoreFraming]
    ) else { return nil }
    let origW = CGFloat(cgImage.width)
    let origH = CGFloat(cgImage.height)
    guard origW > 0, origH > 0 else { return nil }
    let scale = min(1, maxWidth / origW)
    let newW = origW * scale
    let newH = origH * scale
    let img = NSImage(size: NSSize(width: newW, height: newH))
    img.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    NSRect(x: 0, y: 0, width: newW, height: newH).fill(using: .clear)
    NSImage(cgImage: cgImage, size: NSSize(width: origW, height: origH))
        .draw(in: NSRect(x: 0, y: 0, width: newW, height: newH))
    img.unlockFocus()
    return img
}

// MARK: - App Delegate

class ZapAppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeyService = HotkeyService()
    private let switcherState = SwitcherState()
    private var panel: SwitcherPanel?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var thumbnailCache: [CGWindowID: NSImage] = [:]
    private var iconCache: [pid_t: NSImage] = [:]

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
        hotkeyService.onStarted = { [weak self] in
            DispatchQueue.main.async { self?.updateMenuBarIcon(active: true) }
        }
        hotkeyService.onFailed = { [weak self] in
            DispatchQueue.main.async {
                self?.updateMenuBarIcon(active: false)
                self?.showPermissionAlert()
            }
        }
        hotkeyService.onInputMonitoringNeeded = { [weak self] in
            DispatchQueue.main.async {
                self?.updateMenuBarIcon(active: false)
                self?.showInputMonitoringAlert()
            }
        }
        hotkeyService.start()

        let settings = ZapSettings.shared
        if settings.hasSystemConflict {
            print("Note: \(settings.conflictDescription ?? "System shortcut conflict detected.")")
        }

        print("Zap running. \(ZapSettings.shared.modifier.label)+\(ZapSettings.shared.triggerKey.label) to switch windows.")
    }

    private func checkAccessibility() {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        if !trusted {
            print("Accessibility permission required. A system prompt should appear.")
        }

        // On macOS 14+, Input Monitoring is separate from Accessibility.
        // IOHIDRequestAccess triggers the system prompt for Input Monitoring.
        if #available(macOS 14.0, *) {
            let hasInputMonitoring = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            if !hasInputMonitoring {
                print("Input Monitoring permission required for keyboard events.")
            }
        }

        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            print("Screen Recording permission required for window thumbnails.")
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Zap Needs Permissions"
        alert.informativeText = "Zap requires these permissions to work:\n\n• Accessibility – to intercept keyboard shortcuts\n• Input Monitoring – to receive key events (macOS 14+)\n\nGo to System Settings → Privacy & Security and enable Zap under both Accessibility and Input Monitoring.\n\nZap will activate automatically once permissions are granted."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        activateApp()
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func showInputMonitoringAlert() {
        let alert = NSAlert()
        alert.messageText = "Zap Needs Input Monitoring"
        alert.informativeText = "Zap can detect modifier keys but not keyboard shortcuts.\n\nThis usually means Input Monitoring permission is missing.\n\nGo to System Settings → Privacy & Security → Input Monitoring and enable Zap (or your terminal if running from terminal)."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        activateApp()
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func updateMenuBarIcon(active: Bool) {
        if let button = statusItem?.button {
            let symbolName = active ? "bolt.fill" : "bolt.trianglebadge.exclamationmark"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Zap")
            button.toolTip = active ? "Zap – Window Switcher" : "Zap – Accessibility permission required"
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
        activateApp()
    }

    private func setupPanel() {
        let panel = SwitcherPanel()
        let maxWidth = (NSScreen.screens.first?.frame.width ?? 1200) * 0.8
        let hostingView = NSHostingView(rootView: SwitcherView(state: switcherState, maxWidth: maxWidth))
        panel.contentView = hostingView
        self.panel = panel
    }

    private func showPanel() {
        let mouseScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
        guard let panel = panel, let screen = mouseScreen ?? NSScreen.main,
              let contentView = panel.contentView else { return }

        // Position offscreen first so SwiftUI can lay out the new content
        panel.setFrameOrigin(NSPoint(x: -10000, y: -10000))
        panel.orderFrontRegardless()

        // After SwiftUI has laid out, reposition to center of screen
        DispatchQueue.main.async {
            contentView.layoutSubtreeIfNeeded()
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
            var windows = fetchWindows(iconCache: &iconCache)
            // Evict stale cache entries for windows that no longer exist
            let activeIDs = Set(windows.map(\.windowID))
            thumbnailCache = thumbnailCache.filter { activeIDs.contains($0.key) }
            // Apply cached thumbnails so the panel opens with content immediately
            for i in windows.indices {
                if let cached = thumbnailCache[windows[i].windowID] {
                    windows[i].thumbnail = cached
                }
            }
            switcherState.windows = windows
            switcherState.selectedIndex = windows.count > 1 ? 1 : 0
            switcherState.hoverEnabled = false
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
                    self.switcherState.windows[i].thumbnail = thumb
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

// MARK: - Helpers

func activateApp() {
    if #available(macOS 14.0, *) {
        NSApp.activate()
    } else {
        NSApp.activate(ignoringOtherApps: true)
    }
}

func activateRunningApp(_ app: NSRunningApplication) {
    if #available(macOS 14.0, *) {
        app.activate()
    } else {
        app.activate(options: .activateIgnoringOtherApps)
    }
}

// MARK: - Start

let app = NSApplication.shared
let delegate = ZapAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
