import AppKit
import Foundation

@MainActor
@Observable
public final class AudioApp: Identifiable {
    public let id: String
    public let name: String
    public let bundleID: String?
    public let icon: NSImage
    public internal(set) var processNames: [String]
    public internal(set) var volume: Float
    public internal(set) var isMuted: Bool
    public internal(set) var isPlaying: Bool
    public internal(set) var level: AudioLevel = .silent
    var channel: MixerChannel

    init(snapshot: AppSnapshot) {
        id = snapshot.identity.id
        name = snapshot.identity.name
        bundleID = snapshot.identity.bundleID
        icon = snapshot.identity.icon
        processNames = snapshot.processNames
        volume = snapshot.volume
        isMuted = snapshot.isMuted
        isPlaying = snapshot.isPlaying
        channel = snapshot.channel
    }

    func update(from snapshot: AppSnapshot) {
        processNames = snapshot.processNames
        isPlaying = snapshot.isPlaying
        channel = snapshot.channel
    }

    func refreshLevel() {
        guard isPlaying else {
            level = level.decayed(towardRMS: 0, peak: 0)
            return
        }
        level = level.decayed(towardRMS: channel.measuredRMS, peak: channel.consumePeak())
    }
}
