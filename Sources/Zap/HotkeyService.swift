import Cocoa

class HotkeyService {
    static var shared: HotkeyService?

    private var eventTap: CFMachPort?
    var onAltTab: (() -> Void)?
    var onAltShiftTab: (() -> Void)?
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

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        service.reenable()
        return Unmanaged.passUnretained(event)
    }

    let settings = ZapSettings.shared

    if type == .keyDown {
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
