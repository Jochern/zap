import Cocoa

func focusWindow(_ window: ZapWindow) {
    guard let app = NSRunningApplication(processIdentifier: window.pid) else { return }
    app.activate(options: .activateIgnoringOtherApps)

    let axApp = AXUIElementCreateApplication(window.pid)
    var windowsRef: CFTypeRef?
    AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)

    guard let axWindows = windowsRef as? [AXUIElement] else { return }

    // Try to match the correct window by title
    for axWindow in axWindows {
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
        let axTitle = titleRef as? String ?? ""

        if axTitle == window.title || axWindows.count == 1 {
            AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, true as CFTypeRef)
            AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
            return
        }
    }

    // Fallback: raise the first window
    if let first = axWindows.first {
        AXUIElementSetAttributeValue(first, kAXMainAttribute as CFString, true as CFTypeRef)
        AXUIElementPerformAction(first, kAXRaiseAction as CFString)
    }
}
