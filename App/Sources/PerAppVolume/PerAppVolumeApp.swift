import AudioEngine
import SwiftUI

@main
struct PerAppVolumeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            VolumePanel()
                .environment(delegate.engine)
                .environment(delegate.tabStore)
                .preferredColorScheme(.dark)
        } label: {
            StatusBarLabel()
                .environment(delegate.engine)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(delegate.engine)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = AudioEngine()
    let tabStore = BrowserTabStore()
    private lazy var bridge = BrowserBridgeServer(token: Bundle.main.object(forInfoDictionaryKey: "PerAppVolumeToken") as? String ?? "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine.start()
        startBridge()
    }

    func applicationWillTerminate(_ notification: Notification) {
        bridge.stop()
        engine.stop()
    }

    private func startBridge() {
        bridge.onTabs = { [tabStore] bundleID, tabs in
            DispatchQueue.main.async { tabStore.replaceTabs(tabs, for: bundleID) }
        }
        bridge.onDisconnect = { [tabStore] bundleID in
            DispatchQueue.main.async { tabStore.removeTabs(for: bundleID) }
        }
        tabStore.gainSender = { [bridge] tab in
            bridge.sendGain(tab.gain, tabID: tab.tabID, browserBundleID: tab.browserBundleID)
        }
        try? bridge.start()
    }
}
