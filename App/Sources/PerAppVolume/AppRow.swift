import AudioEngine
import SwiftUI

struct AppRow: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(BrowserTabStore.self) private var tabStore
    let app: AudioApp
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 2) {
            mainRow
            if !tabs.isEmpty {
                TabList(tabs: tabs)
            }
        }
    }

    private var tabs: [BrowserTab] { tabStore.tabs(for: app.bundleID) }

    private var mainRow: some View {
        HStack(spacing: 12) {
            Button { engine.setMuted(!app.isMuted, for: app.id) } label: {
                AppIconView(icon: app.icon, glow: normalizedLevel * app.volume, isMuted: app.isMuted)
            }
            .buttonStyle(.plain)
            .help(app.isMuted ? "Ativar som de \(app.name)" : "Silenciar \(app.name)")

            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(app.name)
                        .font(.appName)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(stateLabel)
                        .font(.stateLabel)
                        .tracking(0.6)
                        .foregroundStyle(app.isPlaying && !app.isMuted ? Theme.textSecondary : Theme.textTertiary)
                }
                CapsuleSlider(value: volumeBinding, level: normalizedLevel, isMuted: app.isMuted)
            }

            Text("\(Int((app.volume * 100).rounded()))%")
                .font(.percent)
                .foregroundStyle(app.isMuted ? Theme.textTertiary : Theme.textSecondary)
                .strikethrough(app.isMuted, color: Theme.textTertiary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isHovering ? Theme.hover : .clear))
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.16), value: isHovering)
    }

    private var normalizedLevel: Float {
        LevelScale.normalized(app.level, gain: app.isMuted ? 0 : app.volume)
    }

    private var stateLabel: String {
        if app.isMuted { return "MUDO" }
        return app.isPlaying ? "TOCANDO" : "SILENCIOSO"
    }

    private var volumeBinding: Binding<Float> {
        Binding(get: { app.volume }, set: { engine.setVolume($0, for: app.id) })
    }
}
