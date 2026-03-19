import Cocoa

class ZapSettings: ObservableObject {
    static let shared = ZapSettings()

    @Published var thumbnailScale: Double {
        didSet { UserDefaults.standard.set(thumbnailScale, forKey: "thumbnailScale") }
    }

    @Published var modifier: ModifierKey {
        didSet { UserDefaults.standard.set(modifier.rawValue, forKey: "modifier") }
    }

    @Published var triggerKey: TriggerKey {
        didSet { UserDefaults.standard.set(triggerKey.rawValue, forKey: "triggerKey") }
    }

    enum ModifierKey: String, CaseIterable {
        case option = "option"
        case control = "control"
        case command = "command"

        var mask: CGEventFlags {
            switch self {
            case .option: return .maskAlternate
            case .control: return .maskControl
            case .command: return .maskCommand
            }
        }

        var label: String {
            switch self {
            case .option: return "⌥ Option"
            case .control: return "⌃ Control"
            case .command: return "⌘ Command"
            }
        }
    }

    enum TriggerKey: String, CaseIterable {
        case tab = "tab"
        case backtick = "backtick"
        case space = "space"

        var keyCode: Int64 {
            switch self {
            case .tab: return 48
            case .backtick: return 50
            case .space: return 49
            }
        }

        var label: String {
            switch self {
            case .tab: return "Tab"
            case .backtick: return "` Backtick"
            case .space: return "Space"
            }
        }
    }

    private init() {
        let scale = UserDefaults.standard.double(forKey: "thumbnailScale")
        self.thumbnailScale = scale > 0 ? scale : 1.0

        let mod = UserDefaults.standard.string(forKey: "modifier") ?? "option"
        self.modifier = ModifierKey(rawValue: mod) ?? .option

        let key = UserDefaults.standard.string(forKey: "triggerKey") ?? "tab"
        self.triggerKey = TriggerKey(rawValue: key) ?? .tab
    }
}
