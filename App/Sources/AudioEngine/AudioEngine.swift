import Foundation

@MainActor
@Observable
public final class AudioEngine {
    public private(set) var apps: [AudioApp] = []
    public private(set) var state: EngineState = .idle
    public private(set) var outputDeviceName = ""
    public private(set) var hasMasterVolume = false
    public private(set) var outputDevices: [OutputDeviceInfo] = []

    public var masterVolume: Float {
        get { masterVolumeValue }
        set {
            masterVolumeValue = newValue
            core.setMasterVolume(newValue)
        }
    }

    private var masterVolumeValue: Float = 0
    private let core: EngineCore
    private let levelPublisher = LevelPublisher()

    public init(excludedApps: ExcludedApps = ExcludedApps(), store: VolumeStore = VolumeStore()) {
        core = EngineCore(excludedApps: excludedApps, store: store)
        core.onSnapshot = { [weak self] snapshots in
            DispatchQueue.main.async { self?.apply(snapshots) }
        }
        core.onState = { [weak self] state in
            DispatchQueue.main.async { self?.state = state }
        }
        core.onOutputDevice = { [weak self] name, volume in
            DispatchQueue.main.async {
                self?.outputDeviceName = name
                self?.hasMasterVolume = volume != nil
                self?.masterVolumeValue = volume ?? 0
            }
        }
        core.onMasterVolume = { [weak self] volume in
            DispatchQueue.main.async { self?.masterVolumeValue = volume }
        }
        core.onOutputDevices = { [weak self] devices in
            DispatchQueue.main.async { self?.outputDevices = devices }
        }
    }

    public func start() {
        core.start()
        levelPublisher.start { [weak self] in self?.apps.forEach { $0.refreshLevel() } }
    }

    public func stop() {
        levelPublisher.stop()
        core.stop()
    }

    public func setVolume(_ value: Float, for appID: AudioApp.ID) {
        guard let app = apps.first(where: { $0.id == appID }) else { return }
        app.volume = min(max(value, 0), 1)
        core.setVolume(app.volume, for: appID)
    }

    public func selectOutputDevice(_ device: OutputDeviceInfo) {
        core.selectOutputDevice(device)
    }

    public func setMuted(_ muted: Bool, for appID: AudioApp.ID) {
        guard let app = apps.first(where: { $0.id == appID }) else { return }
        app.isMuted = muted
        core.setMuted(muted, for: appID)
    }

    private func apply(_ snapshots: [AppSnapshot]) {
        var existing = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
        apps = snapshots.map { snapshot in
            guard let app = existing.removeValue(forKey: snapshot.identity.id) else { return AudioApp(snapshot: snapshot) }
            app.update(from: snapshot)
            return app
        }
    }
}
