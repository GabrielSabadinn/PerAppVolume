import AudioEngine
import Foundation

enum Command {
    case list
    case run(seconds: TimeInterval)
    case set(match: String, volume: Float, seconds: TimeInterval)

    init?(arguments: [String]) {
        switch arguments.first {
        case "list":
            self = .list
        case "run":
            self = .run(seconds: Command.seconds(arguments.dropFirst().first, fallback: 10))
        case "set":
            guard arguments.count >= 3, let volume = Float(arguments[2]) else { return nil }
            self = .set(match: arguments[1], volume: volume, seconds: Command.seconds(arguments.dropFirst(3).first, fallback: 10))
        default:
            return nil
        }
    }

    private static func seconds(_ argument: String?, fallback: TimeInterval) -> TimeInterval {
        argument.flatMap(TimeInterval.init) ?? fallback
    }
}

@MainActor
func describe(_ app: AudioApp) -> String {
    String(format: "  %@ [%@] playing=%@ vol=%.2f muted=%@ rms=%.3f peak=%.3f procs=%@",
           app.name, app.bundleID ?? app.id, app.isPlaying ? "yes" : "no", app.volume, app.isMuted ? "yes" : "no",
           app.level.rms, app.level.peak, app.processNames.joined(separator: ","))
}

@MainActor
func report(_ engine: AudioEngine) {
    CLILog.write(String(format: "state=%@ output='%@' master=%.2f apps=%d", String(describing: engine.state), engine.outputDeviceName, engine.masterVolume, engine.apps.count))
    engine.apps.map(describe).forEach(CLILog.write)
}

@MainActor
func pump(seconds: TimeInterval) {
    RunLoop.main.run(until: Date().addingTimeInterval(seconds))
}

@MainActor
func findApp(matching match: String, in engine: AudioEngine) -> AudioApp? {
    engine.apps.first { app in
        app.id.localizedCaseInsensitiveContains(match)
            || app.name.localizedCaseInsensitiveContains(match)
            || app.processNames.contains { $0.localizedCaseInsensitiveContains(match) }
    }
}

@MainActor
func waitForApp(matching match: String, in engine: AudioEngine, timeout: TimeInterval) -> AudioApp? {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if let app = findApp(matching: match, in: engine) { return app }
        pump(seconds: 0.25)
    }
    return nil
}

@MainActor
func runEngine(for seconds: TimeInterval, _ engine: AudioEngine) {
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        pump(seconds: 1)
        report(engine)
    }
    engine.stop()
    pump(seconds: 0.3)
    CLILog.write("RESULT: stopped")
}

@MainActor
func runCommand() {
    guard let command = Command(arguments: Array(CommandLine.arguments.dropFirst())) else {
        CLILog.write("usage: EngineCLI list | run [seconds] | set <bundle-id-or-name> <0..1> [seconds]")
        exit(2)
    }

    let engine = AudioEngine()
    CLILog.write("--- EngineCLI pid=\(getpid()) command=\(CommandLine.arguments.dropFirst().joined(separator: " "))")
    engine.start()

    switch command {
    case .list:
        pump(seconds: 1.5)
        report(engine)
        engine.stop()
        pump(seconds: 0.3)
        CLILog.write("RESULT: listed")
    case .run(let seconds):
        runEngine(for: seconds, engine)
    case .set(let match, let volume, let seconds):
        guard let app = waitForApp(matching: match, in: engine, timeout: 10) else {
            CLILog.write("RESULT: no app matching '\(match)'")
            engine.stop()
            pump(seconds: 0.3)
            exit(1)
        }
        engine.setVolume(volume, for: app.id)
        CLILog.write("set volume \(volume) on \(app.name) [\(app.id)]")
        runEngine(for: seconds, engine)
    }
}

MainActor.assumeIsolated(runCommand)
