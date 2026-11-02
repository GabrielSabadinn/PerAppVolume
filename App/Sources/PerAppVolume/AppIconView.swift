import AppKit
import SwiftUI

struct AppIconView: View {
    let icon: NSImage
    let glow: Float
    let isMuted: Bool

    private let size: CGFloat = 36

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .saturation(isMuted ? 0 : 1)
            .brightness(isMuted ? -0.3 : 0)
            .background(glowLayer)
            .overlay(alignment: .bottomTrailing) { muteBadge }
            .animation(.easeOut(duration: 0.24), value: isMuted)
    }

    private var glowLayer: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(DominantColor.of(icon))
            .padding(-2)
            .blur(radius: 10)
            .opacity(isMuted ? 0 : Double(glow) * 0.7)
            .animation(.linear(duration: 0.12), value: glow)
    }

    @ViewBuilder
    private var muteBadge: some View {
        if isMuted {
            Image(systemName: "speaker.slash.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color(white: 0.1)))
                .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                .offset(x: 4, y: 4)
                .transition(.scale.combined(with: .opacity))
        }
    }
}
