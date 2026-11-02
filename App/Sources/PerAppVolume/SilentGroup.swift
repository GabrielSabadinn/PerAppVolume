import AudioEngine
import SwiftUI

struct SilentGroup: View {
    let apps: [AudioApp]
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 2) {
            Button {
                withAnimation(Theme.rowSpring) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Rectangle().fill(Theme.line).frame(width: 6, height: 1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    Text("SILENCIOSOS \(apps.count)")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                    Rectangle().fill(Theme.line).frame(height: 1)
                }
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(apps) { app in
                    AppRow(app: app)
                        .opacity(0.65)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }
}
