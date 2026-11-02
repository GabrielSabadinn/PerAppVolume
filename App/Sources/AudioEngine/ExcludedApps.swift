import Foundation

public struct ExcludedApps {
    public static let defaultBundleIDs: Set<String> = [
        "com.apple.logic10",
        "com.apple.garageband10",
        "com.ableton.live",
        "com.apple.TV",
    ]

    public var bundleIDs: Set<String>

    public init(bundleIDs: Set<String> = ExcludedApps.defaultBundleIDs) {
        self.bundleIDs = bundleIDs
    }

    func contains(_ identity: AppIdentity) -> Bool {
        guard let bundleID = identity.bundleID else { return false }
        return bundleIDs.contains(bundleID)
    }
}
