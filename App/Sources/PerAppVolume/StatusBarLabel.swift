import AppKit
import AudioEngine
import SwiftUI

struct StatusBarLabel: View {
    @Environment(AudioEngine.self) private var engine

    var body: some View {
        Image(nsImage: StatusIconRenderer.image(level: mixLevel))
    }

    private var mixLevel: Float {
        engine.apps.map { LevelScale.normalized($0.level, gain: 1) }.max() ?? 0
    }
}

enum StatusIconRenderer {
    private static let canvas = NSSize(width: 18, height: 16)
    private static let barWidth: CGFloat = 3
    private static let gap: CGFloat = 2.5
    private static let weights: [CGFloat] = [0.55, 1, 0.75]
    private static let quantization: Float = 24

    static func image(level: Float) -> NSImage {
        let quantized = (level * quantization).rounded() / quantization
        let image = NSImage(size: canvas, flipped: false) { _ in
            draw(level: CGFloat(quantized))
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func draw(level: CGFloat) {
        let totalWidth = barWidth * CGFloat(weights.count) + gap * CGFloat(weights.count - 1)
        var x = (canvas.width - totalWidth) / 2
        for weight in weights {
            let height = 4 + level * 11 * weight
            let rect = NSRect(x: x, y: (canvas.height - height) / 2, width: barWidth, height: height)
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5).fill()
            x += barWidth + gap
        }
    }
}
