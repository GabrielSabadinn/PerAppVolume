import AppKit
import CoreAudio

final class AppResolver {
    private var cache: [AudioObjectID: AppIdentity?] = [:]

    func identity(for process: AudioProcessObject) -> AppIdentity? {
        if let cached = cache[process.objectID] { return cached }
        let resolved = resolve(process)
        cache[process.objectID] = resolved
        return resolved
    }

    func retain(only objectIDs: Set<AudioObjectID>) {
        cache = cache.filter { objectIDs.contains($0.key) }
    }

    private func resolve(_ process: AudioProcessObject) -> AppIdentity? {
        if let application = owningApplication(of: process.pid), let bundleID = application.bundleIdentifier {
            return AppIdentity(application: application, bundleID: bundleID)
        }
        guard process.bundleID.isEmpty, let name = ProcessTree.name(of: process.pid) else { return nil }
        return AppIdentity(standalonePID: process.pid, name: name)
    }

    private func owningApplication(of pid: pid_t) -> NSRunningApplication? {
        let responsible = ProcessTree.responsiblePID(of: pid) ?? pid
        return topmostApplication(from: responsible) ?? topmostApplication(from: pid)
    }

    private func topmostApplication(from pid: pid_t) -> NSRunningApplication? {
        var topmost: NSRunningApplication?
        var current = pid
        while current > 1 {
            if let application = NSRunningApplication(processIdentifier: current), application.bundleIdentifier != nil, application.activationPolicy != .prohibited {
                topmost = application
            }
            guard let parent = ProcessTree.parentPID(of: current) else { break }
            current = parent
        }
        return topmost
    }
}
