import AudioEngine
import SwiftUI

struct VolumePanel: View {
    @Environment(AudioEngine.self) private var engine

    var body: some View {
        VStack(spacing: 12) {
            MasterSection()
            if engine.apps.isEmpty {
                EmptyState()
            } else {
                appList
            }
            PanelFooter()
        }
        .padding(14)
        .frame(width: Theme.panelWidth)
    }

    private var appList: some View {
        VStack(spacing: 2) {
            ForEach(playingApps) { app in
                AppRow(app: app)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if !silentApps.isEmpty {
                SilentGroup(apps: silentApps)
            }
        }
        .animation(Theme.rowSpring, value: engine.apps.map(\.id))
        .animation(Theme.rowSpring, value: playingApps.map(\.id))
    }

    private var playingApps: [AudioApp] { engine.apps.filter(\.isPlaying) }
    private var silentApps: [AudioApp] { engine.apps.filter { !$0.isPlaying } }
}
