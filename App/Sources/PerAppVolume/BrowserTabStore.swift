import Foundation

@MainActor
@Observable
final class BrowserTabStore {
    private(set) var tabsByBrowser: [String: [BrowserTab]] = [:]
    var gainSender: ((BrowserTab) -> Void)?

    func tabs(for bundleID: String?) -> [BrowserTab] {
        guard let bundleID else { return [] }
        return tabsByBrowser[bundleID] ?? []
    }

    func replaceTabs(_ tabs: [BrowserTab], for bundleID: String) {
        tabsByBrowser[bundleID] = tabs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func removeTabs(for bundleID: String) {
        tabsByBrowser[bundleID] = nil
    }

    func setGain(_ gain: Float, for tab: BrowserTab) {
        var updated = tab
        updated.gain = min(max(gain, 0), 1)
        tabsByBrowser[tab.browserBundleID] = tabs(for: tab.browserBundleID).map { $0.id == tab.id ? updated : $0 }
        gainSender?(updated)
    }
}
