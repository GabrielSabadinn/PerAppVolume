import CoreAudio
import Foundation

final class ProcessRegistry {
    private static let debounce: DispatchTimeInterval = .milliseconds(150)

    private let queue: DispatchQueue
    private let onChange: () -> Void
    private var listListener: PropertyListener?
    private var outputListeners: [AudioObjectID: PropertyListener] = [:]
    private var pendingChange: DispatchWorkItem?

    init(queue: DispatchQueue, onChange: @escaping () -> Void) {
        self.queue = queue
        self.onChange = onChange
    }

    func start() throws {
        listListener = try PropertyListener(objectID: .system, selector: kAudioHardwarePropertyProcessObjectList, queue: queue) { [weak self] in self?.scheduleChange() }
    }

    func stop() {
        pendingChange?.cancel()
        listListener = nil
        outputListeners = [:]
    }

    func snapshot() throws -> [AudioProcessObject] {
        let processes = try AudioProcessObject.enumerate()
        refreshOutputListeners(for: processes)
        return processes
    }

    private func refreshOutputListeners(for processes: [AudioProcessObject]) {
        let current = Set(processes.map(\.objectID))
        outputListeners = outputListeners.filter { current.contains($0.key) }
        for process in processes where outputListeners[process.objectID] == nil {
            outputListeners[process.objectID] = try? PropertyListener(objectID: process.objectID, selector: kAudioProcessPropertyIsRunning, queue: queue) { [weak self] in self?.scheduleChange() }
        }
    }

    private func scheduleChange() {
        pendingChange?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        pendingChange = work
        queue.asyncAfter(deadline: .now() + ProcessRegistry.debounce, execute: work)
    }
}
