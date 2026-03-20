import SwiftUI

class SwitcherState: ObservableObject {
    @Published var windows: [ZapWindow] = []
    @Published var selectedIndex: Int = 0
    @Published var hoverEnabled: Bool = false
}

struct WindowItemView: View {
    let window: ZapWindow
    let isSelected: Bool
    let scale: CGFloat

    private var thumbWidth: CGFloat { 148 * scale }
    private var thumbHeight: CGFloat { 90 * scale }
    private var itemWidth: CGFloat { 160 * scale }

    var body: some View {
        VStack(spacing: 6) {
            thumbnailView
            HStack(spacing: 4) {
                iconView
                Text(window.appName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            Text(window.title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: itemWidth)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.3) : Color.clear)
        )
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumb = window.thumbnail {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: thumbWidth, height: thumbHeight)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: thumbWidth, height: thumbHeight)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = window.icon {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: "macwindow")
                .font(.system(size: 12))
                .frame(width: 16, height: 16)
        }
    }
}

struct SwitcherView: View {
    @ObservedObject var state: SwitcherState
    @ObservedObject var settings = ZapSettings.shared
    let maxWidth: CGFloat

    private let spacing: CGFloat = 4

    private var itemWidth: CGFloat { 172 * settings.thumbnailScale }

    private var columns: [GridItem] {
        let maxCount = max(1, Int((maxWidth - 24) / (itemWidth + spacing)))
        let count = min(maxCount, max(1, state.windows.count))
        return Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            ForEach(Array(state.windows.enumerated()), id: \.offset) { index, window in
                WindowItemView(window: window, isSelected: index == state.selectedIndex, scale: settings.thumbnailScale)
                    .onHover { hovering in
                        if hovering {
                            if state.hoverEnabled {
                                state.selectedIndex = index
                            } else {
                                state.hoverEnabled = true
                            }
                        }
                    }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(radius: 20)
        )
    }
}
