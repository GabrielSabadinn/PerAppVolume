import Foundation

public struct VolumeStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func volume(for appID: String) -> Float? {
        guard isPersistable(appID), defaults.object(forKey: volumeKey(appID)) != nil else { return nil }
        return defaults.float(forKey: volumeKey(appID))
    }

    func isMuted(_ appID: String) -> Bool {
        defaults.bool(forKey: mutedKey(appID))
    }

    func save(volume: Float, for appID: String) {
        guard isPersistable(appID) else { return }
        defaults.set(volume, forKey: volumeKey(appID))
    }

    func save(muted: Bool, for appID: String) {
        guard isPersistable(appID) else { return }
        defaults.set(muted, forKey: mutedKey(appID))
    }

    private func isPersistable(_ appID: String) -> Bool { !appID.hasPrefix("pid:") }
    private func volumeKey(_ appID: String) -> String { "volume.\(appID)" }
    private func mutedKey(_ appID: String) -> String { "muted.\(appID)" }
}
