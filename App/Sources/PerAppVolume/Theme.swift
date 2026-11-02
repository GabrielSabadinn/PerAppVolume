import SwiftUI

enum Theme {
    static let accentStart = Color(red: 0.43, green: 0.91, blue: 0.97)
    static let accentEnd = Color(red: 0.65, green: 0.55, blue: 0.98)
    static let accent = LinearGradient(colors: [accentStart, accentEnd], startPoint: .leading, endPoint: .trailing)
    static let healthy = Color(red: 0.37, green: 0.92, blue: 0.83)
    static let warning = Color(red: 0.98, green: 0.6, blue: 0.3)
    static let text = Color(white: 0.95)
    static let textSecondary = Color(red: 0.6, green: 0.62, blue: 0.7)
    static let textTertiary = Color(red: 0.37, green: 0.39, blue: 0.47)
    static let track = Color.white.opacity(0.06)
    static let fill = Color.white.opacity(0.14)
    static let line = Color.white.opacity(0.08)
    static let hover = Color.white.opacity(0.045)
    static let panelWidth: CGFloat = 340
    static let rowSpring = Animation.spring(duration: 0.28, bounce: 0.18)
}

extension Font {
    static let panelTitle = Font.system(size: 13, weight: .semibold)
    static let appName = Font.system(size: 13, weight: .semibold)
    static let stateLabel = Font.system(size: 10, weight: .semibold)
    static let percent = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let footer = Font.system(size: 11.5, weight: .semibold)
}
