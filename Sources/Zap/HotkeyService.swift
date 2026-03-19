import Cocoa

class HotkeyService {
    static var shared: HotkeyService?

    private var eventTap: CFMachPort?
    var onAltTab: (() -> Void)?
    var onAltRelease: (() -> Void)?

    func start() {
        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        )

        HotkeyService.shared = self

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyCallback,
            userInfo: nil
        ) else {
            print("Error: Could not create CGEventTap.")
            print("Accessibility permission required: System Settings -> Privacy -> Accessibility")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("HotkeyService started.")
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

    // Re-enable if the system disabled the tap due to timeout
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        service.reenable()
        return Unmanaged.passUnretained(event)
    }

    if type == .keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        // Tab = keyCode 48, Alt/Option flag
        if keyCode == 48 && flags.contains(.maskAlternate) {
            service.onAltTab?()
            return nil // Consume the event
        }
    } else if type == .flagsChanged {
        if !event.flags.contains(.maskAlternate) {
            service.onAltRelease?()
        }
    }

    return Unmanaged.passUnretained(event)
}
