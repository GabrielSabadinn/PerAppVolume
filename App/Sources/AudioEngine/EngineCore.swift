import CoreAudio
import Foundation

final class EngineCore {
    private static let tapRetention: TimeInterval = 30
    private static let wakeRetryDelays: [TimeInterval] = [0.1, 0.5, 2]
    private static let fadeSettleTime: TimeInterval = 0.015

    var onSnapshot: (([AppSnapshot]) -> Void)?
    var onState: ((EngineState) -> Void)?
    var onOutputDevice: ((String, Float?) -> Void)?
    var onOutputDevices: (([OutputDeviceInfo]) -> Void)?
    var onMasterVolume: ((Float) -> Void)?

    private let queue = DispatchQueue(label: "com.gabi.perappvolume.engine")
    private let permissionQueue = DispatchQueue(label: "com.gabi.perappvolume.permission")
    private let excludedApps: ExcludedApps
    private let store: VolumeStore
    private let resolver = AppResolver()
    private let mixer = Mixer()
    private let ownPID = getpid()
    private let ownBundleID = Bundle.main.bundleIdentifier
    private lazy var registry = ProcessRegistry(queue: queue) { [weak self] in self?.reconcile() }
    private lazy var deviceMonitor = OutputDeviceMonitor(
        queue: queue,
        onDefaultChange: { [weak self] in self?.handleOutputDeviceChange() },
        onListChange: { [weak self] in self?.handleDeviceListChange() }
    )
    private var sleepWakeObserver: SleepWakeObserver?
    private var masterVolumeListener: PropertyListener?
    private var masterControl: MasterVolumeControl?
    private var sessions: [String: AppSession] = [:]
    private var router: AggregateRouter?
    private var routedTapUIDs: [String] = []
    private var pendingExpiry: DispatchWorkItem?
    private var running = false
    private var permissionGranted = false
    private var state: EngineState = .idle
    private var nextSessionOrder = 0

    init(excludedApps: ExcludedApps, store: VolumeStore) {
        self.excludedApps = excludedApps
        self.store = store
    }

    func start() {
        queue.async { self.startOnQueue() }
    }

    func stop() {
        queue.async { self.stopOnQueue() }
    }

    func setVolume(_ value: Float, for appID: String) {
        queue.async {
            guard let session = self.sessions[appID] else { return }
            session.volume = min(max(value, 0), 1)
            session.channel.targetGain = session.effectiveGain
            self.store.save(volume: session.volume, for: appID)
        }
    }

    func setMuted(_ muted: Bool, for appID: String) {
        queue.async {
            guard let session = self.sessions[appID] else { return }
            session.isMuted = muted
            session.channel.targetGain = session.effectiveGain
            self.store.save(muted: muted, for: appID)
        }
    }

    func setMasterVolume(_ value: Float) {
        queue.async { self.masterControl?.write(value) }
    }

    func selectOutputDevice(_ device: OutputDeviceInfo) {
        queue.async { try? OutputDeviceCatalog.select(device) }
    }

    private func startOnQueue() {
        guard !running else { return }
        running = true
        OrphanAggregateCleaner.destroyLeftovers(uidPrefix: AggregateRouter.uidPrefix)
        do {
            try registry.start()
            try deviceMonitor.start()
        } catch {
            fail(error)
            return
        }
        sleepWakeObserver = SleepWakeObserver(
            onSleep: { [weak self] in self?.queue.async { self?.suspend() } },
            onWake: { [weak self] in self?.resumeAfterWake() }
        )
        publishOutputDevice()
        setState(.awaitingPermission)
        reconcile()
        requestPermission()
    }

    private func requestPermission() {
        permissionQueue.async { [weak self] in
            let outcome = Result { try PermissionProbe.run() }
            self?.queue.async { self?.finishPermissionRequest(outcome) }
        }
    }

    private func finishPermissionRequest(_ outcome: Result<Void, Error>) {
        guard running else { return }
        switch outcome {
        case .success:
            permissionGranted = true
            setState(.running)
            reconcile()
        case .failure(let error):
            fail(error)
        }
    }

    private func stopOnQueue() {
        guard running else { return }
        running = false
        permissionGranted = false
        pendingExpiry?.cancel()
        registry.stop()
        deviceMonitor.stop()
        sleepWakeObserver = nil
        masterVolumeListener = nil
        tearDownAudio()
        sessions = [:]
        setState(.idle)
        onSnapshot?([])
    }

    private func suspend() {
        tearDownAudio()
    }

    private func resumeAfterWake() {
        for delay in EngineCore.wakeRetryDelays {
            queue.asyncAfter(deadline: .now() + delay) { [weak self] in self?.reconcile() }
        }
    }

    private func handleOutputDeviceChange() {
        guard running else { return }
        publishOutputDevice()
        rebuildRouter()
    }

    private func handleDeviceListChange() {
        guard running else { return }
        onOutputDevices?(OutputDeviceCatalog.available())
    }

    private func reconcile() {
        guard running else { return }
        do {
            let processes = try registry.snapshot().filter { $0.pid != ownPID }
            resolver.retain(only: Set(processes.map(\.objectID)))
            updateSessions(with: groups(from: processes))
            if permissionGranted {
                try syncTaps()
                setState(.running)
            }
            publishSnapshot()
        } catch {
            fail(error)
        }
    }

    private struct ProcessGroup {
        let identity: AppIdentity
        var objectIDs: [AudioObjectID] = []
        var names: Set<String> = []
        var isPlaying = false
    }

