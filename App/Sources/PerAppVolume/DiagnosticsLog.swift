import Foundation

enum DiagnosticsLog {
    private static let fileURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/PerAppVolume.log")
    private static let queue = DispatchQueue(label: "com.gabi.perappvolume.diagnostics")
    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func write(_ message: String) {
        queue.async {
            let line = Data("\(clock.string(from: Date())) \(message)\n".utf8)
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(line)
                handle.closeFile()
            } else {
                try? line.write(to: fileURL)
            }
        }
    }
}
