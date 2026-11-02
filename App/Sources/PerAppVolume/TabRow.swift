import SwiftUI

struct TabRow: View {
    @Environment(BrowserTabStore.self) private var store
    let tab: BrowserTab
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            favicon
            VStack(spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(tab.title.isEmpty ? tab.host : tab.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .help(tab.title)
                    Spacer(minLength: 8)
                    if !tab.hasControl {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.warning)
                            .help("Esta página não deixou a extensão assumir o áudio")
                    }
                    Text(tab.host)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
                CapsuleSlider(value: gainBinding, height: 10)
            }
            Text("\(Int((tab.gain * 100).rounded()))%")
                .font(.percent)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(isHovering ? Theme.hover : .clear))
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
    }

    private var favicon: some View {
        AsyncImage(url: tab.faviconURL) { image in
            image.resizable().interpolation(.high)
        } placeholder: {
            Image(systemName: "globe")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(width: 16, height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var gainBinding: Binding<Float> {
        Binding(get: { tab.gain }, set: { store.setGain($0, for: tab) })
    }
}

struct TabList: View {
    let tabs: [BrowserTab]

    var body: some View {
        VStack(spacing: 1) {
            ForEach(tabs) { tab in
                TabRow(tab: tab)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.leading, 38)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.line)
                .frame(width: 2)
                .padding(.leading, 23)
                .padding(.vertical, 6)
        }
        .animation(Theme.rowSpring, value: tabs.map(\.id))
    }
}
