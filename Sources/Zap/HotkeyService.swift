import Cocoa

class HotkeyService {
    static var shared: HotkeyService?

    private var eventTap: CFMachPort?
    private var retryTimer: Timer?
    fileprivate(set) var receivedKeyDown = false
    var onAltTab: (() -> Void)?
    var onAltShiftTab: (() -> Void)?
    var onAltRelease: (() -> Void)?
    var onStarted: (() -> Void)?
    var onFailed: (() -> Void)?
    var onInputMonitoringNeeded: (() -> Void)?

    func start() {
        HotkeyService.shared = self

        if tryCreateEventTap() {
            onStarted?()
        } else {
            print("Error: Could not create CGEventTap.")
            print("Accessibility permission required: System Settings -> Privacy -> Accessibility")
            onFailed?()
            startRetryTimer()
        }
    }

    private func tryCreateEventTap() -> Bool {
        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        )

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyCallback,
            userInfo: nil
        ) else {
            return false
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        // Check after a few seconds if keyDown events are flowing.
        // If only flagsChanged arrives, Input Monitoring permission is likely missing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.eventTap != nil, !self.receivedKeyDown else { return }
            print("Warning: Event tap is active but no key events received.")
            print("Input Monitoring permission may be required: System Settings -> Privacy & Security -> Input Monitoring")
            self.onInputMonitoringNeeded?()
        }

        return true
    }

    private func startRetryTimer() {
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if AXIsProcessTrusted() {
                timer.invalidate()
                self.retryTimer = nil
                if self.tryCreateEventTap() {
                    print("HotkeyService started after permission grant.")
                    self.onStarted?()
                }
            }
        }
    }

    func reenable() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
}

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let service = HotkeyService.shared else {
        return Unmanaged.passUnretained(event)
    }

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        service.reenable()
        return Unmanaged.passUnretained(event)
    }

    let settings = ZapSettings.shared

    if type == .keyDown {
        service.receivedKeyDown = true
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        if keyCode == settings.triggerKey.keyCode && flags.contains(settings.modifier.mask) {
            if flags.contains(.maskShift) {
                service.onAltShiftTab?()
            } else {
                service.onAltTab?()
            }
            return nil
        }
    } else if type == .flagsChanged {
        if !event.flags.contains(settings.modifier.mask) {
            service.onAltRelease?()
        }
    }

    return Unmanaged.passUnretained(event)
}
