import AppKit
import UniformTypeIdentifiers

struct AppIdentity {
    let id: String
    let name: String
    let bundleID: String?
    let icon: NSImage

    init(application: NSRunningApplication, bundleID: String) {
        id = bundleID
        name = application.localizedName ?? bundleID
        self.bundleID = bundleID
        icon = application.icon ?? AppIdentity.genericIcon
    }

    init(standalonePID pid: pid_t, name: String) {
        id = "pid:\(pid)"
        self.name = name
        bundleID = nil
        icon = AppIdentity.genericIcon
    }

    private static let genericIcon = NSWorkspace.shared.icon(for: .unixExecutable)
}