    private func groups(from processes: [AudioProcessObject]) -> [String: ProcessGroup] {
        var groups: [String: ProcessGroup] = [:]
        for process in processes {
            guard let identity = resolver.identity(for: process), !isExcluded(identity) else { continue }
            var group = groups[identity.id] ?? ProcessGroup(identity: identity)
            group.objectIDs.append(process.objectID)
            group.names.insert(ProcessTree.name(of: process.pid) ?? "pid \(process.pid)")
            group.isPlaying = group.isPlaying || process.isRunningOutput
            groups[identity.id] = group
        }
        return groups
    }

    private func isExcluded(_ identity: AppIdentity) -> Bool {
        excludedApps.contains(identity) || (identity.bundleID != nil && identity.bundleID == ownBundleID)
    }

    private func updateSessions(with groups: [String: ProcessGroup]) {
        for (id, group) in groups {
            let session = sessions[id] ?? makeSession(for: group.identity)
            session.processObjectIDs = group.objectIDs.sorted()
            session.processNames = group.names.sorted()
            session.isPlaying = group.isPlaying
            if group.isPlaying { session.lastPlayingAt = Date() }
            sessions[id] = session
        }
        for (id, session) in sessions where groups[id] == nil {
            session.dropTap()
            sessions[id] = nil
        }
    }

    private func makeSession(for identity: AppIdentity) -> AppSession {
        defer { nextSessionOrder += 1 }
        return AppSession(identity: identity, order: nextSessionOrder, volume: store.volume(for: identity.id) ?? 1, isMuted: store.isMuted(identity.id))
    }

    private func syncTaps() throws {
        let now = Date()
        for session in sessions.values {
            if session.wantsTap(at: now, retention: EngineCore.tapRetention) {
                try ensureTap(for: session)
            } else {
                session.dropTap()
            }
        }
        try syncRouter()
        scheduleExpiry(from: now)
    }

    private func ensureTap(for session: AppSession) throws {
        if let tap = session.tap {
            guard tap.processObjectIDs != session.processObjectIDs else { return }
            if (try? tap.update(processObjectIDs: session.processObjectIDs)) != nil { return }
            session.dropTap()
        }
        session.tap = try ProcessTap(processObjectIDs: session.processObjectIDs, name: session.identity.name)
    }

    private var routedSessions: [AppSession] {
        sessions.values.filter { $0.tap != nil }.sorted { $0.order < $1.order }
    }

    private func syncRouter() throws {
        let routed = routedSessions
        let taps = routed.compactMap(\.tap)
        guard !taps.isEmpty else {
            tearDownRouter()
            return
        }
        let uids = taps.map(\.uid)
        if let router {
            guard uids != routedTapUIDs else { return }
            mixer.setChannels(routed.map(\.channel))
            do {
                try router.updateTaps(uids)
            } catch {
                tearDownRouter()
                try buildRouter(with: routed)
            }
        } else {
            try buildRouter(with: routed)
        }
        routedTapUIDs = uids
    }

    private func buildRouter(with routed: [AppSession]) throws {
        let output = try OutputDevice.systemDefault()
        mixer.configure(sampleRate: output.sampleRate, tapBufferOffset: output.inputStreamCount)
        mixer.setChannels(routed.map(\.channel))
        mixer.fadeMasterIn()
        router = try AggregateRouter(output: output, tapUIDs: routed.compactMap(\.tap).map(\.uid), mixer: mixer)
        deviceMonitor.track(output)
    }

    private func tearDownRouter() {
        guard let router else { return }
        mixer.fadeMasterOut()
        Thread.sleep(forTimeInterval: EngineCore.fadeSettleTime)
        router.destroy()
        self.router = nil
        routedTapUIDs = []
    }

    private func rebuildRouter() {
        tearDownRouter()
        do {
            try syncRouter()
        } catch {
            fail(error)
        }
    }

    private func tearDownAudio() {
        tearDownRouter()
        sessions.values.forEach { $0.dropTap() }
    }

    private func scheduleExpiry(from now: Date) {
        pendingExpiry?.cancel()
        let expiries = sessions.values
            .filter { $0.tap != nil && !$0.isPlaying }
            .map { $0.lastPlayingAt.addingTimeInterval(EngineCore.tapRetention) }
        guard let earliest = expiries.min() else { return }
        let work = DispatchWorkItem { [weak self] in self?.reconcile() }
        pendingExpiry = work
        queue.asyncAfter(deadline: .now() + max(earliest.timeIntervalSince(now), 0.05), execute: work)
    }

    private func publishSnapshot() {
        let snapshots = sessions.values
            .sorted { lhs, rhs in
                guard lhs.isPlaying == rhs.isPlaying else { return lhs.isPlaying }
                return lhs.identity.name.localizedCaseInsensitiveCompare(rhs.identity.name) == .orderedAscending
            }
            .map(\.snapshot)
        onSnapshot?(snapshots)
    }

    private func publishOutputDevice() {
        guard let output = try? OutputDevice.systemDefault() else { return }
        let control = MasterVolumeControl(deviceID: output.id)
        masterControl = control
        masterVolumeListener = control.listen(on: queue) { [weak self] in
            guard let volume = control.read() else { return }
            self?.onMasterVolume?(volume)
        }
        onOutputDevice?(output.name, control.read())
        onOutputDevices?(OutputDeviceCatalog.available())
    }

    private func setState(_ newState: EngineState) {
        guard state != newState else { return }
        state = newState
        onState?(newState)
    }

    private func fail(_ error: Error) {
        if let coreAudioError = error as? CoreAudioError, coreAudioError.isIllegalOperation {
            setState(.permissionDenied)
        } else {
            setState(.failed(String(describing: error)))
        }
    }
}
