import AppKit
import SwiftUI

enum DominantColor {
    private static let sampleSize = 24
    private static var cache: [ObjectIdentifier: Color] = [:]

    static func of(_ image: NSImage) -> Color {
        let key = ObjectIdentifier(image)
        if let cached = cache[key] { return cached }
        let color = compute(image) ?? Theme.accentStart
        cache[key] = color
        return color
    }

    private static func compute(_ image: NSImage) -> Color? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let space = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)
        guard let context = CGContext(data: &pixels, width: sampleSize, height: sampleSize, bitsPerComponent: 8, bytesPerRow: sampleSize * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
        return weightedHue(of: pixels)
    }

    private static func weightedHue(of pixels: [UInt8]) -> Color? {
        var sumX: Double = 0
        var sumY: Double = 0
        var sumSaturation: Double = 0
        var sumBrightness: Double = 0
        var weightTotal: Double = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0.5 else { continue }
            let color = NSColor(red: CGFloat(pixels[index]) / 255, green: CGFloat(pixels[index + 1]) / 255, blue: CGFloat(pixels[index + 2]) / 255, alpha: 1)
            let saturation = Double(color.saturationComponent)
            let brightness = Double(color.brightnessComponent)
            let weight = saturation * saturation * brightness * alpha
            guard weight > 0.02 else { continue }
            let angle = Double(color.hueComponent) * 2 * .pi
            sumX += cos(angle) * weight
            sumY += sin(angle) * weight
            sumSaturation += saturation * weight
            sumBrightness += brightness * weight
            weightTotal += weight
        }
        guard weightTotal > 0.5 else { return nil }
        var hue = atan2(sumY, sumX) / (2 * .pi)
        if hue < 0 { hue += 1 }
        let saturation = min(sumSaturation / weightTotal + 0.15, 1)
        let brightness = min(sumBrightness / weightTotal + 0.1, 1)
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}
