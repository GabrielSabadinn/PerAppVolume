import Foundation

enum CLILog {
    private static let fileURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/PerAppVolumeCLI.log")

    private static let handle: FileHandle? = {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        let handle = try? FileHandle(forWritingTo: fileURL)
        handle?.seekToEndOfFile()
        return handle
    }()

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func write(_ message: String) {
        let line = "\(clock.string(from: Date())) \(message)\n"
        print(line, terminator: "")
        handle?.write(Data(line.utf8))
    }
}
