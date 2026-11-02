import AppKit
import Foundation

final class SleepWakeObserver {
    private var tokens: [NSObjectProtocol] = []

    init(onSleep: @escaping () -> Void, onWake: @escaping () -> Void) {
        let center = NSWorkspace.shared.notificationCenter
        tokens = [
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { _ in onSleep() },
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { _ in onWake() },
        ]
    }

    deinit {
        tokens.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
    }
}
