import Foundation

enum Log {
    private static let fileURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/TapSpike.log")

    private static let handle: FileHandle? = {
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        return try? FileHandle(forWritingTo: fileURL)
    }()

    private static let clock = ISO8601DateFormatter()

    static func write(_ message: String) {
        let line = "\(clock.string(from: Date())) \(message)\n"
        print(line, terminator: "")
        handle?.write(Data(line.utf8))
    }
}
