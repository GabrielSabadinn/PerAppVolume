import Foundation

struct BrowserTab: Identifiable, Equatable {
    let browserBundleID: String
    let tabID: Int
    let title: String
    let host: String
    let faviconURL: URL?
    let isPlaying: Bool
    let hasControl: Bool
    var gain: Float

    var id: String { "\(browserBundleID):\(tabID)" }
}

enum BrowserIdentity {
    static func bundleID(forClientName name: String) -> String? {
        switch name {
        case "safari": "com.apple.Safari"
        case "chrome": "com.google.Chrome"
        case "brave": "com.brave.Browser"
        default: nil
        }
    }
}
