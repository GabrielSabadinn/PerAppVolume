import SwiftUI

struct CapsuleSlider: View {
    @Binding var value: Float
    var level: Float = 0
    var isMuted = false
    var isEnabled = true
    var height: CGFloat = 14

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(Theme.fill)
                    .frame(width: width * CGFloat(value))
                    .opacity(isMuted ? 0.35 : 1)
                levelFill(width: width)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(width: width))
            .simultaneousGesture(TapGesture(count: 2).onEnded { setValue(1) })
        }
        .frame(height: height)
        .background(ScrollWheelReceiver { delta in setValue(value + Float(delta) * 0.004) })
        .opacity(isEnabled ? 1 : 0.4)
        .allowsHitTesting(isEnabled)
    }

    private func levelFill(width: CGFloat) -> some View {
        Capsule()
            .fill(Theme.accent)
            .overlay(alignment: .trailing) {
                LinearGradient(colors: [.clear, .white.opacity(0.55)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 12)
                    .blur(radius: 2)
            }
            .clipShape(Capsule())
            .frame(width: width * CGFloat(value) * CGFloat(level))
            .opacity(isMuted ? 0 : 0.9)
            .animation(.linear(duration: 0.07), value: level)
    }

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in setValue(Float(gesture.location.x / width)) }
    }

    private func setValue(_ newValue: Float) {
        value = min(max(newValue, 0), 1)
    }
}
