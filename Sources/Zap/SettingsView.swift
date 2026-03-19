import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = ZapSettings.shared

    var body: some View {
        Form {
            Section("Shortcut") {
                Picker("Modifier", selection: $settings.modifier) {
                    ForEach(ZapSettings.ModifierKey.allCases, id: \.self) { mod in
                        Text(mod.label).tag(mod)
                    }
                }
                Picker("Key", selection: $settings.triggerKey) {
                    ForEach(ZapSettings.TriggerKey.allCases, id: \.self) { key in
                        Text(key.label).tag(key)
                    }
                }
            }

            Section("Appearance") {
                HStack {
                    Text("Size")
                    Slider(value: $settings.thumbnailScale, in: 0.5...2.0, step: 0.1)
                    Text(String(format: "%.0f%%", settings.thumbnailScale * 100))
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 340)
    }
}
