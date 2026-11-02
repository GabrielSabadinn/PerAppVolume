import Foundation

@MainActor
final class LevelPublisher {
    private static let interval: TimeInterval = 1 / 30
    private var timer: Timer?

    func start(_ tick: @escaping @MainActor () -> Void) {
        let timer = Timer(timeInterval: LevelPublisher.interval, repeats: true) { _ in
            MainActor.assumeIsolated(tick)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
